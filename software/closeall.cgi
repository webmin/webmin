#!/usr/local/bin/perl
# closeall.cgi
# Empty the open list

require './software-lib.pl';
&save_heiropen([ ]);
&redirect("tree.cgi");

