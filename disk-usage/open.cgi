#!/usr/local/bin/perl
# Add some directory to the open list

require './disk-usage-lib.pl';
&ReadParse();
@heiropen = &get_heiropen();
push(@heiropen, $in{'what'});
&save_heiropen(\@heiropen);
&redirect("index.cgi#$in{'what'}");

