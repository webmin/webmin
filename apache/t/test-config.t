#!/usr/bin/perl
# Tests for test_config, which must check the Apache config without waiting
# on a DNS lookup of the system hostname.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Cwd qw(abs_path);

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..', '..'));
my $tmp = abs_path(tempdir(CLEANUP => 1));
my $webmin_config = File::Spec->catdir($tmp, 'webmin-config');
my $webmin_var = File::Spec->catdir($tmp, 'webmin-var');
my $bin = File::Spec->catdir($tmp, 'bin');
my $log = File::Spec->catfile($tmp, 'commands.log');

# Paths with spaces check that the configured paths are used and quoted
my $apache_root = File::Spec->catdir($tmp, 'apache root');
my $apache_conf = File::Spec->catfile($apache_root, 'main config.conf');

make_path($webmin_config, $webmin_var, "$webmin_config/apache",
	  "$webmin_var/apache", $apache_root, $bin);

# write_text(file, text, [mode])
# Writes a file, optionally setting its permissions
sub write_text
{
my ($file, $text, $mode) = @_;
open(my $fh, '>', $file) || die "Failed to write $file: $!";
print $fh $text;
close($fh) || die "Failed to close $file: $!";
chmod($mode, $file) || die "Failed to chmod $file: $!" if (defined($mode));
}

# Shell snippet that logs the program name and its arguments, one per field
my $log_args = <<'EOF';
{ printf '%s' "$FAKE_NAME"; for a in "$@"; do printf '|%s' "$a"; done;
  printf '\n'; } >> "$FAKE_APACHE_LOG"
EOF

# Fake httpd, which passes or fails the test based on the environment
my $httpd = File::Spec->catfile($bin, 'httpd');
write_text($httpd, "#!/bin/sh\nFAKE_NAME=httpd\n".$log_args.<<'EOF', 0755);
if [ "$FAKE_APACHE_RESULT" = "error" ]; then
	echo "AH00526: Syntax error on line 2 of test.conf:"
	echo "Invalid command 'Bogus', perhaps misspelled"
	exit 1
fi
echo "Syntax OK"
EOF

# Debian-style apache2ctl, which passes extra arguments to httpd
my $debian_ctl = File::Spec->catfile($bin, 'debian-ctl');
write_text($debian_ctl,
	   "#!/bin/sh\nFAKE_NAME=apachectl\n".$log_args.<<"EOF", 0755);
case "\$*" in
configtest) exec "$httpd" -t ;;
*) exec "$httpd" "\$@" ;;
esac
EOF

# Red Hat-style apachectl, which refuses extra arguments
my $redhat_ctl = File::Spec->catfile($bin, 'redhat-ctl');
write_text($redhat_ctl,
	   "#!/bin/sh\nFAKE_NAME=apachectl\n".$log_args.<<"EOF", 0755);
if [ "x\$2" != "x" ]; then
	echo "Passing arguments to httpd using apachectl is no longer supported."
	exit 1
fi
case "\$1" in
configtest|-t) exec "$httpd" -t ;;
esac
exit 2
EOF

# Wrapper that only understands configtest
my $strict_ctl = File::Spec->catfile($bin, 'strict-ctl');
write_text($strict_ctl,
	   "#!/bin/sh\nFAKE_NAME=apachectl\n".$log_args.<<"EOF", 0755);
case "\$1" in
configtest) exec "$httpd" -t ;;
esac
echo "usage: apachectl configtest"
exit 2
EOF

write_text(File::Spec->catfile($webmin_config, 'config'),
	"os_type=debian-linux\n".
	"os_version=12\n".
	"real_os_type=Debian Linux\n".
	"real_os_version=12\n");
write_text(File::Spec->catfile($webmin_config, 'miniserv.conf'),
	"root=$root\n");
write_text(File::Spec->catfile($webmin_config, 'apache', 'config'),
	"httpd_dir=$apache_root\n".
	"httpd_path=$httpd\n".
	"httpd_conf=$apache_conf\n".
	"apachectl_path=$debian_ctl\n".
	"httpd_version=2.4.57\n".
	"test_apachectl=0\n".
	"test_config=1\n");

$ENV{'WEBMIN_CONFIG'} = $webmin_config;
$ENV{'WEBMIN_VAR'} = $webmin_var;
$ENV{'FOREIGN_MODULE_NAME'} = 'apache';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $root;
$ENV{'REMOTE_USER'} = 'root';
$ENV{'FAKE_APACHE_LOG'} = $log;
$ENV{'FAKE_APACHE_RESULT'} = 'ok';

unshift(@INC, $root);
require File::Spec->catfile($root, 'apache', 'apache-lib.pl');

{
	no warnings 'once';
	$main::httpd_modules{'core'} = 2.4;
}

# set_apache_conf(text)
# Writes the main Apache config file and clears the cached copy
sub set_apache_conf
{
my ($text) = @_;
write_text($apache_conf, $text);
main::flush_config_cache();
}

# A ServerName inside a virtual host is not global, so Apache still looks up
# the system hostname
my $no_global_name = "Listen 80\n".
		     "<VirtualHost *:80>\n".
		     "    ServerName vhost.example\n".
		     "</VirtualHost>\n";
set_apache_conf($no_global_name);

