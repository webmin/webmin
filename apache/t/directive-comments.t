#!/usr/bin/perl
# Full-line comments must survive Apache block rewrites.

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

# Comments at multiple indentation levels must round-trip with the directives.
my $roundtrip = File::Spec->catfile($tmp, 'comments.conf');
my $roundtrip_text =
	"# outer comment\n".
	"<Directory /srv/example>\n".
	"    # nested comment\n".
	"    Require all granted\n".
	"</Directory>\n";
write_text($roundtrip, $roundtrip_text);
open(my $fh, '<', $roundtrip) || die "Failed to read $roundtrip: $!";
my $line = 0;
my @roundtrip_config = main::parse_config_file($fh, $line, $roundtrip);
close($fh) || die "Failed to close $roundtrip: $!";
is(join("\n", main::directive_lines(@roundtrip_config))."\n",
	$roundtrip_text, 'comments survive parsing and serialization');

# Rewriting and removing virtual hosts must retain comments in kept blocks and
# remove comments that belong to deleted blocks.
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

main::recursive_set_lines_files(\@vhost_config, 0, $vhosts_file);
is($vhosts[0]->{'eline'}, 3, 'comment is included in the block line count');
is($vhosts[1]->{'line'}, 4, 'next block starts after the preserved comment');

main::save_directive_struct($vhosts[0], $vhosts[0],
	\@vhost_config, \@vhost_config);
main::flush_file_lines($vhosts_file);
is(read_text($vhosts_file), $first_vhost.$second_vhost,
	'comments survive a block rewrite');

main::save_directive_struct($vhosts[1], undef,
	\@vhost_config, \@vhost_config);
main::flush_file_lines($vhosts_file);
is(read_text($vhosts_file), $first_vhost,
	'deleting a block removes only its comments');

done_testing();
