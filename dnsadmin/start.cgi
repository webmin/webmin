#!/usr/local/bin/perl
# start.cgi
# Start bind 4

require './dns-lib.pl';
system("$config{'named_pathname'} -b $config{'named_boot_file'} >/dev/null </dev/null");
&redirect("");

