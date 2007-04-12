#!/usr/local/bin/perl
# Remove some zone from the open list

require './bind8-lib.pl';
&ReadParse();
@heiropen = &get_heiropen();
@heiropen = grep { $_ ne $in{'what'} } @heiropen;
&save_heiropen(\@heiropen);
&redirect("index.cgi#$in{'what'}");

