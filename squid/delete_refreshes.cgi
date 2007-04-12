#!/usr/local/bin/perl
# Delete several refresh rules at once

require './squid-lib.pl';
&error_setup($text{'drefresh_err'});
$access{'refresh'} || &error($text{'refresh_ecannot'});
&ReadParse();
@d = split(/\0/, $in{'d'});
@d || &error($text{'drefesh_enone'});

# Do the delete
&lock_file($config{'squid_conf'});
$conf = &get_config();
@refresh = &find_config("refresh_pattern", $conf);
foreach $d (sort { $b <=> $a } @d) {
	$h = $conf->[$d];
	splice(@refresh, &indexof($h, @refresh), 1);
	}

# Write it out
&save_directive($conf, "refresh_pattern", \@refresh);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("delete", "refreshes", scalar(@d));
&redirect("list_refresh.cgi");

