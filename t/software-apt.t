#!/usr/local/bin/perl

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use Cwd qw(abs_path);

our %config;

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
chdir($root) or die "chdir($root): $!";

do './software/apt-lib.pl' or die $@ || $!;

is(strip_apt_package_arch('libtinfo6:amd64'), 'libtinfo6',
	'strips native Debian architecture suffix');
is(strip_apt_package_arch('libgomp1:i386'), 'libgomp1',
	'strips foreign Debian architecture suffix');
is(strip_apt_package_arch('ncurses-base'), 'ncurses-base',
	'leaves unqualified package names unchanged');

{
no warnings qw(once redefine);
local *backquote_command = sub {
	return "Inst libtinfo6:amd64 [6.3-2ubuntu0.1] ".
	       "(6.3-2ubuntu0.2 Ubuntu:22.04/jammy-updates [amd64])\n";
	};
local *clean_language = sub { };
local *reset_environment = sub { };

my @ops = update_system_operations('libtinfo6');
is($ops[0]->{'name'}, 'libtinfo6',
	'normalizes package names from simulated APT operations');
}

{
no warnings qw(once redefine);
my $apt_output = "Setting up libtinfo6:amd64 (6.3-2ubuntu0.2) ...\n";
my $yes_input = "";
local *additional_log = sub { };
local *backquote_logged = sub { return ""; };
local *clean_language = sub { };
local *html_escape = sub { return $_[0]; };
local *reset_environment = sub { };
local *text = sub { return $_[0]; };
local *transname = sub { return "/tmp/software-apt-test-yes"; };
local *open_tempfile = sub {
	my ($fh) = @_;
	no strict 'refs';
	open(ref($fh) ? $fh : \*{$fh}, ">", \$yes_input)
		or die "open temp input: $!";
	};
local *print_tempfile = sub {
	my ($fh, @text) = @_;
	no strict 'refs';
	my $handle = ref($fh) ? $fh : \*{$fh};
	print $handle @text;
	};
local *close_tempfile = sub {
	my ($fh) = @_;
	no strict 'refs';
	close(ref($fh) ? $fh : \*{$fh});
	};
local *open_execute_command = sub {
	my ($fh) = @_;
	no strict 'refs';
	open(ref($fh) ? $fh : \*{$fh}, "<", \$apt_output)
		or die "open simulated apt output: $!";
	};
local $config{'package_system'} = 'debian';

my $printed = "";
open(my $stdout, ">", \$printed) or die "open captured stdout: $!";
local *STDOUT = $stdout;
my @installed = update_system_install('libtinfo6', undef, 1);
is_deeply(\@installed, [ 'libtinfo6' ],
	'normalizes package names returned by apt install output');
}

done_testing();
