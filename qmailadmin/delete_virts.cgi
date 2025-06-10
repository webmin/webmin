#!/usr/local/bin/perl
# Delete a bunch of virtual mappings

require './qmail-lib.pl';
&ReadParse();
&error_setup($text{'vdelete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'adelete_enone'});

@virts = &list_virts();
foreach $d (@d) {
	($virt) = grep { $_->{'from'} eq $d } @virts;
	if ($virt) {
		&delete_virt($virt);
		}
	}
&webmin_log("delete", "virts", scalar(@d));
&redirect("list_virts.cgi");

