#!/usr/local/bin/perl
# Add some zone to the open list
use strict;
use warnings;
our (%in);

require './bind8-lib.pl';
&ReadParse();
my @heiropen = &get_heiropen();
push(@heiropen, $in{'what'});
&save_heiropen(\@heiropen);
&redirect("index.cgi#$in{'what'}");

