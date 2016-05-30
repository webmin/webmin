#!/usr/local/bin/perl
# Check a zone's records and report problems
use strict;
use warnings;

require './bind8-lib.pl';
# Globals from bind8-lib.pl
our (%access, %text, %in);

&ReadParse();
$access{'apply'} || &error($text{'check_ecannot'});
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
&can_edit_zone($zone) || &error($text{'master_ecannot'});
my $desc = &ip6int_to_net(&arpa_to_ip($zone->{'name'}));

&ui_print_header($desc, $text{'check_title'}, "",
		 undef, undef, undef, undef, &restart_links($zone));

my $file = &make_chroot($zone->{'file'});
my @errs = &check_zone_records($zone);
if (@errs) {
	# Show list of errors
	print "<b>",&text('check_errs', "<tt>$file</tt>"),"</b><p>\n";
	print "<ul>\n";
	foreach my $e (@errs) {
		print "<li>".&html_escape($e)."\n";
		}
	print "</ul>\n";
	}
else {
	# All OK!
	print "<b>",&text('check_allok', "<tt>$file</tt>"),"</b><p>\n";
	}

&ui_print_footer("edit_master.cgi?zone=$in{'zone'}&view=$in{'view'}",
		 $text{'master_return'});

