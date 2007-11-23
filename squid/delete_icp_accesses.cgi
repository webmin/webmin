#!/usr/local/bin/perl
# Delete multiple proxy restrictions

require './squid-lib.pl';
&error_setup($text{'dicp_err'});
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
@d = split(/\0/, $in{'d'});
@d || &error($text{'dicp_enone'});

# Get the existing restrictions
&lock_file($config{'squid_conf'});
$conf = &get_config();
@icps = &find_config("icp_access", $conf);

# Delete them
foreach $d (sort { $b <=> $c } @d) {
	$icp = $conf->[$d];
	splice(@icps, &indexof($icp, @icps), 1);
	}

# Write out
&save_directive($conf, "icp_access", \@icps);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("delete", "icps", scalar(@d));
&redirect("edit_acl.cgi?mode=icp");

