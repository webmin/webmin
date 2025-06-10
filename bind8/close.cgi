#!/usr/local/bin/perl
# Remove some zone from the open list
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals
our (%in);

require './bind8-lib.pl';
&ReadParse();
my @heiropen = &get_heiropen();
@heiropen = grep { $_ ne $in{'what'} } @heiropen;
&save_heiropen(\@heiropen);
&redirect("index.cgi#$in{'what'}");

