#!/usr/local/bin/perl
# Kill the running minecraft server process

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'stop_err'});
my $err = &stop_minecraft_server($in{'any'});
&error($err) if ($err);
&webmin_log("stop");
&redirect("");
