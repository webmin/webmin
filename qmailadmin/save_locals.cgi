#!/usr/local/bin/perl
# save_locals.cgi
# Save the list of local domains

require './qmail-lib.pl';
&ReadParseMime();

if ($in{'locals_def'}) {
	&save_control_file("locals", undef);
	}
else {
	$in{'locals'} =~ s/\r//g;
	@dlist = split(/\s+/, $in{'locals'});
	&save_control_file("locals", \@dlist);
	}
&restart_qmail();
&webmin_log("locals", undef, undef, \%in);
&redirect("");

