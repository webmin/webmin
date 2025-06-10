#!/usr/local/bin/perl
# Delete a bunch of user mappings

require './qmail-lib.pl';
&ReadParse();
&error_setup($text{'sdelete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'adelete_enone'});

@assigns = &list_assigns();
foreach $d (@d) {
	($assign) = grep { $_->{'address'} eq $d } @assigns;
	if ($assign) {
		&delete_assign($assign);
		}
	}
&webmin_log("delete", "assigns", scalar(@d));
&redirect("list_assigns.cgi");

