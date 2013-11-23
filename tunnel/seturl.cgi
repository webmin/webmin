#!/usr/local/bin/perl
# Sets the URL cookie

require './tunnel-lib.pl';
&ReadParse();
&error_setup($text{'seturl_err'});

$in{'url'} = &fix_end_url($in{'url'}) || &error($text{'seturl_eurl'});

#$in{'url'} =~ /^(http|https):\/\/(\S+)$/ || &error($text{'seturl_eurl'});
&redirect("link.cgi/$in{'url'}");

