#!/usr/local/bin/perl
# edit_global.cgi
# Display a form for editing some kind of global options

require './proftpd-lib.pl';
&ReadParse();
$conf = &get_config();
$global = &find_directive_struct("Global", $conf);
if ($global) {
	$gconf = $global->{'members'};
	}
&ui_print_header(undef, $text{"type_$in{'type'}"}, "",
	undef, undef, undef, undef, &restart_button());

print "<form method=post action=save_global.cgi>\n";
print "<input type=hidden name=type value=$in{'type'}>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",$text{"type_$in{'type'}"},"</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
@dirs = &editable_directives($in{'type'}, 'root');
&generate_inputs(\@dirs, $conf);
@gdirs = &editable_directives($in{'type'}, 'global');
if (@dirs && @gdirs) {
	print "<tr> <td colspan=4><hr></td> </tr>\n";
	}
&generate_inputs(\@gdirs, $gconf);
print "</table></td> </tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});


