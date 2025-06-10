#!/usr/local/bin/perl
# delete_session.cgi
# Delete a single session

require './usermin-lib.pl';
&ReadParse();
$access{'sessions'} || &error($text{'sessions_ecannot'});

&get_usermin_miniserv_config(\%miniserv);
&acl::delete_session_id(\%miniserv, $in{'id'});
&restart_usermin_miniserv();
&redirect("list_sessions.cgi");

