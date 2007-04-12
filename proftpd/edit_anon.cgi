#!/usr/local/bin/perl
# edit_anon.cgi
# Display a form for editing some kind of anonymous option

require './proftpd-lib.pl';
&ReadParse();
($vconf, $v) = &get_virtual_config($in{'virt'});
$anon = &find_directive_struct("Anonymous", $vconf);
$conf = $anon->{'members'};
@dirs = &editable_directives($in{'type'}, 'anon');
$desc = $in{'virt'} eq '' ? $text{'anon_header4'} :
	      &text('anon_header3', $v->{'value'});
&ui_print_header($desc, $text{"type_$in{'type'}"}, "",
	undef, undef, undef, undef, &restart_button());

print "<form action=save_anon.cgi method=post>\n";
print "<input type=hidden name=type value=$in{'type'}>\n";
print "<input type=hidden name=virt value=$in{'virt'}>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('virt_header3', $text{"type_$in{'type'}"}),
      "</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
&generate_inputs(\@dirs, $conf);
print "</table></td> </tr></table><br>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("anon_index.cgi?virt=$in{'virt'}", $text{'anon_return'},
	"virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
	"", $text{'index_return'});

