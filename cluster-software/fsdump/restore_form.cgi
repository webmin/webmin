#!/usr/local/bin/perl
# restore_form.cgi
# Display a form with restore options

require './fsdump-lib.pl';
&ReadParse();
$access{'restore'} || &error($text{'restore_ecannot'});

&ui_print_header(undef, $text{'restore_title'}, "", "restore");

$m = &missing_restore_command($in{'fs'}) if ($in{'fs'} ne 'tar');
if ($m) {
	print "<p>",&text('restore_ecommand', "<tt>$m</tt>", uc($in{'fs'})),
	      "<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}
if ($in{'id'}) {
	# Restoring a specific dump
	$dump = &get_dump($in{'id'});
	}

print "<b>$text{'restore_desc'}</b><p>\n";

print "<form action=restore.cgi>\n";
print "<input type=hidden name=fs value='$in{'fs'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",$in{'fs'} eq 'tar' ? $text{'restore_theader'} :
		&text('restore_header', uc($in{'fs'})),"</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

&restore_form($in{'fs'}, $dump);

if ($access{'extra'}) {
	print "<tr> <td><b>",&hlink($text{'restore_extra'}, "rextra"),"</b></td>\n";
	print "<td colspan=3><input name=extra size=60 value=''></td> </tr>\n";
	}

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'restore_ok'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

