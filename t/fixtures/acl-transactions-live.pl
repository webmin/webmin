#!/usr/bin/perl
# Run ACL transaction tests as root on a disposable Linux VM.
# Pass /tmp/webmin-acl-live.<suffix> containing web-lib-funcs.pl.
# The test creates temporary databases and accounts, then removes them.
# Installed Webmin files are unchanged.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use DBI;
use IPC::Open3;
use Symbol qw(gensym);
use Test::More;

# Require Linux, root and a task path before loading the tested code.
die "Run this test as root on a disposable Linux VM\n" unless $^O eq 'linux' && $> == 0;
my ($task) = @ARGV;
die "Pass a task directory named /tmp/webmin-acl-live.<suffix>\n" unless $task && $task =~ m{^/tmp/webmin-acl-live\.[A-Za-z0-9]+$};
require "$task/web-lib-funcs.pl";
# Use a per-process database name and a password generated on the VM.
my $name = 'webmin_acl_test_'.$$;
open(my $random, '<', '/dev/urandom') or die $!;
read($random, my $bytes, 32) == 32 or die "Cannot generate fixture password\n";
close($random);
my $password = unpack('H*', $bytes);
# Track created resources so cleanup can run after setup fails.
my ($mysql, $pg, $mysql_db, $mysql_user, $pg_db, $pg_user);
my @handles;

# pg_admin(sql): run SQL as the local postgres user and return stdout.
sub pg_admin {
my ($sql) = @_;
my ($input, $output);
my $errors = gensym();
# Send SQL on stdin so passwords are not included in command arguments.
my $pid = open3($input, $output, $errors, 'runuser', '-u', 'postgres', '--',
	'psql', '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-d', 'postgres');
print $input $sql;
close($input);
# Collect both output streams before checking psql's exit status.
my $out = do { local $/; <$output> };
my $err = do { local $/; <$errors> };
waitpid($pid, 0);
# Hide SQL containing passwords when the command fails.
die "PostgreSQL fixture administration failed\n" if $?;
return $out;
}

# cleanup(): remove only resources successfully created by this process.
sub cleanup {
for my $handle (@handles) {
	# Skip closed handles and continue cleanup after disconnect errors.
	eval { $handle->disconnect() if $handle->{'Active'}; };
	}
@handles = ( );
if ($mysql_db) {
	# Drop the MariaDB test database before its login.
	$mysql->do("drop database $name");
	$mysql_db = 0;
	}
if ($mysql_user) {
	# Remove the MariaDB login even if later setup failed.
	$mysql->do("drop user '$name'\@'127.0.0.1'");
	$mysql_user = 0;
	}
if ($pg_db) {
	# Force-close any remaining PostgreSQL fixture sessions.
	pg_admin("drop database $name with (force)");
	$pg_db = 0;
	}
if ($pg_user) {
	# Remove the PostgreSQL role after its database.
	pg_admin("drop role $name");
	$pg_user = 0;
	}
}
# Clean up on early exits too. Cleared flags prevent repeated drops.
END { cleanup(); }

# Use the guest's configured MariaDB login without printing its credentials.
my %mysql_config;
main::read_file('/etc/webmin/mysql/config', \%mysql_config)
	or die "Cannot read guest database configuration\n";
my $mysql_dsn = 'dbi:mysql:host=localhost';
# Use Webmin's socket override when the guest has one configured.
$mysql_dsn .= ';mysql_socket='.$mysql_config{'sock'} if $mysql_config{'sock'};
# Report connection failures without exposing the configured password.
$mysql = DBI->connect($mysql_dsn, $mysql_config{'login'}, $mysql_config{'pass'},
	{ RaiseError => 0, PrintError => 0, AutoCommit => 1 })
	or die "Cannot connect to the guest MariaDB server\n";
$mysql->{'RaiseError'} = 1;
diag('MariaDB '.$mysql->selectrow_array('select version()'));
# Restrict the MariaDB test login to this run's database.
$mysql->do("create database $name");
$mysql_db = 1;
$mysql->do("create user '$name'\@'127.0.0.1' identified by '$password'");
$mysql_user = 1;
$mysql->do("grant all on $name.* to '$name'\@'127.0.0.1'");
# Create the test role and database as the local postgres user.
pg_admin("create role $name login password '$password'");
$pg_user = 1;
pg_admin("create database $name owner $name");
$pg_db = 1;
# Use an independent connection to observe committed ACL changes.
$pg = DBI->connect("dbi:Pg:dbname=$name;host=127.0.0.1", $name, $password,
	{ RaiseError => 1, PrintError => 0, AutoCommit => 1 });
push(@handles, $pg);
diag('PostgreSQL '.$pg->selectrow_array('show server_version'));

