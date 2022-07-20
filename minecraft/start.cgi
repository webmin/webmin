#!/usr/local/bin/perl
# Start the Minecraft server

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%text);
&error_setup($text{'start_err'});
my $err = &start_minecraft_server();
&error("<tt>".&html_escape($err)."</tt>") if ($err);
&webmin_log("start");
&redirect("");
