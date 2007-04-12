#!/usr/local/bin/perl
# openall.cgi
# Add all classes to the open list

require './software-lib.pl';
$n = &list_packages();
for($i=0; $i<$n; $i++) {
	@w = split(/\//, $packages{$i,'class'});
	for($j=0; $j<@w; $j++) {
		push(@list, join('/', @w[0..$j]));
		}
	}
@list = &unique(@list);
&save_heiropen(\@list);
&redirect("tree.cgi");