# Keep Webmin's real connection cache and transaction cleanup in use.
my %miniserv;
# get_miniserv_config(&config): supply this case's database and cache settings.
local *main::get_miniserv_config = sub { %{$_[0]} = %miniserv; };
# error(message): turn Webmin errors into catchable exceptions.
local *main::error = sub { die "$_[0]\n"; };
# text(key, [values...]): expose error keys and SQL messages to assertions.
local *main::text = sub { join(': ', @_); };
# Use a different login so user ACL saves take the database path.
local $main::base_remote_user = 'admin';
my $connect = \&main::connect_userdb;
# Cover both backends and cache settings, with AutoCommit on and off.
for my $proto ('mysql', 'postgresql') {
	my $admin = $proto eq 'mysql' ? $mysql : $pg;
	# MariaDB's admin connection must select the fixture database.
	$admin->do("use $name") if $proto eq 'mysql';
	$admin->do('create table allowed_values (value varchar(32) primary key)');
	$admin->do("insert into allowed_values values ('deny'), ('allow')");
	if ($proto eq 'postgresql') {
		# Provide the trigger function used to reject an ACL deletion.
		$admin->do(q{create function reject_acl_delete() returns trigger
			language plpgsql as $$ begin raise exception 'fixture delete denied'; end $$});
		}
	for my $kind ('user', 'group') {
		# Create the user or group whose ACL will be saved.
		my $table = "webmin_${kind}_acl";
		$admin->do("create table webmin_$kind (id integer primary key, name varchar(32))");
		$admin->do("insert into webmin_$kind values (1, 'fixture')");
		my $save = $kind eq 'user' ? \&main::save_module_acl : \&main::save_group_module_acl;
		for my $cached (0, 1) {
			for my $auto (0, 1) {
				for my $failure ('success', 'reset', 'delete', 'insert', 'commit') {
					# Start each case with two ACL entries.
					my $label = "$proto $kind cached=$cached auto=$auto $failure";
					my $schema = "create table $table (id integer, module varchar(32), ".
						'attr varchar(32), value varchar(32), primary key(id,module,attr)';
					# PostgreSQL checks values at COMMIT.
					$schema .= ', foreign key(value) references allowed_values(value) deferrable initially deferred'
						if $proto eq 'postgresql';
					$admin->do($schema.')'.($proto eq 'mysql' ? ' engine=InnoDB' : ''));
					$admin->do("insert into $table values (1,'example','access','deny'), (1,'example','flag','deny')");
					if ($failure eq 'delete') {
						# Reject deletion before any old
						# permissions are removed.
						$admin->do($proto eq 'mysql'
							? "create trigger reject_delete before delete on $table for each row ".
							  "signal sqlstate '45000' set message_text = 'fixture delete denied'"
							: "create trigger reject_delete before delete on $table for each row ".
							  'execute function reject_acl_delete()');
						}
					# Use a fresh connection cache per case.
					my $str = "$proto://$name:$password\@127.0.0.1/$name";
					%miniserv = (userdb => $str, userdb_nocache => !$cached);
					local %main::connect_userdb_cache;
					local %main::connect_userdb_cache_time;
					my $dbh;
					# connect_userdb(string): open the real
					# connection with the chosen settings.
					local *main::connect_userdb = sub {
						my @rv = $connect->(@_);
						$dbh = $rv[0];
						die "Fixture connection failed\n" unless ref($dbh);
						push(@handles, $dbh);
						$dbh->{'PrintError'} = 0;
						$dbh->{'AutoCommit'} = $auto;
						if ($proto eq 'mysql' && $failure eq 'commit') {
							# Fail COMMIT by closing
							# this test connection.
							my ($id) = $dbh->selectrow_array('select connection_id()');
							# commit(handle): close
							# this connection once.
							$dbh->{'Callbacks'} = { commit => sub {
								$dbh->{'Callbacks'} = { };
								$mysql->do("kill connection $id");
								return;
								} };
							}
						return wantarray ? @rv : $rv[0];
						};
					my $acl = {access => 'allow', flag => 'allow'};
					# An undefined ACL removes all entries.
					$acl = undef if $failure eq 'reset';
					# Fail INSERT with a long attribute.
					$acl->{'x' x 33} = 'allow' if $failure eq 'insert';
					# Fail COMMIT with an unknown value.
					$acl->{'access'} = 'invalid' if $failure eq 'commit' && $proto eq 'postgresql';
					# Catch errors so other cases still run.
					eval { $save->($acl, 'fixture', 'example', 1); };
					my $err = $@;
					if ($failure eq 'success' || $failure eq 'reset') {
						# Successful saves and resets
						# must not raise an error.
						is($err, '', "$label completes without error");
						}
					else {
						# Check the database error.
						like($err, qr/fixture delete denied|too long|foreign key|gone away|Lost connection|Turning on AutoCommit failed/i,
							"$label reports the database error");
						}
					if ($failure eq 'commit') {
						# Failed handles must not be
						# reused from the cache.
						ok(!$dbh->{'Active'}, "$label closes the failed connection");
						ok(!exists($main::connect_userdb_cache{$str}), "$label clears the cached connection");
						}
					# Read through an independent connection
					# to detect missing or partial commits.
					my $expected = $failure eq 'reset' ? [ ] :
						[ ['access', $failure eq 'success' ? 'allow' : 'deny'],
						  ['flag', $failure eq 'success' ? 'allow' : 'deny'] ];
					is_deeply($admin->selectall_arrayref("select attr,value from $table order by attr"),
						$expected, "$label applies all ACL changes or none");
					# Close cached handles before removing
					# this case's table.
					$dbh->disconnect() if $dbh->{'Active'};
					$admin->do("drop table $table");
					}
				}
			}
		}
	}
# Remove the test databases and accounts before finishing.
cleanup();
diag('Fixture databases and accounts removed');
done_testing();
