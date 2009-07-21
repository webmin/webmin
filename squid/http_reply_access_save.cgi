#!/usr/local/bin/perl
# http_reply_access_save.cgi
# Save or delete a proxy REPLY restriction

require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();
$whatfailed = $text{'sahttp_replyftspr'};

@http_replies = &find_config("http_reply_access", $conf);
if (defined($in{'index'})) {
	$http = $conf->[$in{'index'}];
	}
if ($in{'delete'}) {
	# delete this restriction
	splice(@http_replies, &indexof($http, @http_replies), 1);
	}
else {
	# update or create
	@vals = ( $in{'action'} );
	foreach $y (split(/\0/, $in{'yes'})) { push(@vals, $y); }
	foreach $n (split(/\0/, $in{'no'})) { push(@vals, "!$n"); }
	$newhttp = { 'name' => 'http_reply_access', 'values' => \@vals };
	if ($http) { splice(@http_replies, &indexof($http, @http_replies), 1, $newhttp); }
	else { push(@http_replies, $newhttp); }
	}
&save_directive($conf, "http_reply_access", \@http_replies);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $http ? 'modify' : 'create', "http");
&redirect("edit_acl.cgi?mode=reply");