# Expected log lines for the fake commands
my $noname = 'ServerName localhost';
my $direct_fast = join('|', 'httpd', '-d', $apache_root, '-f', $apache_conf,
		       '-C', $noname, '-t');
my $direct_std = join('|', 'httpd', '-d', $apache_root, '-f', $apache_conf,
		      '-t');
my $ctl_fast = join('|', 'apachectl', '-C', $noname, '-t');
my $ctl_std = 'apachectl|configtest';
my $httpd_fast = join('|', 'httpd', '-C', $noname, '-t');
my $httpd_std = 'httpd|-t';

# run_test(test-apachectl, [apachectl-path], result)
# Runs test_config with the given settings, and returns its result and the
# commands it ran
sub run_test
{
my ($use_ctl, $ctl, $result) = @_;
no warnings 'once';
$main::config{'test_apachectl'} = $use_ctl;
$main::config{'apachectl_path'} = $ctl if ($ctl);
$ENV{'FAKE_APACHE_RESULT'} = $result;
unlink($log);
my $err = main::test_config();
my @cmds;
if (open(my $fh, '<', $log)) {
	chomp(@cmds = <$fh>);
	close($fh);
	}
return ($err, \@cmds);
}

subtest 'httpd test skips the hostname lookup' => sub {
	my ($err, $cmds) = run_test(0, undef, 'ok');
	is($err, undef, 'valid config passes');
	is_deeply($cmds, [ $direct_fast ],
		  'httpd runs once with configured paths and ServerName');
};

subtest 'httpd test reports config errors' => sub {
	my ($err, $cmds) = run_test(0, undef, 'error');
	like($err, qr/Syntax error on line 2/, 'error output is returned');
	is_deeply($cmds, [ $direct_fast, $direct_std ],
		  'failure is confirmed with the standard test');
};

subtest 'Debian apachectl passes ServerName to httpd' => sub {
	my ($err, $cmds) = run_test(1, $debian_ctl, 'ok');
	is($err, undef, 'valid config passes');
	is_deeply($cmds, [ $ctl_fast, $httpd_fast ],
		  'apachectl runs httpd with the placeholder ServerName');
};

subtest 'Debian apachectl reports config errors' => sub {
	my ($err, $cmds) = run_test(1, $debian_ctl, 'error');
	like($err, qr/Syntax error on line 2/, 'error output is returned');
	is_deeply($cmds, [ $ctl_fast, $httpd_fast, $ctl_std, $httpd_std ],
		  'failure is confirmed with apachectl configtest');
};

subtest 'Red Hat apachectl falls back to httpd' => sub {
	my ($err, $cmds) = run_test(1, $redhat_ctl, 'ok');
	is($err, undef, 'valid config passes');
	is_deeply($cmds, [ $ctl_fast, $direct_fast ],
		  'httpd is run directly when apachectl refuses arguments');
};

subtest 'Red Hat apachectl reports config errors' => sub {
	my ($err, $cmds) = run_test(1, $redhat_ctl, 'error');
	like($err, qr/Syntax error on line 2/, 'error output is returned');
	unlike($err, qr/no longer supported/,
	       'apachectl refusal is not reported as a config error');
	is_deeply($cmds, [ $ctl_fast, $direct_fast, $ctl_std, $httpd_std ],
		  'failure is confirmed with apachectl configtest');
};

subtest 'unknown apachectl falls back to configtest' => sub {
	my ($err, $cmds) = run_test(1, $strict_ctl, 'ok');
	is($err, undef, 'valid config passes');
	is_deeply($cmds, [ $ctl_fast, $ctl_std, $httpd_std ],
		  'standard test runs when apachectl rejects the arguments');
};

subtest 'global ServerName uses only the standard test' => sub {
	set_apache_conf("ServerName www.example.com\n".$no_global_name);
	my ($err, $cmds) = run_test(0, undef, 'ok');
	is($err, undef, 'valid config passes');
	is_deeply($cmds, [ $direct_std ], 'httpd runs without a placeholder');

	($err, $cmds) = run_test(1, $redhat_ctl, 'error');
	like($err, qr/Syntax error on line 2/, 'error output is returned');
	is_deeply($cmds, [ $ctl_std, $httpd_std ],
		  'apachectl configtest runs as before');
	set_apache_conf($no_global_name);
};

subtest 'global ServerName in an included file is found' => sub {
	# Webmin expands includes with glob(), which splits paths on spaces
	my $inc = File::Spec->catfile($tmp, 'servername.conf');
	write_text($inc, "ServerName www.example.com\n");
	set_apache_conf("Include $inc\n".$no_global_name);
	my ($err, $cmds) = run_test(1, $debian_ctl, 'ok');
	is($err, undef, 'valid config passes');
	is_deeply($cmds, [ $ctl_std, $httpd_std ],
		  'apachectl configtest runs as before');
	unlink($inc);
	set_apache_conf($no_global_name);
};

subtest 'old Apache versions are not tested' => sub {
	no warnings 'once';
	local $main::httpd_modules{'core'} = 1.3;
	my ($err, $cmds) = run_test(0, undef, 'error');
	is($err, undef, 'no error is reported');
	is_deeply($cmds, [ ], 'no test command runs');
};

done_testing();
