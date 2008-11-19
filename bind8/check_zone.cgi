#!/usr/local/bin/perl
# Check a zone's records and report problems

require './bind8-lib.pl';
&ReadParse();
$access{'apply'} || &error($text{'check_ecannot'});
$zone = &get_zone_name($in{'index'}, $in{'view'});
&can_edit_zone($zone) || &error($text{'master_ecannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));

&ui_print_header($desc, $text{'check_title'}, "",
		 undef, undef, undef, undef, &restart_links($zone));

$file = &make_chroot($zone->{'file'});
@errs = &check_zone_records($zone);
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

&ui_print_footer("edit_master.cgi?index=$in{'index'}&view=$in{'view'}",
		 $text{'master_return'});

