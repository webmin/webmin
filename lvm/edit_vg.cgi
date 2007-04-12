#!/usr/local/bin/perl
# edit_vg.cgi
# Display a form for editing or creating a volume group

require './lvm-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");
&ReadParse();

if ($in{'vg'}) {
	($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
	&ui_print_header(undef, $text{'vg_edit'}, "");
	}
else {
	&ui_print_header(undef, $text{'vg_create'}, "");
	}

print "<form action=save_vg.cgi>\n";
print "<input type=hidden name=vg value='$in{'vg'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'vg_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'vg_name'}</b></td>\n";
print "<td><input name=name size=20 value='$vg->{'name'}'></td>\n";

if ($in{'vg'}) {
	print "<td><b>$text{'vg_size'}</b></td>\n";
	print "<td>",&nice_size($vg->{'size'}*1024),"</td> </tr>\n";

	print "<tr> <td><b>$text{'vg_petotal'}</b></td>\n";
	print "<td>",&text('lv_petotals', $vg->{'pe_alloc'}, $vg->{'pe_total'}),
	      "</td>\n";

	print "<td><b>$text{'vg_pesize'}</b></td>\n";
	print "<td>$vg->{'pe_size'} kB</td> </tr>\n";

	print "<tr> <td><b>$text{'vg_petotal2'}</b></td>\n";
	print "<td>",&text('lv_petotals', &nice_size($vg->{'pe_alloc'}*$vg->{'pe_size'}*1024), &nice_size($vg->{'pe_total'}*$vg->{'pe_size'}*1024)),"</td>\n";

	print "</tr>\n";
	}
else {
	print "<td><b>$text{'vg_pesize'}</b></td>\n";
	print "<td><input type=radio name=pesize_def value=1 checked> ",
		$text{'default'},"\n";
	print "<input type=radio name=pesize_def value=0>\n";
	print "<input name=pesize size=8> kB</td> </tr>\n";

	print "<tr> <td><b>$text{'vg_device'}</b></td> <td colspan=3>\n";
	&device_input();
	print "</td> </tr>\n";
	}

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'vg'}) {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      " value='$text{'delete'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
print "</tr></table>\n";

&ui_print_footer("", $text{'index_return'});

