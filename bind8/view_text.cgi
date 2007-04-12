#!/usr/local/bin/perl
# view_text.cgi
# Display the records in a zone

require './bind8-lib.pl';
&ReadParse();
$zone = &get_zone_name($in{'index'}, $in{'view'});
$file = &absolute_path($zone->{'file'});
$tv = $zone->{'type'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$access{'file'} || &error($text{'text_ecannot'});
&ui_print_header($file, $text{'text_title2'}, "");

print &text('text_desc2', "<tt>$file</tt>"),"<p>\n";

open(FILE, &make_chroot($file));
while(<FILE>) {
	push(@lines, &html_escape($_));
	}
close(FILE);

if (@lines) {
	print "<table border width=100%><tr $cb><td><pre>";
	print @lines;
	print "</pre></td></tr></table>\n";
	}
else {
	print "$text{'text_none'}<p>\n";
	}

&ui_print_footer(($tv eq "master" ? "edit_master.cgi" :
	 $tv eq "forward" ? "edit_forward.cgi" : "edit_slave.cgi").
	"?index=$in{'index'}&view=$in{'view'}", $text{'master_return'});
