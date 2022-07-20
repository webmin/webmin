#!/usr/local/bin/perl
# Delete multiple at jobs
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our(%access, %text, %in);

require './at-lib.pl';
&ReadParse();
&error_setup($text{'deletes_err'});
my @d = split(/\0/, $in{'d'});
@d || &error($text{'deletes_enone'});

# Delete each one
my @jobs = &list_atjobs();
foreach my $d (@d) {
	my ($job) = grep { $_->{'id'} eq $d } @jobs;
	$job || &error($text{'delete_egone'});
	&can_edit_user(\%access, $job->{'user'}) ||
		&error($text{'edit_ecannot'});
	&delete_atjob($job->{'id'});
	}
&webmin_log("delete", "jobs", scalar(@d));
&redirect("");

