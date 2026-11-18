#!/usr/bin/perl
# Check backup and export ACLs before any database or filesystem changes.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use FindBin;
use File::Temp qw(tempdir);
use File::Path qw(make_path);

my $root = $ENV{'POSTGRESQL_BACKUP_SOURCE'} || "$FindBin::Bin/..";
require "$FindBin::Bin/../web-lib-funcs.pl";
my $tmp = tempdir(TMPDIR => 1, CLEANUP => 1);
make_path("$tmp/allowed", "$tmp/outside");
symlink("$tmp/outside", "$tmp/allowed/escape") or die $!;

{
	package PgBackupFixture;
	our (%in, %access, %config, %module_info, %text, $expanded, @written);
	our ($bpath, $buser);
	# Stub request setup and stop at writes, leaving CGI validation intact.
	sub ReadParse { }
	sub error_setup { }
	sub can_edit_db { 1 }
	sub list_databases { 'fixture' }
	sub list_tables { () }
	sub accepting_connections { 1 }
	sub has_command { 1 }
	sub foreign_installed { 1 }
	sub foreign_require { }
	sub execute_before { 1 }
	sub ui_print_header { }
	sub ui_print_footer { }
	sub webmin_log { }
	sub error { die "ERROR: $_[0]\n" }
	sub text { join(' ', @_) }
	sub html_escape { main::html_escape(@_) }
	sub is_under_directory { main::is_under_directory(@_) }
	sub date_subs { defined($expanded) ? $expanded : $_[0] }
	# Model a privileged Webmin request even on a non-root test workstation.
	sub get_backup_limits {
		($access{'bpath'} || '/',
		 $access{'buser'} && $access{'buser'} ne 'root' ? $access{'buser'} : undef);
	}
	sub backup_database { @written = ('backup', @_); die "BACKUP\n" }
	sub make_backup_dir { @written = ('mkdir', @_); die "MKDIR\n" }
	sub save_module_config { die "SAVED\n" }
	sub save_user_module_config { die "PERSONAL\n" }
	sub quote_table { $_[0] }
	sub execute_sql { { titles => ['value'], data => [['fixture']] } }
	sub open_tempfile { @written = ('direct', @_); die "WRITE\n" }
	sub command_as_user { "AS $_[0]: $_[2]" }
	sub open_execute_command { @written = ('user', @_); die "WRITE\n" }
	sub ui_form_end { @written = map { $_->[0] } @{$_[0]}; die "FORM\n" }
	# Ignore form markup while retaining its actual save-button decisions.
	our $AUTOLOAD;
	sub AUTOLOAD { return '' if $AUTOLOAD =~ /::(?:ui_|file_chooser)/; die $AUTOLOAD }
}
{
	package cron;
	sub list_cron_jobs { () }
	sub parse_times_input { }
	sub get_times_input { '' }
}

# run_cgi(page, request, [ACL], [expanded-path]) returns the stopping point.
sub run_cgi
{
my ($page, $request, $acl, $expanded) = @_;
local %PgBackupFixture::in = (db => 'fixture', tables_def => 1,
	path => "$tmp/allowed/dump.sql", file => "$tmp/allowed/data.csv",
	format => 'p', cols => 'value', where_def => 1, %$request);
local %PgBackupFixture::access = (backup => 1, bpath => "$tmp/allowed",
	buser => 'nobody', %{$acl || {}});
local %PgBackupFixture::config = (dump_cmd => 'pg_dump');
local %PgBackupFixture::text = map { $_ => $_ }
	qw(backup_ecannot backup_esave csv_ebuser cvs_ebpath);
local $PgBackupFixture::expanded = $expanded;
local ($PgBackupFixture::bpath, $PgBackupFixture::buser);
local @PgBackupFixture::written;
local $INC{'./postgresql-lib.pl'} = 1;
my $output = '';
open(my $capture, '>', \$output) or die $!;
local *STDOUT = $capture;
{
	package PgBackupFixture;
	do "$root/postgresql/$page.cgi";
}
return ($@, [@PgBackupFixture::written], $output);
}

