#!/usr/local/bin/perl
# Remove some directory from the open list

require './disk-usage-lib.pl';
&ReadParse();
@heiropen = &get_heiropen();
@heiropen = grep { $_ ne $in{'what'} } @heiropen;
&save_heiropen(\@heiropen);
&redirect("index.cgi#$in{'what'}");

