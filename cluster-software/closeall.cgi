#!/usr/local/bin/perl
# closeall.cgi
# Empty the open list

require './cluster-software-lib.pl';
&ReadParse();
&save_heiropen([ ], $in{'id'});
&redirect("edit_host.cgi?id=$in{'id'}");

