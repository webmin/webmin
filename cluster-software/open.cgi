#!/usr/local/bin/perl
# open.cgi
# Add some class to the open list

require './cluster-software-lib.pl';
&ReadParse();
@heir = &get_heiropen($in{'id'});
push(@heir, $in{'what'});
&save_heiropen(\@heir, $in{'id'});
&redirect("edit_host.cgi?id=$in{'id'}");

