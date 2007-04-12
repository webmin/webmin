#!/usr/local/bin/perl
# Delete a bunch of other caches

require './squid-lib.pl';
&error_setup($text{'deicp_err'});
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&ReadParse();
@d = split(/\0/, $in{'d'});
@d || &error($text{'deicp_enone'});

# Get the existing entries
&lock_file($config{'squid_conf'});
$conf = &get_config();
$cache_host = $squid_version >= 2 ? "cache_peer" : "cache_host";
@ch = &find_config($cache_host, $conf);
@chd = &find_config($cache_host."_domain", $conf);

# Delete them
foreach $d (sort { $b <=> $a } @d) {
	$dom = $ch[$d]->{'values'}->[0];
	$dir = $ch[$d];
	splice(@ch, $d, 1);

	# delete any cache_host directives as well
	for($i=0; $i<@chd; $i++) {
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

