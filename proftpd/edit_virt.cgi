#!/usr/local/bin/perl
# edit_virt.cgi
# Display a form for editing some kind of per-server options

require './proftpd-lib.pl';
&ReadParse();
($conf, $v) = &get_virtual_config($in{'virt'});
@dirs = &editable_directives($in{'type'}, 'virtual');
$desc = $in{'virt'} eq '' ? $text{'virt_header2'} :
	      &text('virt_header1', $v->{'value'});
&ui_print_header($desc, $text{"type_$in{'type'}"}, "",
	undef, undef, undef, undef, &restart_button());

print "<form action=save_virt.cgi method=post>\n";
print "<input type=hidden name=type value=$in{'type'}>\n";
print "<input type=hidden name=virt value=$in{'virt'}>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('virt_header3', $text{"type_$in{'type'}"}),
      "</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
&generate_inputs(\@dirs, $conf);
print "</table></td> </tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
	"", $text{'index_return'});


