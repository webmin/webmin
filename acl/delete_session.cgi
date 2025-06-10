#!/usr/local/bin/perl
# delete_session.cgi
# Delete a single session

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access, %sessiondb);
&ReadParse();
$access{'sessions'} || &error($text{'sessions_ecannot'});

my %miniserv;
&get_miniserv_config(\%miniserv);
&delete_session_id(\%miniserv, $in{'id'});
&restart_miniserv();
&redirect($in{'redirect_ref'} ?
    &get_referer_relative() : "list_sessions.cgi");

