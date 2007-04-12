#!/usr/local/bin/perl
# save_ffile.cgi
# Save a filter file

require (-r 'sendmail-lib.pl' ? './sendmail-lib.pl' :
	 -r 'qmail-lib.pl' ? './qmail-lib.pl' :
			     './postfix-lib.pl');
&ReadParseMime();
&error_setup($text{'ffile_err'});
if (substr($in{'file'}, 0, length($access{'apath'})) ne $access{'apath'}) {
	&error(&text('ffile_efile', $in{'file'}));
	}

for($i=0; defined($in{"field_$i"}); $i++) {
	next if (!$in{"field_$i"});
	$in{"match_$i"} || &error($text{'ffile_ematch'});
	$in{"action_$i"} || &error($text{'ffile_eaction'});
	push(@filter, $in{"what_$i"}." ".$in{"action_$i"}." ".
		      $in{"field_$i"}." ".$in{"match_$i"}."\n");
	}
push(@filter, "2 ".$in{'other'}."\n") if ($in{'other'});

&open_lock_tempfile(FILE, ">$in{'file'}");
&print_tempfile(FILE, @filter);
&close_tempfile(FILE);
&redirect("edit_alias.cgi?num=$in{'num'}&name=$in{'name'}");

