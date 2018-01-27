#!/opt/bin/perl
# closeall.cgi
# Empty the open list

require './software-lib.pl';
&save_heiropen([ ]);
&redirect("ipkg-tree.cgi");

