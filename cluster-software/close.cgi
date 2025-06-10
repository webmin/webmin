#!/usr/local/bin/perl
# close.cgi
# Remove some class from the open list

require './cluster-software-lib.pl';
&ReadParse();
@heir = &get_heiropen($in{'id'});
@heir = grep { $_ ne $in{'what'} } @heir;
&save_heiropen(\@heir, $in{'id'});
&redirect("edit_host.cgi?id=$in{'id'}");

