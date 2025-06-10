#!/usr/local/bin/perl
# Sets the URL cookie

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%config, %text, %module_info, %in);
require './tunnel-lib.pl';
&ReadParse();
&error_setup($text{'seturl_err'});

$in{'url'} = &fix_end_url($in{'url'}) || &error($text{'seturl_eurl'});

#$in{'url'} =~ /^(http|https):\/\/(\S+)$/ || &error($text{'seturl_eurl'});
&redirect("link.cgi/$in{'url'}");

