#!/usr/bin/perl
# Tests that directive words keep their text through write, read and form
# round trips, and that quoting stops a value from adding directives.

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
make_path($webmin_config, $webmin_var, "$webmin_config/nginx");

# write_text(file, text)
# Writes a fixture file or dies
sub write_text
{
my ($file, $text) = @_;
open(my $fh, '>', $file) || die "Failed to write $file: $!";
print $fh $text;
close($fh) || die "Failed to close $file: $!";
}

write_text("$webmin_config/config",
	"os_type=unix\nos_version=1\nreal_os_type=Unix\nreal_os_version=1\n");
write_text("$webmin_config/miniserv.conf", "root=$root\n");
write_text("$webmin_config/nginx/config",
	"nginx_config=$tmp/nginx.conf\nnginx_cmd=/bin/true\n");

$ENV{'WEBMIN_CONFIG'} = $webmin_config;
$ENV{'WEBMIN_VAR'} = $webmin_var;
$ENV{'FOREIGN_MODULE_NAME'} = 'nginx';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $root;
$ENV{'REMOTE_USER'} = 'root';

unshift(@INC, $root);
require File::Spec->catfile($root, 'nginx', 'nginx-lib.pl');
{
	no warnings 'once';
	$main::error_must_die = 1;
}

# parse_line(text)
# Returns the words of a single directive written to a temporary file
my $n = 0;
sub parse_line
{
my ($line) = @_;
my $file = "$tmp/line".($n++).".conf";
write_text($file, "$line\n");
main::flush_config_cache();
my $conf = main::read_config_file($file, 1);
return $conf->[0]->{'words'};
}

# Words that Virtualmin writes must keep their existing text
my @fixed = (
	[ [ '~', '\.php(/|$)' ], '~ "\.php(/|$)"' ],
	[ [ '^(.+\.php)(/.+)$' ], '"^(.+\.php)(/.+)$"' ],
	[ [ '^/(?!\.well-known(?:/|$))(.*)$', 'https://$host$1', 'break' ],
	  '"^/(?!\.well-known(?:/|$))(.*)$" "https://$host$1" break' ],
	[ [ '$uri', '$fastcgi_script_name', '=404' ],
	  '$uri $fastcgi_script_name =404' ],
	[ [ 'SCRIPT_FILENAME', '$document_root$fastcgi_script_name' ],
	  'SCRIPT_FILENAME $document_root$fastcgi_script_name' ],
	[ [ '~', '/\.htpasswd$' ], '~ "/\.htpasswd$"' ],
	[ [ 'main', '$remote_addr - [$time_local] "$request"' ],
	  q{main '$remote_addr - [$time_local] "$request"'} ],
	[ [ '/srv/two words', '' ], '"/srv/two words" ""' ],
	);
foreach my $f (@fixed) {
	is(main::join_words(@{$f->[0]}), $f->[1],
	   "written text for @{$f->[0]}");
	is_deeply(parse_line("x ".$f->[1].";"), $f->[0],
		  "read back @{$f->[0]}");
	}

# Values with quotes and backslashes must read back unchanged
my @tricky = (
	'~^(www\.)?(?<d>.+)\.example\.com$',
	q{Ops' "West" #4},
	'a\\b', 'a\\\\b', 'a\\"b', q{a\\'b}, 'end\\', 'end\\\\', '\\d+',
	q{x"; access_log /etc/cron.d/p; #},
	q{x'; access_log /etc/cron.d/p; #},
	);
foreach my $w (@tricky) {
	my $text = main::join_words($w, 'next');
	is_deeply(parse_line("x $text;"), [ $w, 'next' ],
		  "file round trip for $w");

	# Forms show join_words output and read it back with split_words
	my @once = main::split_words(" ".$text);
	is_deeply(\@once, [ $w, 'next' ], "form round trip for $w");
	is(main::join_words(@once), $text, "form save is stable for $w");
	}

# Existing regex values keep their text across repeated saves
my $sn = '"~^(www\.)?(?<d>.+)\.example\.com$" example.com';
my $words = parse_line("server_name $sn;");
is(main::join_words(@$words), $sn, 'regex server name keeps its text');
is(main::join_words(main::split_words(" ".main::join_words(@$words))), $sn,
   'regex server name is stable after two form saves');

# Line breaks cannot be written into a directive
ok(!eval { main::join_words("a\nb"); 1 }, 'newline in a word is rejected');

done_testing();
