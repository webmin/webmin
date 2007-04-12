#!/usr/local/bin/perl
# never_save.cgi
# Save or delete an never_direct directive

require './squid-lib.pl';
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();

@never = &find_config("never_direct", $conf);
if (defined($in{'index'})) {
	$never = $conf->[$in{'index'}];
	}
if ($in{'delete'}) {
	# delete this restriction
	splice(@never, &indexof($never, @never), 1);
	}
else {
	# update or create
	@vals = ( $in{'action'} );
	foreach $y (split(/\0/, $in{'yes'})) { push(@vals, $y); }
	foreach $n (split(/\0/, $in{'no'})) { push(@vals, "!$n"); }
	$newnever = { 'name' => 'never_direct', 'values' => \@vals };
	if ($never) { splice(@never, &indexof($never, @never),
			      1, $newnever); }
	else { push(@never, $newnever); }
	}
&save_directive($conf, "never_direct", \@never);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $never ? 'modify' : 'create', "never");
&redirect("edit_icp.cgi");

