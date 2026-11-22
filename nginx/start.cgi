#!/usr/local/bin/perl
# Start the webserver

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
&error_setup($text{'start_err'});
$access{'stop'} || &error($text{'start_ecannot'});

my $err = &start_nginx();
$err && &error("<tt>".&html_escape($err)."</tt>");
&webmin_log("start");
# Return to the requested URL, referring page or module index
&redirect($in{'redir'} || &get_referer_relative() || "");
