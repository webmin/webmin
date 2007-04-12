#!/usr/local/bin/perl
# icp_access_save.cgi
# Save or delete a proxy restriction

require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();
$whatfailed = $text{'saicp_ftsir'};

@icps = &find_config("icp_access", $conf);
if (defined($in{'index'})) {
	$icp = $conf->[$in{'index'}];
	}
if ($in{'delete'}) {
	# delete this restriction
	splice(@icps, &indexof($icp, @icps), 1);
	}
else {
	# update or create
	@vals = ( $in{'action'} );
	foreach $y (split(/\0/, $in{'yes'})) { push(@vals, $y); }
	foreach $n (split(/\0/, $in{'no'})) { push(@vals, "!$n"); }
	$newicp = { 'name' => 'icp_access', 'values' => \@vals };
	if ($icp) { splice(@icps, &indexof($icp, @icps), 1, $newicp); }
	else { push(@icps, $newicp); }
	}
&save_directive($conf, "icp_access", \@icps);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $icp ? 'modify' : 'create', "icp");
&redirect("edit_acl.cgi");

