#!/usr/bin/perl
# Run as root on a disposable Linux VM with PostgreSQL, passing a source tree.
# Use temporary databases, a role and files. Installed Webmin files are untouched.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use IPC::Open3;
use Symbol qw(gensym);

die "Disposable root Linux VM required\n" unless $^O eq 'linux' && $> == 0;
my ($source) = @ARGV;
die "Pass a source tree under /tmp\n" unless $source && $source =~ m{^/tmp/};
require "$source/web-lib-funcs.pl";
my $task = tempdir('pg-backup-fixture-XXXXXX', DIR => '/tmp', CLEANUP => 1);
chmod(0755, $task) or die $!;
my $name = 'webmin_pg_backup_'.$$;
my ($role_created, $db_created);
my @nobody = getpwnam('nobody');
@nobody or die "Missing nobody account\n";

# admin_sql(sql, [database]) runs fixture SQL without exposing credentials.
sub admin_sql
{
my ($sql, $database) = @_;
my ($input, $output);
my $errors = gensym();
my $pid = open3($input, $output, $errors, 'runuser', '-u', 'postgres', '--',
	'psql', '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-d', $database || 'postgres');
print $input $sql;
close($input);
my $out = do { local $/; <$output> };
my $err = do { local $/; <$errors> };
waitpid($pid, 0);
die "PostgreSQL fixture SQL failed\n" if $?;
return $out;
}

# cleanup() removes only this run's database and role, including on failure.
sub cleanup
{
if ($db_created) {
	admin_sql("drop database $name with (force)");
	$db_created = 0;
	}
if ($role_created) {
	admin_sql("drop role $name");
	$role_created = 0;
	}
}
END { cleanup(); }

# Load the changed helpers without initializing installed module settings.
open(my $library, '<', "$source/postgresql/postgresql-lib.pl") or die $!;
my $code = do { local $/; <$library> };
close($library);
for my $name (qw(backup_database make_backup_dir command_with_login
		 host_port_flags get_backup_limits)) {
	my ($sub) = $code =~ /^(sub \Q$name\E\n\{.*?^\})/ms;
	# Older source lacks get_backup_limits; the other tests still reproduce it.
	next if !$sub && $name eq 'get_backup_limits';
	die "Missing $name\n" unless $sub;
	eval "no strict; $sub";
	die $@ if $@;
	}
our (%config, %gconfig, %access, %in, %text, $postgres_sameunix,
     $postgres_login, $postgres_pass, $null_file, $buser, $bpath);
%gconfig = (os_type => 'debian-linux');
%config = (dump_cmd => '/usr/bin/pg_dump');
$null_file = '/dev/null';
my $temporary = 0;
local *main::transname = sub { "$task/login-".++$temporary };
local *main::supports_pgpass = sub { 1 };
local *main::get_module_name = sub { 'postgresql' };
local *main::get_miniserv_config = sub { %{$_[0]} = (); };
local *main::is_readonly_mode = sub { 0 };
local *main::error = sub { die "$_[0]\n" };

# Generate credentials in guest memory and create a narrowly owned database.
open(my $random, '<', '/dev/urandom') or die $!;
read($random, my $bytes, 24) == 24 or die "Cannot generate fixture password\n";
close($random);
my $password = unpack('H*', $bytes);
admin_sql("create role $name login password '$password'");
$role_created = 1;
admin_sql("create database $name owner $name");
$db_created = 1;
admin_sql("set role $name; create table fixture (value text); ".
	"insert into fixture values ('backup-permission-marker');", $name);
make_path("$task/allowed", "$task/shared", "$task/denied");
chown($nobody[2], $nobody[3], "$task/allowed") or die $!;
chmod(0700, "$task/allowed", "$task/denied") == 2 or die $!;
chmod(0777, "$task/shared") or die $!;

