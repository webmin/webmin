#!/usr/local/bin/perl
# Add some zone to the open list

require './bind8-lib.pl';
&ReadParse();
@heiropen = &get_heiropen();
push(@heiropen, $in{'what'});
&save_heiropen(\@heiropen);
&redirect("index.cgi#$in{'what'}");

