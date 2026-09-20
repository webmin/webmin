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
	"\n".
	"    Require all granted\n".
	"</Directory>\n";
write_text($roundtrip, $roundtrip_text);
open(my $fh, '<', $roundtrip) || die "Failed to read $roundtrip: $!";
my $line = 0;
my @roundtrip_config = main::parse_config_file($fh, $line, $roundtrip);
close($fh) || die "Failed to close $roundtrip: $!";
my ($directory) =
	main::find_directive_struct('Directory', \@roundtrip_config);
my ($require) =
	main::find_directive_struct('Require', $directory->{'members'});
is_deeply($directory->{'comments'}, [ '# outer comment' ],
	'outer comment is attached to the directory');
is_deeply($require->{'comments'}, [ '    # nested comment', '' ],
	'nested comment block is attached to the following directive');
ok(!$roundtrip_config[0]->{'comments'} &&
   !$directory->{'members'}->[0]->{'comments'},
	'dummy block markers do not store comments');
is(join("\n", main::directive_lines(@roundtrip_config))."\n",
	$roundtrip_text, 'comments survive parsing and serialization');

# Rewriting and removing virtual hosts must handle attached comments with them.
my $vhosts_file = File::Spec->catfile($tmp, 'vhosts.conf');
my $first_vhost =
	"# first virtual host\n".
	"<VirtualHost *:80>\n".
	"    # first comment\n".
	"\n".
	"    ServerName first.example\n".
	"</VirtualHost>\n";
my $second_vhost =
	"# second virtual host\n".
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
is($vhosts[0]->{'line'}, 1, 'block line follows its attached comment');
is($vhosts[0]->{'eline'}, 5, 'member comment is included in block line count');
is($vhosts[1]->{'line'}, 7, 'next block follows its attached comment');

my %replacement = %{$vhosts[0]};
delete($replacement{'comments'});
$replacement{'value'} = '*:8080';
my $rewritten_first = $first_vhost;
$rewritten_first =~ s/\*:80>/*:8080>/;
main::save_directive_struct($vhosts[0], \%replacement,
	\@vhost_config, \@vhost_config);
main::flush_file_lines($vhosts_file);
is(read_text($vhosts_file), $rewritten_first.$second_vhost,
	'replacement block preserves surrounding comments');
is_deeply($replacement{'comments'}, [ '# first virtual host' ],
	'replacement block inherits attached comments');

main::save_directive_struct($vhosts[1], undef,
	\@vhost_config, \@vhost_config);
main::flush_file_lines($vhosts_file);
is(read_text($vhosts_file),
	$rewritten_first,
	'deleting a block removes its attached comment');

# Normal directive edits preserve comments, while deletion removes their owner.
my $directives_file = File::Spec->catfile($tmp, 'directives.conf');
my $directives_text =
	"# listen comment\n".
	"Listen 80\n".
	"# server name comment\n".
	"ServerName old.example\n";
write_text($directives_file, $directives_text);
open($fh, '<', $directives_file) ||
	die "Failed to read $directives_file: $!";
$line = 0;
my @directive_config =
	main::parse_config_file($fh, $line, $directives_file);
close($fh) || die "Failed to close $directives_file: $!";

main::save_directive('ServerName', [ 'new.example' ],
	\@directive_config, \@directive_config);
main::flush_file_lines($directives_file);
my $updated_directives =
	"# listen comment\n".
	"Listen 80\n".
	"# server name comment\n".
	"ServerName new.example\n";
is(read_text($directives_file), $updated_directives,
	'comments survive a normal directive edit');

main::save_directive('Listen', [ ], \@directive_config, \@directive_config);
main::flush_file_lines($directives_file);
my $deleted_directive =
	"# server name comment\n".
	"ServerName new.example\n";
is(read_text($directives_file), $deleted_directive,
	'deleting a directive removes its attached comment');

open($fh, '<', $directives_file) ||
	die "Failed to read $directives_file: $!";
$line = 0;
@directive_config = main::parse_config_file($fh, $line, $directives_file);
close($fh) || die "Failed to close $directives_file: $!";
my ($servername) =
	main::find_directive_struct('ServerName', \@directive_config);
is_deeply($servername->{'comments'},
	[ '# server name comment' ],
	'remaining comment stays attached to its directive');

# Nested block positions must include comments at every level.
my $inner = {
	'name' => 'Files', 'value' => '*.php', 'type' => 1,
	'comments' => [ '    # files comment' ],
	'members' => [
		{ 'name' => 'dummy', 'type' => 0 },
		{ 'name' => 'Require', 'value' => 'all denied',
		  'comments' => [ '        # access comment' ] },
		],
	};
my $outer = {
	'name' => 'Directory', 'value' => '/srv/example', 'type' => 1,
	'members' => [
		{ 'name' => 'dummy', 'type' => 0 },
		$inner,
		{ 'name' => 'Options', 'value' => 'Indexes' },
		],
	};
my @nested = ($outer);
my @nested_lines = main::directive_lines(@nested);
my $next_line = main::recursive_set_lines_files(\@nested, 20, $vhosts_file);
is($inner->{'line'}, 22, 'nested block line follows its comment');
is($inner->{'members'}->[1]->{'line'}, 24,
	'nested member line follows its comment');
is($outer->{'members'}->[2]->{'line'}, 26,
	'directive after nested block has the correct line');
is($outer->{'eline'}, 27, 'outer block ends after all nested lines');
is($next_line, 20 + scalar(@nested_lines),
	'line count matches nested serialized output');

# Comments on skipped conditionals must not move to a later directive.
my @skipped_conditionals = (
	[ 'IfModule',
	  '<IfModule webmin_test_missing_module.c>', '</IfModule>' ],
	[ 'IfDefine',
	  '<IfDefine WEBMIN_TEST_MISSING_DEFINE>', '</IfDefine>' ],
	[ 'IfVersion', '<IfVersion >= 999.0>', '</IfVersion>' ],
	);
foreach my $conditional (@skipped_conditionals) {
	my ($name, $opening, $closing) = @{$conditional};
	my $conditional_file =
		File::Spec->catfile($tmp, "skipped-$name.conf");
	write_text($conditional_file,
		"# skipped $name comment\n".
		"$opening\n".
		"    IgnoredDirective value\n".
		"$closing\n".
		"ServerName example.test\n");
	open($fh, '<', $conditional_file) ||
		die "Failed to read $conditional_file: $!";
	$line = 0;
	my @conditional_config =
		main::parse_config_file($fh, $line, $conditional_file);
	close($fh) || die "Failed to close $conditional_file: $!";
	my ($conditional_servername) =
		main::find_directive_struct('ServerName', \@conditional_config);
	ok(!$conditional_servername->{'comments'},
		"skipped $name comment is not attached to ServerName");
	}

done_testing();
