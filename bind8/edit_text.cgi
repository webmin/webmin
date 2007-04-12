#!/usr/local/bin/perl
# edit_text.cgi
# Display a form for manually editing a records file

require './bind8-lib.pl';
&ReadParse();
$zone = &get_zone_name($in{'index'}, $in{'view'});
$file = &absolute_path($zone->{'file'});
$tv = $zone->{'type'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$access{'file'} || &error($text{'text_ecannot'});
&ui_print_header($file, $text{'text_title'}, "");

open(FILE, &make_chroot($file));
while(<FILE>) {
	push(@lines, &html_escape($_));
	}
close(FILE);

if (!$access{'ro'}) {
	print &text('text_desc', "<tt>$file</tt>"),"<p>\n";
	}

print "<form action=save_text.cgi method=post enctype=multipart/form-data>\n";
print "<input type=hidden name=index value=\"$in{'index'}\">\n";
print "<input type=hidden name=view value=\"$in{'view'}\">\n";
print "<textarea name=text rows=20 cols=80>",
	join("", @lines),"</textarea><p>\n";
print "<input type=submit value=\"$text{'save'}\"> ",
      "<input type=reset value=\"$text{'text_undo'}\">\n"
	if (!$access{'ro'});
print "</form>\n";

&ui_print_footer(($tv eq "master" ? "edit_master.cgi" :
	 $tv eq "forward" ? "edit_forward.cgi" : "edit_slave.cgi").
	"?index=$in{'index'}&view=$in{'view'}", $text{'master_return'});
