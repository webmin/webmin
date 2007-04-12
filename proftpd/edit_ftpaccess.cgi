#!/usr/local/bin/perl
# edit_ftpaccess.cgi
# Display a form for editing some kind of per-directory options file

require './proftpd-lib.pl';
&ReadParse();
$conf = &get_ftpaccess_config($in{'file'});
@dirs = &editable_directives($in{'type'}, 'ftpaccess');
$desc = &text('ftpindex_header', "<tt>".&html_escape($in{'file'})."</tt>");
&ui_print_header($desc, $text{"type_$in{'type'}"}, "",
	undef, undef, undef, undef, &restart_button());

print "<form method=post action=save_ftpaccess.cgi>\n";
print "<input type=hidden name=type value=$in{'type'}>\n";
print "<input type=hidden name=file value=$in{'file'}>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('ftpindex_header2', $text{"type_$in{'type'}"},
			       "<tt>$in{'file'}</tt>"),"</td> </tr>\n";
print "<tr $cb> <td><table>\n";
&generate_inputs(\@dirs, $conf);
print "</table></td> </tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("ftpaccess_index.cgi?file=$in{'file'}", $text{'ftpindex_return'},
	"ftpaccess.cgi", $text{'ftpaccess_return'},
	"", $text{'index_return'});


