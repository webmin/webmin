#!/usr/local/bin/perl
# http_access_save.cgi
# Save or delete a proxy restriction

require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();
$whatfailed = $text{'sahttp_ftspr'};

@https = &find_config("http_access", $conf);
if (defined($in{'index'})) {
	$http = $conf->[$in{'index'}];
	}
if ($in{'delete'}) {
	# delete this restriction
	splice(@https, &indexof($http, @https), 1);
	}
else {
	# update or create
	@vals = ( $in{'action'} );
	foreach $y (split(/\0/, $in{'yes'})) { push(@vals, $y); }
	foreach $n (split(/\0/, $in{'no'})) { push(@vals, "!$n"); }
	$newhttp = { 'name' => 'http_access', 'values' => \@vals };
	if ($http) { splice(@https, &indexof($http, @https), 1, $newhttp); }
	else { push(@https, $newhttp); }
	}
&save_directive($conf, "http_access", \@https, "acl");
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $http ? 'modify' : 'create', "http");
&redirect("edit_acl.cgi?mode=http");

