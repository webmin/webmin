#!/usr/local/bin/perl
# Re-start the Minecraft server

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%text);
&error_setup($text{'restart_err'});
my $err = &stop_minecraft_server();
&error("<tt>".&html_escape($err)."</tt>") if ($err);
$err = &start_minecraft_server();
&error("<tt>".&html_escape($err)."</tt>") if ($err);
&webmin_log("restart");
&redirect("");
