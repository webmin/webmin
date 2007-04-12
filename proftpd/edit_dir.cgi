#!/usr/local/bin/perl
# edit_virt.cgi
# Display a form for editing some kind of per-directory options

require './proftpd-lib.pl';
&ReadParse();
if ($in{'global'}) {
	$conf = &get_config();
	$vconf = &get_or_create_global($conf);
	}
else {
	($vconf, $v) = &get_virtual_config($in{'virt'});
	}
if ($in{'anon'}) {
	$anon = &find_directive_struct("Anonymous", $vconf);
	$vconf = $anon->{'members'};
	}
$d = $vconf->[$in{'idx'}];
$conf = $d->{'members'};
@dirs = &editable_directives($in{'type'}, 'directory');
$dn = $d->{'words'}->[0];
$desc = $in{'global'} ? &text('dir_header5', $dn) :
	$in{'anon'} ? &text('dir_header4', $dn) :
	$in{'virt'} ? &text('dir_header1', $dn, $v->{'words'}->[0]) :
	&text('dir_header2', $dn);
&ui_print_header($desc, $text{"type_$in{'type'}"}, "",
	undef, undef, undef, undef, &restart_button());

print "<form method=post action=save_dir.cgi method=post>\n";
print "<input type=hidden name=type value=$in{'type'}>\n";
print "<input type=hidden name=idx value=$in{'idx'}>\n";
print "<input type=hidden name=virt value=$in{'virt'}>\n";
print "<input type=hidden name=anon value=$in{'anon'}>\n";
print "<input type=hidden name=global value=$in{'global'}>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('dir_header3', $text{"type_$in{'type'}"},
			       $d->{'words'}->[0]),"</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
&generate_inputs(\@dirs, $conf);
print "</table></td> </tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

if ($in{'global'}) {
	&ui_print_footer("dir_index.cgi?idx=$in{'idx'}&global=$in{'global'}",
		$text{'dir_return'},
		"", $text{'index_return'});
	}
elsif ($in{'anon'}) {
	&ui_print_footer("dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}&anon=$in{anon}",
		$text{'dir_return'},
		"anon_index.cgi?virt=$in{'virt'}", $text{'anon_return'},
		"virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
		"", $text{'index_return'});
	}
else {
	&ui_print_footer("dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}",
		$text{'dir_return'},
		"virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
		"", $text{'index_return'});
	}


