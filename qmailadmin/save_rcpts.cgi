#!/usr/local/bin/perl
# save_rcpts.cgi
# Save the list of accepted domains

require './qmail-lib.pl';
&ReadParseMime();

if ($in{'rcpts_def'}) {
	&save_control_file("rcpthosts", undef);
	}
else {
	$in{'rcpts'} =~ s/\r//g;
	@dlist = split(/\s+/, $in{'rcpts'});
	&save_control_file("rcpthosts", \@dlist);
	}
$in{'rcpts2'} =~ s/\r//g;
if ($in{'rcpts2'}) {
	@dlist2 = split(/\s+/, $in{'rcpts2'});
	&save_control_file("morercpthosts", \@dlist2);
	&system_logged("$qmail_bin_dir/qmail-newmrh >/dev/null 2>&1");
	}
else {
	&save_control_file("morercpthosts", undef);
	}
&webmin_log("rcpts", undef, undef, \%in);
&redirect("");

