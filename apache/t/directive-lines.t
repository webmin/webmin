#!/usr/bin/perl
# Apache directive line numbers must match their serialized positions.

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
my $apache_root = File::Spec->catdir($tmp, 'apache2');
my $apache_conf = File::Spec->catfile($apache_root, 'apache2.conf');

make_path($webmin_config, $webmin_var, "$webmin_config/apache",
	  "$webmin_var/apache", $apache_root);

sub write_text
{
my ($file, $text) = @_;
open(my $fh, '>', $file) || die "Failed to write $file: $!";
print $fh $text;
close($fh) || die "Failed to close $file: $!";
}

sub read_text
{
my ($file) = @_;
open(my $fh, '<', $file) || die "Failed to read $file: $!";
local $/ = undef;
my $text = <$fh>;
close($fh) || die "Failed to close $file: $!";
return $text;
}

# Load the Apache module with an isolated Webmin configuration.
write_text(File::Spec->catfile($webmin_config, 'config'),
	"os_type=debian-linux\n".
	"os_version=12\n");
write_text(File::Spec->catfile($webmin_config, 'miniserv.conf'),
	"root=$root\n");
write_text(File::Spec->catfile($webmin_config, 'apache', 'config'),
	"httpd_dir=$apache_root\n".
	"httpd_path=/bin/true\n".
	"httpd_conf=$apache_conf\n".
	"apachectl_path=/bin/true\n".
	"httpd_version=2.4.57\n");
write_text($apache_conf, "Listen 80\n");

$ENV{'WEBMIN_CONFIG'} = $webmin_config;
$ENV{'WEBMIN_VAR'} = $webmin_var;
$ENV{'FOREIGN_MODULE_NAME'} = 'apache';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $root;
$ENV{'REMOTE_USER'} = 'root';

unshift(@INC, $root);
require File::Spec->catfile($root, 'apache', 'apache-lib.pl');

# Model a template containing <Files> inside <Directory>, followed by a
# directive whose position must include every line in both nested blocks.
my $inner_require = {
	'name' => 'Require', 'value' => 'all denied', 'indent' => 8,
	};
my $files = {
	'name' => 'Files', 'value' => '*.php', 'type' => 1, 'indent' => 4,
	'members' => [
		{ 'name' => 'dummy', 'type' => 0 },
		$inner_require,
		],
	};
my $directory = {
	'name' => 'Directory', 'value' => '/srv/example', 'type' => 1,
	'indent' => 0,
	'members' => [
		{ 'name' => 'dummy', 'type' => 0 },
		{ 'name' => 'Require', 'value' => 'all granted', 'indent' => 4 },
		$files,
		],
	};
my $alias = {
	'name' => 'ScriptAlias', 'value' => '/cgi-bin/ /srv/cgi-bin/',
	'indent' => 0,
	};
my @directives = ($directory, $alias);
my @lines = main::directive_lines(@directives);
my $next = main::recursive_set_lines_files(\@directives, 10, '/tmp/test.conf');

is($directory->{'line'}, 10, 'outer block starts at the first line');
is($files->{'line'}, 12, 'nested block starts after the outer directive');
is($inner_require->{'line'}, 13, 'nested member has its serialized line');
is($files->{'eline'}, 14, 'nested block ends after all of its members');
is($directory->{'eline'}, 15, 'outer block includes the nested closing line');
is($alias->{'line'}, 16, 'following directive starts after the outer block');
is($next, 10 + scalar(@lines), 'returned line follows serialized output');

# Parsed comments are not Apache directives, but block rewrites must retain
# their text and indentation around nested containers.
my $roundtrip = File::Spec->catfile($tmp, 'comments.conf');
my $roundtrip_text =
	"# outer comment\n".
	"<Directory /srv/example>\n".
	"    # nested comment\n".
	"    <Files *.php>\n".
	"        Require all denied\n".
	"    </Files>\n".
	"</Directory>\n";
write_text($roundtrip, $roundtrip_text);
open(my $fh, '<', $roundtrip) || die "Failed to read $roundtrip: $!";
my $line = 0;
my @parsed = main::parse_config_file($fh, $line, $roundtrip);
close($fh) || die "Failed to close $roundtrip: $!";
is(join("\n", main::directive_lines(@parsed))."\n", $roundtrip_text,
	'comments survive parsing and serialization');

# Removing one of two parsed virtual hosts must use spans that include their
# comments, or remnants of the removed block will make Apache invalid.
my $vhosts_file = File::Spec->catfile($tmp, 'vhosts.conf');
my $first_vhost =
	"<VirtualHost *:80>\n".
	"    # first comment\n".
	"    ServerName first.example\n".
	"</VirtualHost>\n";
my $second_vhost =
	"<VirtualHost *:443>\n".
	"    # second comment\n".
	"    ServerName second.example\n".
	"</VirtualHost>\n";
write_text($vhosts_file, $first_vhost.$second_vhost);
open($fh, '<', $vhosts_file) || die "Failed to read $vhosts_file: $!";
$line = 0;
my @vhost_config = main::parse_config_file($fh, $line, $vhosts_file);
close($fh) || die "Failed to close $vhosts_file: $!";
my @vhosts = main::find_directive_struct('VirtualHost', \@vhost_config);
main::save_directive_struct($vhosts[1], undef,
	\@vhost_config, \@vhost_config);
main::flush_file_lines($vhosts_file);
is(read_text($vhosts_file), $first_vhost,
	'removing a block also removes all of its comments');

done_testing();
