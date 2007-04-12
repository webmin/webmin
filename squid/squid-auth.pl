#!/usr/local/bin/perl
# squid-auth.pl
# A basic squid authentication program

open(AUTH, $ARGV[0]);
while(<AUTH>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^(\S+):(\S+)/) {
		$auth{$1} = $2;
		}
	}
close(AUTH);

$| = 1;
while(<STDIN>) {
	s/\r|\n//g;
	local ($u, $p) = split(/\s+/, $_);
	print $auth{$u} &&
	      $auth{$u} eq crypt($p, $auth{$u}) ? "OK\n" : "ERR\n";
	}

