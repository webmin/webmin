#!/usr/local/bin/perl
# Delete a bunch of other caches

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
&error_setup($text{'deicp_err'});
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&ReadParse();
my @d = split(/\0/, $in{'d'});
@d || &error($text{'deicp_enone'});

# Get the existing entries
&lock_file($config{'squid_conf'});
my $conf = &get_config();
my $cache_host = $squid_version >= 2 ? "cache_peer" : "cache_host";
my @ch = &find_config($cache_host, $conf);
my @chd = &find_config($cache_host."_domain", $conf);

# Delete them
foreach my $d (sort { $b <=> $a } @d) {
	my $dom = $ch[$d]->{'values'}->[0];
	my $dir = $ch[$d];
	splice(@ch, $d, 1);

	# delete any cache_host directives as well
	for(my $i=0; $i<@chd; $i++) {
		if ($chd[$i]->{'values'}->[0] eq $dom) {
			splice(@chd, $i--, 1);
			}
		}
	}

# Write them out
&save_directive($conf, $cache_host, \@ch);
&save_directive($conf, $cache_host."_domain", \@chd);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("delete", "hosts", scalar(@d));
&redirect("edit_icp.cgi");

