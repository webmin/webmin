#!/usr/local/bin/perl
# save_afile.cgi
# Save a filter file

require './qmail-lib.pl';
&ReadParseMime();
&error_setup($text{'ffile_err'});

for($i=0; defined($in{"field_$i"}); $i++) {
	next if (!$in{"field_$i"});
	$in{"match_$i"} || &error($text{'ffile_ematch'});
	$in{"action_$i"} || &error($text{'ffile_eaction'});
	push(@filter, $in{"what_$i"}." ".$in{"action_$i"}." ".
		      $in{"field_$i"}." ".$in{"match_$i"}."\n");
	}
push(@filter, "2 ".$in{'other'}."\n") if ($in{'other'});

open(FILE, ">$in{'file'}");
print FILE @filter;
close(FILE);
&redirect("edit_alias.cgi?name=$in{'name'}");

