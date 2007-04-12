#!/usr/local/bin/perl
# pool_access_save.cgi
# Save or delete a delay pool ACL

require './squid-lib.pl';
$access{'delay'} || &error($text{'delay_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();

@delays = &find_config("delay_access", $conf);
if (defined($in{'index'})) {
	$delay = $conf->[$in{'index'}];
	}
if ($in{'delete'}) {
	# delete this ACL
	splice(@delays, &indexof($delay, @delays), 1);
	}
else {
	# update or create
	@vals = ( $in{'idx'}, $in{'action'} );
	foreach $y (split(/\0/, $in{'yes'})) { push(@vals, $y); }
	foreach $n (split(/\0/, $in{'no'})) { push(@vals, "!$n"); }
	$newdelay = { 'name' => 'delay_access', 'values' => \@vals };
	if ($delay) { splice(@delays, &indexof($delay, @delays), 1, $newdelay);}
	else { push(@delays, $newdelay); }
	}
&save_directive($conf, "delay_access", \@delays);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $delay ? 'modify' : 'create', "delay",
	    $in{'idx'});
&redirect("edit_pool.cgi?idx=$in{'idx'}");

