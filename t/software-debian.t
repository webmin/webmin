#!/usr/local/bin/perl

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use Cwd qw(abs_path);

our (%packages, %text);

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
chdir($root) or die "chdir($root): $!";

do './software/debian-lib.pl' or die $@ || $!;

my $dpkg_output = <<'EOF';
Desired=Unknown/Install/Remove/Purge/Hold
| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
+++-==============-=======-============-=================================
ii  installed       1.0    amd64        Installed package
iH  half-installed  1.1    amd64        Half-installed package
iU  unpacked        1.2    amd64        Unpacked package
iF  half-configured 1.3    amd64        Half-configured package
iW  triggers-await  1.4    amd64        Package awaiting triggers
it  triggers-pend   1.5    amd64        Package with pending triggers
rc  config-only     0.9    amd64        Removed package configuration
un  not-installed   <none> <none>       Package not installed
EOF

{
no warnings qw(once redefine);
local *open_execute_command = sub {
	my ($fh) = @_;
	no strict 'refs';
	open(ref($fh) ? $fh : \*{$fh}, '<', \$dpkg_output)
		or die "open simulated dpkg output: $!";
	};

my $count = list_packages();
is($count, 6, 'lists installed and partially installed packages');
is_deeply(
	[ map { $packages{$_,'name'} } 0 .. $count-1 ],
	[ qw(installed half-installed unpacked half-configured
	     triggers-await triggers-pend) ],
	'keeps every present package state and excludes removed packages');
}

sub package_info_for_status
{
my ($status) = @_;
no warnings qw(once redefine);
local *has_command = sub {
	return $_[0] eq 'apt-cache' ? '/usr/bin/apt-cache' : undef;
	};
local *html_escape = sub { return $_[0]; };
local *make_date = sub { return $_[0]; };
local *backquote_command = sub {
	my ($command) = @_;
	$? = 0;
	return "$status  php8.2-fpm 8.2.1 amd64 PHP FPM\n"
		if ($command =~ /^dpkg --list/);
	return "Package: php8.2-fpm\n".
	       "Version: 8.2.1\n".
	       "Architecture: amd64\n".
	       "Maintainer: Debian PHP Maintainers\n".
	       "Description: PHP FPM\n";
	};
return [ package_info('php8.2-fpm') ];
}

foreach my $status (qw(ii iH iU iF iW it)) {
	ok(@{package_info_for_status($status)},
		"returns details for package status $status");
	}
is_deeply(package_info_for_status('rc'), [],
	'does not return details for a removed package');
is_deeply(package_info_for_status('un'), [],
	'does not return details for a not-installed package');

done_testing();
