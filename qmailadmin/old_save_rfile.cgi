#!/usr/local/bin/perl
# save_rfile.cgi
# Save an autoreply file

require './qmail-lib.pl';
&ReadParseMime();

$in{'replies_def'} || $in{'replies'} =~ /^\/\S+/ ||
	&error($text{'rfile_ereplies'});
$in{'period_def'} || $in{'period'} =~ /^\d+$/ ||
	&error($text{'rfile_eperiod'});

$in{'text'} =~ s/\r//g;
open(FILE, ">$in{'file'}");
if (!$in{'replies_def'}) {
	print FILE "Reply-Tracking: $in{'replies'}\n";
	}
if (!$in{'period_def'}) {
	print FILE "Reply-Period: $in{'period'}\n";
	}
print FILE $in{'text'};
close(FILE);
&redirect("edit_alias.cgi?name=$in{'name'}");

