#!/usr/local/bin/perl
# save_percents.cgi
# Save the list of % domains

require './qmail-lib.pl';
&ReadParseMime();

$in{'percents'} =~ s/\r//g;
@percents = split(/\s+/, $in{'percents'});
if (@percents) {
	&save_control_file("percenthack", \@percents);
	}
else {
	&save_control_file("percenthack", undef);
	}
&webmin_log("percents", undef, undef, \%in);
&redirect("");

