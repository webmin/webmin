#!/usr/local/bin/perl
# Delete multiple proxy REPLY restrictions

require './squid-lib.pl';
&error_setup($text{'dhttp_err'});
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
@d = split(/\0/, $in{'d'});
@d || &error($text{'dhttp_enone'});

# Get the existing restrictions
&lock_file($config{'squid_conf'});
$conf = &get_config();
@http_replies = &find_config("http_reply_access", $conf);

# Delete them
foreach $d (sort { $b <=> $c } @d) {
	$http_reply = $conf->[$d];
	splice(@http_replies, &indexof($http_reply, @http_replies), 1);
	}

# Write out
&save_directive($conf, "http_reply_access", \@http_replies);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("delete", "http_replies", scalar(@d));
&redirect("edit_acl.cgi?mode=reply");
