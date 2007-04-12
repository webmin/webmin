#!/usr/local/bin/perl
# delete_session.cgi
# Delete a single session

require './acl-lib.pl';
&ReadParse();
$access{'sessions'} || &error($text{'sessions_ecannot'});

&get_miniserv_config(\%miniserv);
&delete_session_id(\%miniserv, $in{'id'});
&restart_miniserv();
&redirect("list_sessions.cgi");