# Exercise real pg_dump with peer and password logins and every output format.
for my $peer (1, 0) {
	$postgres_sameunix = $peer;
	$postgres_login = $peer ? 'postgres' : $name;
	$postgres_pass = $peer ? '' : $password;
	$config{'host'} = $peer ? '' : '127.0.0.1';
	for my $format ('p', 't', 'c') {
		for my $compress (0, 1, 2) {
			my $label = "peer=$peer format=$format compression=$compress";
			my $path = "$task/allowed/dump-$peer-$format-$compress";
			my $error = main::backup_database($name, $path, $format, [],
				'nobody', $compress);
			is($error, undef, "$label succeeds");
			is((stat($path))[4], $nobody[2], "$label is owned by the backup user");
			# Decode the archive and verify real table data, not an empty dump.
			my $decoded = "$task/decoded";
			my $decoder = $compress == 1 ? 'gzip -dc' :
				$compress == 2 ? 'bzip2 -dc' : 'cat';
			my $status = system("$decoder ".quotemeta($path)." >".quotemeta($decoded));
			is($status, 0, "$label decodes");
			my $contents = $format eq 'p' ? main::read_file_contents($decoded) :
				`pg_restore -f - $decoded 2>/dev/null`;
			like($contents, qr/backup-permission-marker/, "$label contains the table data");
			}
		}
	my $error = main::backup_database($name, "$task/denied/dump-$peer", 'p', [],
		'nobody', 0);
	like($error || '', qr/denied/i, "peer=$peer reports an unwritable destination");
	ok(!-e "$task/denied/dump-$peer", "peer=$peer cannot write as root");
	$error = main::backup_database($name.'_missing', "$task/allowed/missing-$peer", 'p', [],
		'nobody', 0);
	like($error || '', qr/does not exist|failed/i, "peer=$peer reports dump failures");
	my $path = "$task/shared/default-$peer";
	$error = main::backup_database($name, $path, 'p', [], undef, 0);
	is($error, undef, "peer=$peer keeps ordinary backups working");
	is((stat($path))[4], $peer ? (getpwnam('postgres'))[2] : 0,
		"peer=$peer retains default ownership");
	}

# Directory creation must use the same filesystem permissions as the writer.
main::make_backup_dir("$task/allowed/new/nested", 'nobody');
is((stat("$task/allowed/new/nested"))[4], $nobody[2], 'new directories use the backup user');
main::make_backup_dir("$task/denied/new", 'nobody');
ok(!-e "$task/denied/new", 'directory creation cannot bypass permissions');

# Run the actual CSV CGI with real writer processes and fixed query results.
local $INC{'./postgresql-lib.pl'} = 1;
local *main::ReadParse = sub { };
local *main::error_setup = sub { };
local *main::can_edit_db = sub { 1 };
local *main::quote_table = sub { $_[0] };
local *main::execute_sql = sub { { data => [['backup-permission-marker']] } };
local *main::ui_print_header = sub { };
local *main::ui_print_footer = sub { };
local *main::get_databases_return_link = sub { '' };
local *main::text = sub { join(' ', @_) };
%text = (csv_ewrite => 'Failed to write destination file', cvs_ebpath => 'outside allowed path');
for my $case ('allowed', 'denied', 'outside') {
	%in = (db => $name, dest => 1, file => "$task/$case/data.csv",
		cols => 'value', table => 'fixture', where_def => 1, format => 0);
	%access = (backup => 1, bpath => $case eq 'outside' ? "$task/allowed" : $task,
		buser => 'nobody');
	($bpath, $buser) = (undef, undef);
	my $html = '';
	open(my $capture, '>', \$html) or die $!;
	my $error;
	{
		local *STDOUT = $capture;
		do "$source/postgresql/csv.cgi";
		$error = $@;
	}
	if ($case eq 'allowed') {
		is($error, '', 'CSV export succeeds');
		is((stat($in{'file'}))[4], $nobody[2], 'CSV is owned by the backup user');
		like(main::read_file_contents($in{'file'}), qr/backup-permission-marker/,
			'CSV contains the selected data');
		}
	else {
		like($error, $case eq 'denied' ? qr/csv_ewrite/ : qr/outside allowed path/,
			"CSV $case destination reports failure");
		ok(!-e $in{'file'}, "CSV $case cannot create a file");
		unlike($html, qr/csv_done/, "CSV $case never reports success");
		}
	}
cleanup();
diag('Fixture database and role removed; temporary files are cleaned on exit');
done_testing();
