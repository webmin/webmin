#!/usr/local/bin/perl
# Save or delete an HTTP header access control rule

require './squid-lib.pl';
$access{'headeracc'} || &error($text{'headeracc_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();
&error_setup($text{'headeracc_err'});

@headeracc = &find_config("header_access", $conf);
if (defined($in{'index'})) {
	$h = $conf->[$in{'index'}];
	}
if ($in{'delete'}) {
	# delete this restriction
	splice(@headeracc, &indexof($h, @headeracc), 1);
	}
else {
	# update or create
	$in{'name'} =~ /^[a-z0-9\.\-\_]+$/i || &error($text{'header_ename'});
	@vals = ( $in{'name'}, $in{'action'} );
	foreach $y (split(/\0/, $in{'yes'})) { push(@vals, $y); }
	foreach $n (split(/\0/, $in{'no'})) { push(@vals, "!$n"); }
	$newh = { 'name' => 'header_access', 'values' => \@vals };
	if ($h) { splice(@headeracc, &indexof($h, @headeracc), 1, $newh); }
	else { push(@headeracc, $newh); }
	}
&save_directive($conf, "header_access", \@headeracc);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $h ? 'modify' : 'create',
	    "headeracc", $in{'name'});
&redirect("list_headeracc.cgi");

