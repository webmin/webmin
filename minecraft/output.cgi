#!/usr/local/bin/perl
# Tail the console log

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%config);
my $logfile = &get_minecraft_log_file();

$| = 1;
&popup_header();
my $fh = "OUT";
&open_execute_command($fh, "tail -40f ".$logfile, 1, 1);
select($fh); $| = 1; select(STDOUT);
print "<pre>\n";
while(<$fh>) {
	print &html_escape($_);
	}
close($fh);
