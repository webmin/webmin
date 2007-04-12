#!/usr/local/bin/perl
# Sets the URL cookie

require './tunnel-lib.pl';
&ReadParse();
&error_setup($text{'seturl_err'});
$in{'url'} =~ /^(http|https):\/\/(\S+)$/ || &error($text{'seturl_eurl'});
&redirect("link.cgi/$in{'url'}");

