#!/usr/local/bin/perl
# Delete several selected filters

require './filter-lib.pl';
&ReadParse();

# Validate selection
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Do it
&lock_file($procmail::procmailrc);
@filters = &list_filters();
foreach $d (sort { $b <=> $a } @d) {
	$filter = $filters[$d];
	&delete_filter($filter);
	}
&unlock_file($procmail::procmailrc);

&redirect("");

