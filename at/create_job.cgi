#!/usr/local/bin/perl
# create_job.cgi
# Create a new at job
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in);

require './at-lib.pl';
use Time::Local;
&ReadParse();
&error_setup($text{'create_err'});

# Validate inputs
&can_edit_user(\%access, $in{'user'}) || &error($text{'create_ecannot'});
defined(getpwnam($in{'user'})) || &error($text{'create_euser'});
&can_use_at($in{'user'}) || &error($text{'create_eallow'});
$in{'hour'} =~ /^\d+$/ && $in{'min'} =~ /^\d+$/ &&
	$in{'day'} =~ /^\d+$/ && $in{'year'} =~ /^\d+$/ ||
		&error($text{'create_edate'});
my $date;
eval { $date = timelocal(0, $in{'min'}, $in{'hour'},
		         $in{'day'}, $in{'month'}, $in{'year'}-1900) };
$@ && &error($text{'create_edate'});
$date > time() || &error($text{'create_efuture'});
$in{'cmd'} =~ s/\r//g;
$in{'cmd'} =~ /\S/ || &error($text{'create_ecmd'});
-d $in{'dir'} || &error($text{'create_edir'});

# Create the job
&create_atjob($in{'user'}, $date, $in{'cmd'}, $in{'dir'}, $in{'mail'});
&webmin_log("create", "job", $in{'user'}, \%in);
&redirect("");

