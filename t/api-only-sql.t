#!/usr/bin/perl
# Exercise SQL ACL saves and write failures in an isolated database.
# On a disposable VM, copy this test and web-lib-funcs.pl under
# /tmp/webmin-api-sql.XXXXXX, keeping the t/ directory. Run with either
# "mysql InnoDB", "mysql MyISAM" as root, or "postgresql" as postgres.
# Live runs create and remove their own database. Without arguments, use SQLite.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
BEGIN {
	eval { require DBI; 1 } or plan skip_all => 'DBI is required';
}
require "$FindBin::Bin/../web-lib-funcs.pl";
$main::config_directory = tempdir(TMPDIR => 1, CLEANUP => 1);
$main::base_remote_user = 'admin';
my $backend = shift(@ARGV) || 'sqlite';
my ($db, $admin, $database, $engine);
my $options = { RaiseError => 0, PrintError => 0, AutoCommit => 1 };
if ($backend eq 'sqlite') {
	# The default test touches only an in-memory SQLite database.
	eval { require DBD::SQLite; 1 }
		or plan skip_all => 'DBD::SQLite is required';
	$db = DBI->connect('dbi:SQLite:dbname=:memory:', '', '', $options);
	}
else {
	# Live database tests must be explicitly requested from a guest fixture.
	die "Disposable Linux VM task directory required\n"
		if ($^O ne 'linux' || $FindBin::Bin !~
		    m{^/tmp/webmin-api-sql\.[A-Za-z0-9]+/t$});
	die "Unknown SQL backend\n"
		if ($backend ne 'mysql' && $backend ne 'postgresql');
	my ($dsn, $user, $pass, $admin_db);
	if ($backend eq 'mysql') {
		# Use the guest's configured login without copying its password.
		my %mysql;
		read_file('/etc/webmin/mysql/config', \%mysql) or
			die "Missing guest MySQL settings\n";
		($user, $pass) = ($mysql{'login'} || 'root', $mysql{'pass'} || '');
		$dsn = 'dbi:mysql:database=';
		$admin_db = 'mysql';
		$engine = shift(@ARGV) || 'InnoDB';
		die "Invalid table engine\n" if ($engine !~ /\A(?:InnoDB|MyISAM)\z/);
		}
	else {
		# PostgreSQL uses the guest's local postgres account and peer auth.
		$dsn = 'dbi:Pg:dbname=';
		$admin_db = 'postgres';
		}
	$admin = DBI->connect($dsn.$admin_db, $user, $pass,
		{ %$options, RaiseError => 1 });
	my $name = 'webmin_api_sql_test_'.$$;
	$admin->do("create database $name");
	$database = $name;
	$db = DBI->connect($dsn.$database, $user, $pass, $options);
	}
$db or die "Could not connect to test database\n";

# Remove only the database created by this process, even if a test aborts.
END {
	if ($database) {
		$db->disconnect() if ($db && $db->{'Active'});
		eval {
			$admin->do("drop database $database");
			my $query = $backend eq 'mysql' ?
				"select count(*) from information_schema.schemata ".
				"where schema_name = ?" :
				"select count(*) from pg_database where datname = ?";
			my ($left) = $admin->selectrow_array($query, undef, $database);
			die "Test database still exists\n" if ($left);
			};
		if ($@) {
			warn "Test database cleanup failed: $@";
			$? = 1;
			}
		$admin->disconnect();
		}
	}

# Route ACL writers to the fixture database and capture Webmin errors.
*main::get_userdb_string = sub { return 'mysql://fixture'; };
*main::connect_userdb = sub {
	return ($db, $backend eq 'postgresql' ? 'postgresql' : 'mysql');
	};
*main::disconnect_userdb = sub { };
*main::error = sub { die join('', @_)."\n"; };
*main::text = sub { return join(': ', @_); };

my $trigger_table;
# sql(statement, [values...])
# Stop on fixture failures so they cannot be mistaken for save failures.
sub sql
{
my ($statement, @values) = @_;
$statement .= " engine=$engine" if ($engine && $statement =~ /^create table /);
$statement .= " on $trigger_table" if ($backend eq 'postgresql' &&
	$statement eq 'drop trigger reject_write');
$db->do($statement, undef, @values) or die $db->errstr;
}

# stored_acl(table, module)
# Read the stored permissions independently of Webmin's ACL cache.
sub stored_acl
{
my ($table, $module) = @_;
my $rows = $db->selectall_arrayref(
	"select attr,value from $table where id = 1 and module = ?",
	undef, $module) or die $db->errstr;
return { map { @$_ } @$rows };
}

