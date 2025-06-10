#!/usr/local/bin/perl
# openall.cgi
# Add all classes to the open list

require './cluster-software-lib.pl';
&ReadParse();
($host) = grep { $_->{'id'} eq $in{'id'} } &list_software_hosts();
foreach $p (@{$host->{'packages'}}) {
	@w = split(/\//, $p->{'class'});
	for($j=0; $j<@w; $j++) {
		push(@list, join('/', @w[0..$j]));
		}
	}
@list = &unique(@list);
&save_heiropen(\@list, $in{'id'});
&redirect("edit_host.cgi?id=$in{'id'}");

