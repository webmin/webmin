#!/usr/bin/perl
# Exercise ACL transaction failures with a real DBI handle.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
# Skip these tests when DBI or the SQLite driver is missing.
BEGIN {
	eval { require DBI; require DBD::SQLite; 1 }
		or plan skip_all => 'DBI and DBD::SQLite are required';
}
use DBD::SQLite::Constants qw(SQLITE_DELETE SQLITE_INSERT SQLITE_DENY SQLITE_OK);
require "$FindBin::Bin/../web-lib-funcs.pl";

# get_miniserv_config(&config): use the default connection cache settings.
local *main::get_miniserv_config = sub { %{$_[0]} = ( ); };
# get_userdb_string(): select the SQL path with a placeholder connection URL.
local *main::get_userdb_string = sub { 'mysql://fixture' };
# error(message): turn Webmin errors into catchable exceptions.
local *main::error = sub { die "$_[0]\n"; };
# text(key, [values...]): expose error keys and SQL messages to assertions.
local *main::text = sub { join(': ', @_); };
# Use a different login so ACL saves take the database path.
local $main::base_remote_user = 'admin';
my $tmp = tempdir(TMPDIR => 1, CLEANUP => 1);

# SQLite exercises shared SQL and DBI commit behavior without a server.
for my $kind ('user', 'group') {
	for my $cached (0, 1) {
		for my $failure ('', 'prepare_delete', 'prepare_insert',
				 'delete', 'insert', 'commit') {
			# Isolate each case in its own SQLite database.
			my $label = "$kind cached=$cached ".($failure || 'success');
			my $dsn = "dbi:SQLite:dbname=$tmp/$kind-$cached-$failure.db";
			my $dbh = DBI->connect($dsn, '', '',
				{ RaiseError => 0, PrintError => 0, AutoCommit => 1 });
			$dbh->do('pragma foreign_keys = ON');
			$dbh->do("create table webmin_$kind (id integer, name text)");
			$dbh->do("insert into webmin_$kind values (1, 'fixture')");
			# Defer value validation to exercise failed commits.
			$dbh->do('create table allowed_values (value text primary key)');
			$dbh->do("insert into allowed_values values ('deny'), ('allow')");
			my $table = "webmin_${kind}_acl";
			$dbh->do("create table $table (id integer, module text, ".
				"attr text check(length(attr) <= 32), value text ".
				"references allowed_values(value) deferrable initially deferred)");
			$dbh->do("insert into $table values (1, 'example', 'access', 'deny')");
			if ($failure eq 'delete') {
				# Fail before removing the old ACL.
				$dbh->do("create trigger reject_delete before delete on $table ".
					"begin select raise(abort, 'fixture delete denied'); end");
				}
			if ($failure =~ /^prepare_/) {
				# Fail one prepare without blocking the other.
				my $action = $failure eq 'prepare_delete'
					? SQLITE_DELETE : SQLITE_INSERT;
				# SQLite authorizer(action, ...): reject only
				# the chosen SQL operation.
				$dbh->sqlite_set_authorizer(sub {
					return $_[0] == $action ? SQLITE_DENY : SQLITE_OK;
					});
				}
			# connect_userdb(string): use SQLite as the SQL backend.
			local *main::connect_userdb = sub { ($dbh, 'mysql') };
			# Exercise cached and uncached connection cleanup.
			local %main::connect_userdb_cache = $cached
				? ( 'mysql://fixture' => [ $dbh ] ) : ( );
			local %main::connect_userdb_cache_time =
				( 'mysql://fixture' => time() );
			my $save = $kind eq 'user' ? \&main::save_module_acl
				: \&main::save_group_module_acl;
			# Trigger insert or commit failures with invalid values.
			my $attr = $failure eq 'insert' ? 'x' x 33 : 'access';
			my $value = $failure eq 'commit' ? 'invalid' : 'allow';
			eval { $save->({ $attr => $value }, 'fixture', 'example', 1); };
			if ($failure =~ /^prepare_/) {
				# Check the error text and the ACL type.
				like($@, qr/^e${kind}dbacl: not authorized/,
					"$label reports the prepare error");
				}
			elsif ($failure) {
				# Report the SQL error even after rollback.
				like($@, qr/fixture delete denied|constraint failed/,
					"$label reports the SQL error");
				}
			else {
				# Normal replacements must not raise an error.
				is($@, '', "$label reports no error");
				}
			if ($failure eq 'commit') {
				# Discard the failed handle and its cache entry.
				ok(!$dbh->{'Active'}, "$label closes the failed handle");
				ok(!exists($main::connect_userdb_cache{'mysql://fixture'}),
					"$label removes the failed cache entry");
				}
			# A second connection sees only committed ACLs.
			my $reader = DBI->connect($dsn, '', '', { RaiseError => 1 });
			is_deeply($reader->selectall_arrayref("select attr,value from $table"),
				[ [ 'access', $failure ? 'deny' : 'allow' ] ],
				"$label applies all ACL changes or none");
			# Release the reader and any cached writer.
			$reader->disconnect();
			# Uncached and failed handles may already be closed.
			$dbh->disconnect() if ($dbh->{'Active'});
			}
		}
	}
done_testing();
