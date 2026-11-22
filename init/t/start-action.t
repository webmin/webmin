#!/usr/bin/perl
# Check systemd start results through the normal init dispatcher.
use strict;
use warnings;
use Test::More;
use FindBin;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $root = abs_path("$FindBin::Bin/../..");
require "$root/t/test-lib.pl";
my $dir = tempdir(CLEANUP => 1);
make_path("$dir/init", "$dir/scripts", "$dir/var");
write_text("$dir/config", "os_type=generic-linux\nos_version=0\n");
write_text("$dir/webmin.acl", "root: init\n");
write_text("$dir/init/config", "init_mode=systemd\ninit_dir=$dir/scripts\n");
@ENV{qw(WEBMIN_CONFIG WEBMIN_VAR SERVER_ROOT LIBROOT REMOTE_USER
	BASE_REMOTE_USER SCRIPT_NAME REQUEST_METHOD)} =
	($dir, "$dir/var", $root, $root, 'root', 'root', '/init/index.cgi', 'GET');
chdir("$root/init") or die $!;
unshift(@INC, $root);
local $0 = "$root/init/index.cgi";
do './init-lib.pl' or die $@ || $!;

# Stub command execution only. Keep the actual dispatcher and result handling.
foreach my $case ([ 0, '', 0 ], [ 256, 'See journalctl', 1 ],
		 [ 256, 'Start failed', 0 ]) {
	my ($exit, $output, $expected_journal) = @$case;
	my $journals = 0;
	no warnings qw(redefine once);
	local *main::backquote_logged = sub {
		$? = $exit;
		return $output;
		};
	local *main::backquote_command = sub {
		$journals++;
		$? = 0;
		return '\nJournal details';
		};
	my ($ok, $out) = start_action('fixture.service');
	is(!!$ok, !$exit, "start result survives diagnostics for exit $exit");
	is($journals, $expected_journal, 'journal is read only when suggested');
	is($out, $output.($expected_journal ? '\nJournal details' : ''),
	   'command output and any diagnostics are returned');
	}
done_testing();
