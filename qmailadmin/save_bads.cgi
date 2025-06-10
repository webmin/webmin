#!/usr/local/bin/perl
# save_bads.cgi
# Save the list of rejected addresses

require './qmail-lib.pl';
&ReadParseMime();

$in{'bads'} =~ s/\r//g;
@bads = split(/\n+/, $in{'bads'});
if (@bads) {
	&save_control_file("badmailfrom", \@bads);
	}
else {
	&save_control_file("badmailfrom", undef);
	}
&webmin_log("bads", undef, undef, \%in);
&redirect("");

