#!/usr/local/bin/perl
# Delete several procmail recipes

require './procmail-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

&lock_file($procmailrc);
@conf = &get_procmailrc();
foreach $d (sort { $b <=> $c } @d) {
	$rec = $conf[$d];
	&delete_recipe($rec);
	}
&unlock_file($procmailrc);
&webmin_log("delete", "recipes", scalar(@d));
&redirect("");

