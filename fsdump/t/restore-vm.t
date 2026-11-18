#!/usr/bin/perl
# Exercise the normal restore CGI with a private Webmin configuration.
use strict;
use warnings;
use Test::More;
use FindBin;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

plan skip_all => 'requires an explicitly enabled Linux debug guest'
	unless $ENV{'WEBMIN_FSDUMP_VM_TEST'} && $^O eq 'linux' && $> == 0;
my $src = abs_path("$FindBin::Bin/../..");
require "$src/t/test-lib.pl";
my $task = tempdir('fsdump-restore-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my $conf = "$task/conf";
my $allowed = "$task/allowed";
my $dest = "$allowed/restored files";
make_path("$conf/fsdump", "$conf/cron", "$conf/mount", "$conf/proc",
	  "$task/var", "$task/input", "$task/separate", $dest);
write_text("$conf/config", "os_type=generic-linux\nos_version=0\nlang=en\ntempdir=$task/tmp\n");
write_text("$conf/miniserv.conf", "root=$src\nport=10000\n");
write_text("$conf/webmin.acl", "operator: fsdump\nobserver: fsdump\nadmin: fsdump\n");
write_text("$conf/fsdump/operator.acl", "restore=1\nedit=0\ncmds=0\nextra=0\ndirs=$allowed\n");
write_text("$conf/fsdump/observer.acl", "restore=0\nedit=0\ncmds=0\nextra=0\ndirs=$allowed\n");
write_text("$conf/fsdump/admin.acl", "restore=1\nedit=1\ncmds=1\nextra=1\ndirs=*\n");
write_text("$task/input/report.txt", "restore fixture\n");
my $archive = "$allowed/daily backup.tar";
system('tar', 'cf', $archive, '-C', "$task/input", 'report.txt') == 0 or die 'tar';
chdir("$src/fsdump") or die $!;

# Run the CGI as the specified Webmin account with normal request parsing.
sub request
{
	my ($user, $script, %fields) = @_;
	my @parts;
	for my $name (sort keys %fields) {
		my $value = $fields{$name};
		$value =~ s/([^A-Za-z0-9_.-])/sprintf('%%%02X', ord($1))/ge;
		push(@parts, "$name=$value");
		}
	my $body = join('&', @parts);
	write_text("$task/request", $body);
	my $pid = fork();
	defined($pid) or die $!;
	if (!$pid) {
		@ENV{qw(WEBMIN_CONFIG WEBMIN_VAR SERVER_ROOT LIBROOT MINISERV_CONFIG
			REMOTE_USER SERVER_NAME SERVER_PORT HTTP_HOST HTTP_REFERER)} =
			($conf, "$task/var", $src, $src, "$conf/miniserv.conf", $user,
			 'localhost', 10000, 'localhost:10000', 'http://localhost:10000/');
		my $get = $script eq 'restore_form.cgi';
		@ENV{qw(SCRIPT_NAME REQUEST_METHOD QUERY_STRING CONTENT_TYPE CONTENT_LENGTH)} =
			("/fsdump/$script", $get ? 'GET' : 'POST', $get ? $body : '',
			 'application/x-www-form-urlencoded', $get ? 0 : length($body));
		open(STDIN, '<', "$task/request") or die $!;
		open(STDOUT, '>', "$task/response") or die $!;
		open(STDERR, '>&', \*STDOUT) or die $!;
		exec($^X, "-I$src", "-I$src/vendor_perl", "./$script") or die $!;
		}
	waitpid($pid, 0);
	return read_text("$task/response");
}

my %form = (fs => 'tar', mode => 0, file => $archive, dir => $dest,
	    files_def => 1, rsh_def => 0);
my $operator_form = request('operator', 'restore_form.cgi', fs => 'tar');
like($operator_form, qr/name=["']?files_def\b/i,
     'permitted operator can open the restore form');
unlike($operator_form, qr/name=["']?(?:rmt|perms)\b/i,
       'restricted form omits custom commands and permission preservation');
like(request('operator', 'restore.cgi', %form, test => 1), qr/report\.txt/,
     'preview lists the ordinary archive member');
ok(!-e "$dest/report.txt", 'preview leaves the directory empty');
my $denied = qr/You are not allowed to restore backups/;
like(request('observer', 'restore.cgi', %form), $denied,
     'restore permission is required');
like(request('operator', 'restore.cgi', %form, dir => "$task/separate"),
     $denied, 'an unlisted destination is refused');
like(request('operator', 'restore.cgi', %form, file => "$task/separate/copy.tar"),
     $denied, 'an unlisted local source is refused before opening it');
like(request('operator', 'restore.cgi', %form, extra => '-v'),
     $denied, 'even a harmless extra option needs permission');
like(request('operator', 'restore.cgi', %form, rmt => 'rmt'),
     qr/not allowed to choose a custom remote command/, 'custom commands need permission');
ok(!-e "$task/separate/report.txt" && !-e "$dest/report.txt",
   'refused operations leave both destinations unchanged');
like(request('operator', 'restore.cgi', %form), qr/Restore completed successfully/,
     'restore permission works without permission to edit backup jobs');
is(read_text("$dest/report.txt"), "restore fixture\n", 'restored contents match');
is((stat("$dest/report.txt"))[4], 0, 'the existing privileged executor restored the file');

# A full administrator can use a separate destination and preserve permissions.
my $admin_form = request('admin', 'restore_form.cgi', fs => 'tar');
like($admin_form, qr/name=["']?rmt\b/i, 'administrator can select a remote command');
like($admin_form, qr/name=["']?perms\b/i, 'administrator can preserve permissions');
like(request('admin', 'restore.cgi', %form, dir => "$task/separate",
             rmt_def => 1, perms => 1), qr/Restore completed successfully/,
     'unrestricted administrator can restore in a separate directory');
is(read_text("$task/separate/report.txt"), "restore fixture\n", 'administrator restored the file');

# Let GNU tar invoke the real volume-change callback for a name with spaces.
my $series = "$allowed/weekly backup";
my $contents = "quarterly report\n" x 1000;
write_text("$task/input/quarter.txt", $contents);
system('tar', '-cML', 10, '-f', "$series.1", '-f', "$series.2", '-f',
       "$series.3", '-C', "$task/input", 'quarter.txt') == 0 or die 'multivolume tar';
ok(-s "$series.2", 'archive spans more than one volume');
like(request('operator', 'restore.cgi', %form, file => $series, multi => 1),
     qr/Restore completed successfully/, 'restricted operator can restore numbered volumes');
is(read_text("$dest/quarter.txt"), $contents, 'all volumes restored the complete file');
done_testing();