# reject_write(table, operation, condition)
# Make the database reject a write, including writes that remove the policy.
sub reject_write
{
my ($table, $operation, $condition) = @_;
if ($backend eq 'mysql') {
	# SIGNAL rejects the statement for both transactional and MyISAM tables.
	sql("create trigger reject_write before $operation on $table ".
		"for each row begin if $condition then signal sqlstate '45000' ".
		"set message_text = 'fixture write failure'; end if; end");
	}
elsif ($backend eq 'postgresql') {
	# PostgreSQL triggers call a function that raises the test failure.
	$trigger_table = $table;
	my $record = $operation eq 'delete' ? 'old' : 'new';
	sql("create or replace function reject_fixture_write() returns trigger ".
		"as \$\$ begin if $condition then ".
		"raise exception 'fixture write failure'; ".
		"end if; return $record; end; \$\$ language plpgsql");
	sql("create trigger reject_write before $operation on $table ".
		"for each row execute function reject_fixture_write()");
	}
else {
	# SQLite runs the same conditions without a database server.
	sql("create trigger reject_write before $operation on $table ".
		"when $condition begin ".
		"select raise(abort, 'fixture write failure'); end");
	}
}

foreach my $kind ('user', 'group') {
	my $table = "webmin_${kind}_acl";
	sql("create table webmin_$kind (id integer primary key, name text)");
	sql("insert into webmin_$kind values (1, 'integration')");
	sql("create table $table (id integer, module varchar(32), ".
		"attr varchar(32), value varchar(255), ".
		"primary key(id,module,attr))");
	my $save = $kind eq 'user' ? \&save_module_acl : \&save_group_module_acl;
	my $endpoint = 'virtual-server/remote.cgi';
	my $acl = { api_only => $endpoint, rpc => 0 };
	$save->($acl, 'integration', '', 1);
	is_deeply(stored_acl($table, ''), $acl, "$kind creates API policy");

	# Ordinary-field failures must retain the previous restriction, even
	# when the caller intended to change or remove it in the same save.
	reject_write($table, 'insert', "new.attr <> 'api_only'");
	foreach my $policy ({ api_only => $endpoint },
			   { api_only => 'other/api.cgi' },
			   { api_only => '' }, { }) {
		eval { $save->({ %$policy, rpc => 1 }, 'integration', '', 1); };
		like($@, qr/fixture write failure/, "$kind reports failed save");
		is(stored_acl($table, '')->{'api_only'}, $endpoint,
			"$kind retains policy after failed save");
		}
	sql('drop trigger reject_write');

	# Check the policy remains present during a successful replacement.
	reject_write($table, 'insert', "new.attr <> 'api_only' and ".
		"not exists (select 1 from $table where id = new.id ".
		"and module = '' and attr = 'api_only' and value <> '')");
	eval { $save->($acl, 'integration', '', 1); };
	is($@, '', "$kind keeps policy throughout ordinary writes");
	sql('drop trigger reject_write');
	is_deeply(stored_acl($table, ''), $acl, "$kind replaces ordinary ACL");

	# A rejected policy update must leave the old endpoint in place.
	reject_write($table, 'update', '1=1');
	eval { $save->($acl, 'integration', '', 1); };
	is($@, '', "$kind leaves unchanged endpoint alone");
	foreach my $endpoint_change ('other/api.cgi', '') {
		eval { $save->({ api_only => $endpoint_change },
			'integration', '', 1); };
		like($@, qr/fixture write failure/, "$kind reports policy failure");
		is(stored_acl($table, '')->{'api_only'}, $endpoint,
			"$kind retains policy after rejected update");
		}
	sql('drop trigger reject_write');

	# Removing a policy is still supported, but only after other writes.
	reject_write($table, 'delete', "old.attr = 'api_only'");
	eval { $save->(undef, 'integration', '', 1); };
	like($@, qr/fixture write failure/, "$kind reports failed reset");
	is(stored_acl($table, '')->{'api_only'}, $endpoint,
		"$kind retains policy after rejected deletion");
	sql('drop trigger reject_write');
	$save->({ api_only => 'other/api.cgi' }, 'integration', '', 1);
	is_deeply(stored_acl($table, ''), { api_only => 'other/api.cgi' },
		"$kind changes endpoint without duplicate rows");
	$save->({ api_only => '' }, 'integration', '', 1);
	is_deeply(stored_acl($table, ''), { api_only => '' },
		"$kind can explicitly clear restriction");
	$save->($acl, 'integration', '', 1);
	$save->({ rpc => 1 }, 'integration', '', 1);
	is_deeply(stored_acl($table, ''), { rpc => 1 },
		"$kind keeps ACL replacement semantics for omitted keys");
	$save->($acl, 'integration', '', 1);
	$save->(undef, 'integration', '', 1);
	is_deeply(stored_acl($table, ''), { }, "$kind can clear whole ACL");

	# Module ACLs must retain their existing replacement and reset behavior.
	$save->($acl, 'integration', '', 1);
	$save->({ api_only => 'module-value', edit => 1 },
		'integration', 'proc', 1);
	$save->({ edit => 0 }, 'integration', 'proc', 1);
	is_deeply(stored_acl($table, 'proc'), { edit => 0 },
		"$kind replaces module ACL normally");
	$save->(undef, 'integration', 'proc', 1);
	is_deeply(stored_acl($table, 'proc'), { }, "$kind resets module ACL");
	is_deeply(stored_acl($table, ''), $acl,
		"$kind module saves leave global policy alone");
}
$db->disconnect();
done_testing();
