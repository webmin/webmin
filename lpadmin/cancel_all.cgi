#!/usr/local/bin/perl
# Cancel some jobs on the selected printer

require './lpadmin-lib.pl';
&ReadParse();
&error_setup($text{'cancel_err'});
%d = map { $_, 1 } split(/\0/, $in{'d'});

@jobs = &get_jobs($in{'name'});
foreach $j (@jobs) {
	next if (!$d{$j->{'id'}});
	($ju = $j->{'user'}) =~ s/\!.*$//;
	&can_edit_jobs($in{'name'}, $ju) || &error($text{'cancel_ecannot'});
	&cancel_job($in{'name'}, $j->{'id'});
	}
&webmin_log("cancelsel", undef, $in{'name'},
	    { 'd' => scalar(keys %d) } );
&redirect("list_jobs.cgi?name=$in{'name'}");

