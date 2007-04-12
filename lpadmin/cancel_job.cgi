#!/usr/local/bin/perl
# cancel_job.cgi
# Cancel an existing print job

require './lpadmin-lib.pl';
&ReadParse();
&error_setup($text{'cancel_err'});

@jobs = &get_jobs($in{'name'});
($j) = grep { $_->{'id'} eq $in{'id'} } @jobs;
if ($j) {
	# print job exists.. cancel it
	($ju = $j->{'user'}) =~ s/\!.*$//;
	&can_edit_jobs($in{'name'}, $ju) || &error($text{'cancel_ecannot'});
	&cancel_job($in{'name'}, $in{'id'});
	&webmin_log("cancel", "job", $in{'name'}, \%in);
	&redirect("list_jobs.cgi?name=$in{'name'}");
	}
else {
	&error(&text('cancel_egone', $in{'id'}));
	}

