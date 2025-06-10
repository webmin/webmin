#!/usr/local/bin/perl
# open.cgi
# Add some class to the open list

require './software-lib.pl';
&ReadParse();
@heiropen = &get_heiropen();
push(@heiropen, $in{'what'});
&save_heiropen(\@heiropen);
&redirect("tree.cgi#".&urlize($in{'what'}));

