#!/usr/local/bin/perl
# unapply.cgi
# Copy the active firewall configuration to the save file

require './ipfw-lib.pl';
&lock_file($ipfw_file);
&system_logged("$config{'ipfw'} list > $ipfw_file");
&unlock_file($ipfw_file);
&webmin_log("unapply");
&redirect("");

