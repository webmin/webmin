#!/usr/local/bin/perl
# Set the Usermin session cookie to be some other user

require './usermin-lib.pl';
&ReadParse();
$access{'sessions'} || &error($text{'sessions_ecannot'});

$url = &create_usermin_login_url($in{'user'});
&redirect($url);
&webmin_log("switch", undef, $in{'user'});

