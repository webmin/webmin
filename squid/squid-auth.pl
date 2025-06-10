#!/usr/local/bin/perl
# squid-auth.pl
# A basic squid authentication program

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';

my %auth;
open(my $fh, "<".$ARGV[0]);
while(<$fh>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^(\S+):(\S+)/) {
		$auth{$1} = $2;
		}
	}
close($fh);

$| = 1;
while(<STDIN>) {
	s/\r|\n//g;
	my ($u, $p) = split(/\s+/, $_);
	print $auth{$u} &&
	      $auth{$u} eq crypt($p, $auth{$u}) ? "OK\n" : "ERR\n";
	}

