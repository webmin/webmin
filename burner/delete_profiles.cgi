#!/usr/local/bin/perl
# Delete a bunch of profiles

require './burner-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Delete them
foreach $d (@d) {
	$profile = &get_profile($d);
	&can_use_profile($profile) || &error($text{'edit_ecannot'});
	&delete_profile($profile);
	}

&redirect("");

