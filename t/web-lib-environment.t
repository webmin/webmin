#!/usr/bin/perl
# Tests nested environment cleanup and exact restoration.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $root = File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), '..'));
require File::Spec->catfile($root, 'web-lib-funcs.pl');

my %original = (
	'PATH' => '/bin:/usr/bin',
	'LANG' => 'de_DE.UTF-8',
	'WEBMIN_CONFIG' => '/etc/webmin',
	'HTTP_ACCEPT' => 'text/html',
	);

{
local %ENV = %original;
no warnings 'once';
local @main::clean_environment_stack;
local %main::UNCLEAN_ENV;

main::clean_environment();
$ENV{'WEBMIN_CONFIG'} = '/nested/etc/webmin';
main::clean_environment();
main::clean_language();
main::reset_environment();

is($ENV{'WEBMIN_CONFIG'}, '/nested/etc/webmin',
	'nested reset restores the outer cleaned environment');
ok(!exists($ENV{'HTTP_ACCEPT'}),
	'nested reset does not restore the original request environment');

main::reset_environment();
is_deeply({ %ENV }, \%original,
	'outer reset restores the original environment exactly');
}

done_testing();
