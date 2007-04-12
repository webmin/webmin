#!/usr/local/bin/perl
# cancel_all.cgi
# Cancel all print jobs on some printer

require './lpadmin-lib.pl';
&ReadParse();
&error_setup($text{'cancel_err'});

@jobs = &get_jobs($in{'name'});
foreach $j (@jobs) {
	($ju = $j->{'user'}) =~ s/\!.*$//;
	&can_edit_jobs($in{'name'}, $ju) || &error($text{'cancel_ecannot'});
	&cancel_job($in{'name'}, $j->{'id'});
	}
&webmin_log("cancel", "all", $in{'name'});
&redirect("list_jobs.cgi?name=$in{'name'}");

