#!/usr/local/bin/perl
# Delete several refresh rules at once

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
&error_setup($text{'drefresh_err'});
$access{'refresh'} || &error($text{'refresh_ecannot'});
&ReadParse();
my @d = split(/\0/, $in{'d'});
@d || &error($text{'drefesh_enone'});

# Do the delete
&lock_file($config{'squid_conf'});
my $conf = &get_config();
my @refresh = &find_config("refresh_pattern", $conf);
foreach my $d (sort { $b <=> $a } @d) {
	my $h = $conf->[$d];
	splice(@refresh, &indexof($h, @refresh), 1);
	}

# Write it out
&save_directive($conf, "refresh_pattern", \@refresh);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("delete", "refreshes", scalar(@d));
&redirect("list_refresh.cgi");

