#!/usr/local/bin/perl
# Tail the console log

use strict;
use warnings;
require './minecraft-lib.pl';
our (%config);
my $logfile = $config{'minecraft_dir'}."/server.log";

$| = 1;
&popup_header();
my $fh = "OUT";
&open_execute_command($fh, "tail -20f ".$logfile, 1, 1);
select($fh); $| = 1; select(STDOUT);
print "<pre>\n";
while(<$fh>) {
	print &html_escape($_);
	}
close($fh);
