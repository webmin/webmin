#!/usr/local/bin/perl
# delete_session.cgi
# Delete a single session

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access, %sessiondb);
&ReadParse();
$access{'sessions'} || &error($text{'sessions_ecannot'});

my %miniserv;
&get_miniserv_config(\%miniserv);
&delete_session_id(\%miniserv, $in{'id'});
&restart_miniserv();
&redirect("list_sessions.cgi");

