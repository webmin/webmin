#!/usr/local/bin/perl
# Re-set the session user to be some other user, and redirect to /

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access, %sessiondb);
&ReadParse();
&can_edit_user($in{'user'}) && $access{'switch'} ||
	&error($text{'switch_euser'});

my %miniserv;
&get_miniserv_config(\%miniserv);
&open_session_db(\%miniserv);
my $skey = &session_db_key($main::session_id);
my ($olduser, $oldtime) = split(/\s+/, $sessiondb{$skey});
$olduser || &error($text{'switch_eold'});
$sessiondb{$skey} = "$in{'user'} $oldtime $ENV{'REMOTE_ADDR'}";
dbmclose(%sessiondb);
&reload_miniserv();
&webmin_log("switch", undef, $in{'user'});
&redirect("/");

