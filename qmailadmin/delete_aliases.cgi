#!/usr/local/bin/perl
# Delete a bunch of aliases

require './qmail-lib.pl';
&ReadParse();
&error_setup($text{'adelete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'adelete_enone'});

foreach $d (@d) {
	$a = &get_alias($d);
	if ($a) {
		&delete_alias($a);
		}
	}
&webmin_log("delete", "aliases", scalar(@d));
&redirect("list_aliases.cgi");