subtest 'restricted backup actions' => sub {
	my ($error, $written) = run_cgi('backup', {});
	is($error, "BACKUP\n", 'ordinary backup reaches the dump');
	is($written->[5], 'nobody', 'dump receives the restricted writer');
	($error, $written) = run_cgi('backup', {all => 1, mkdir => 1});
	is($error, "MKDIR\n", 'all-database backup creates its directory');
	is($written->[2], 'nobody', 'directory uses the restricted writer');
	for my $request ({save => 1}, {sched => 1}) {
		($error, $written) = run_cgi('backup', $request);
		like($error, qr/backup_esave/, 'restricted settings cannot be saved or scheduled');
		is_deeply($written, [], 'denial precedes writes');
	}
};

subtest 'backup path restrictions' => sub {
	for my $path ("$tmp/outside/dump.sql", "$tmp/allowed/escape/dump.sql") {
		my ($error, $written) = run_cgi('backup', {path => $path});
		like($error, qr/backup_eunder/, 'outside path is rejected');
		is_deeply($written, [], 'no backup starts');
	}
	my ($error) = run_cgi('backup', {}, {}, "$tmp/outside/expanded.sql");
	like($error, qr/backup_eunder/, 'expanded path is checked too');
	symlink("$tmp/outside/dump.sql", "$tmp/allowed/fixture.sql") or die $!;
	($error) = run_cgi('backup', {all => 1, path => "$tmp/allowed"});
	like($error, qr/backup_eunder/, 'each generated filename stays inside the allowed directory');
};

subtest 'CSV writer and permissions' => sub {
	my ($error, $written) = run_cgi('csv', {dest => 1});
	is($error, "WRITE\n", 'export reaches the writer');
	is($written->[0], 'user', 'restricted export uses a child writer');
	like($written->[2], qr/^AS nobody: cat >/, 'writer uses the ACL Unix user');
	($error, $written) = run_cgi('csv', {dest => 1}, {buser => 'root'});
	is($written->[0], 'direct', 'administrator keeps the direct writer');
	($error) = run_cgi('csv', {dest => 1}, {backup => 0});
	like($error, qr/csv_ebuser/, 'disabled backups produce a nonblank error');
	($error, $written) = run_cgi('csv', {dest => 1, file => "$tmp/outside/data.csv"});
	like($error, qr/cvs_ebpath/, 'outside CSV destination is denied');
	is_deeply($written, [], 'denied CSV does not open a writer');
	my $output;
	($error, $written, $output) = run_cgi('csv', {dest => 0}, {backup => 0});
	is($error, '', 'browser download does not require filesystem backup rights');
	like($output, qr/fixture/, 'browser download contains the data');
};

subtest 'administrator and form compatibility' => sub {
	# The fixture's default ACL limits the backup folder, so saving,
	# scheduling and the save button are refused.
	for my $action ('save', 'sched') {
		my ($error) = run_cgi('backup', {$action => 1}, {buser => 'root'});
		like($error, qr/backup_esave/, "directory limit prevents $action");
	}
	my (undef, $limited) = run_cgi('backup_form', {}, {buser => 'root'});
	is_deeply($limited, ['backup'], 'directory-limited form only offers backup');
	# Without a folder limit, root backups can still save settings.
	my ($error) = run_cgi('backup', {save => 1}, {buser => 'root', bpath => '/'});
	is($error, "SAVED\n", 'administrator can still save settings');
	for my $user ('nobody', 'root') {
		my ($error, $buttons) = run_cgi('backup_form', {}, {buser => $user, bpath => '/'});
		is($error, "FORM\n", "$user form renders");
		is_deeply($buttons, $user eq 'root' ? ['backup', 'save'] : ['backup'],
			"$user gets only permitted actions");
	}
};

subtest 'Usermin personal backup settings' => sub {
	local $PgBackupFixture::module_info{'usermin'} = 1;
	local %PgBackupFixture::userconfig;
	my (undef, $buttons) = run_cgi('backup_form', {});
	is_deeply($buttons, ['backup', 'save'], 'Usermin offers a personal save');
	my ($error) = run_cgi('backup', {save => 1, tables_def => 0,
		tables => "t1\0t2", compress => 1});
	is($error, "PERSONAL\n", 'Usermin saves to the personal config');
	is($PgBackupFixture::userconfig{'backup_tables_fixture'}, 't1 t2',
	   'personal save keeps the selected tables');
	is($PgBackupFixture::userconfig{'backup_compress_fixture'}, 1,
	   'personal save keeps compression');
	($error) = run_cgi('backup', {save => 1, sched => 1});
	like($error, qr/backup_esave/, 'Usermin cannot schedule a backup');
};
done_testing();
