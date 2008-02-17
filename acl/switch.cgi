#!/usr/local/bin/perl
# Re-set the session user to be some other user, and redirect to /

require './acl-lib.pl';
&ReadParse();
&can_edit_user($in{'user'}) && $access{'switch'} ||
	&error($text{'switch_euser'});

&get_miniserv_config(\%miniserv);
&open_session_db(\%miniserv);
$skey = &session_db_key($main::session_id);
($olduser, $oldtime) = split(/\s+/, $sessiondb{$skey});
$olduser || &error($text{'switch_eold'});
$sessiondb{$skey} = "$in{'user'} $oldtime $ENV{'REMOTE_ADDR'}";
dbmclose(%sessiondb);
&reload_miniserv();
&webmin_log("switch", undef, $in{'user'});
&redirect("/");

