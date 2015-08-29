#!/usr/local/bin/perl
# edit_dserv.cgi
# Edit <Directory> section details

require './proftpd-lib.pl';
&ReadParse();
if ($in{'global'}) {
	$conf = &get_config();
	$conf = &get_or_create_global($conf);
	}
else {
	($conf, $v) = &get_virtual_config($in{'virt'});
	}
if ($in{'anon'}) {
	$anon = &find_directive_struct("Anonymous", $conf);
	$conf = $anon->{'members'};
	}
$d = $conf->[$in{'idx'}];
$dn = $d->{'words'}->[0];
$dconf = $d->{'members'};
$desc = $in{'global'} ? &text('dir_header5', $dn) :
	$in{'anon'} ? &text('dir_header4', $dn) :
	$in{'virt'} ?  &text('dir_header1', $dn, $v->{'words'}->[0]) :
	&text('dir_header2', $dn);
&ui_print_header($desc, $text{'dserv_title'}, "",
	undef, undef, undef, undef, &restart_button());

print "<form action=save_dserv.cgi>\n";
print "<input type=hidden name=virt value='$in{'virt'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=anon value='$in{'anon'}'>\n";
print "<input type=hidden name=global value='$in{'global'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'dserv_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'dserv_dir'}</b></td>\n";
printf "<td><input name=dir size=40 value='%s'> %s</td> </tr>\n",
	$d->{'value'}, &file_chooser_button("dir", 1);

print "<tr> <td colspan=2>\n";
print "<input type=submit value=\"$text{'save'}\">\n";
print "<input type=submit name=delete value=\"$text{'dserv_delete'}\">\n";
print "</td> </tr>\n";

print "</table> </td></tr></table><p>\n";
print "</form>\n";

if ($in{'global'}) {
	&ui_print_footer("dir_index.cgi?global=$in{'global'}&idx=$in{'idx'}",
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

