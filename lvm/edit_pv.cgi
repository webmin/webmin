#!/usr/local/bin/perl
# edit_pv.cgi
# Display a form for editing or creating a physical volume

require './lvm-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");
&ReadParse();
($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();

$vgdesc = &text('pv_vg', $vg->{'name'});
if ($in{'pv'}) {
	@pvs = &list_physical_volumes($in{'vg'});
	($pv) = grep { $_->{'name'} eq $in{'pv'} } @pvs;
	&ui_print_header($vgdesc, $text{'pv_edit'}, "");
	}
else {
	&ui_print_header($vgdesc, $text{'pv_create'}, "");
	$pv = { 'alloc' => 'y' };
	}

print "<form action=save_pv.cgi>\n";
print "<input type=hidden name=vg value='$in{'vg'}'>\n";
print "<input type=hidden name=pv value='$in{'pv'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'pv_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'pv_device'}</b></td> <td colspan=3>\n";
if ($in{'pv'}) {
	local $name = &foreign_call("mount", "device_name", $pv->{'device'});
	print "$name\n";
	}
else {
	&device_input();
	}
print "</td> </tr>\n";

print "<tr> <td><b>$text{'pv_alloc'}</b></td>\n";
printf "<td><input type=radio name=alloc value=y %s> %s\n",
	$pv->{'alloc'} eq 'y' ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=alloc value=n %s> %s</td>\n",
	$pv->{'alloc'} eq 'n' ? 'checked' : '', $text{'no'};

if ($in{'pv'}) {
	print "<td><b>$text{'pv_size'}</b></td>\n";
	print "<td>",&nice_size($pv->{'size'}*1024),"</td> </tr>\n";

	print "<tr> <td><b>$text{'pv_petotal'}</b></td>\n";
	print "<td>",&text('lv_petotals', $pv->{'pe_alloc'}, $pv->{'pe_total'}),
	      "</td>\n";

	print "<td><b>$text{'pv_pesize'}</b></td>\n";
	print "<td>$pv->{'pe_size'} kB</td> </tr>\n";

	print "<tr> <td><b>$text{'pv_petotal2'}</b></td>\n";
	print "<td>",&text('lv_petotals', &nice_size($pv->{'pe_alloc'}*$pv->{'pe_size'}*1024), &nice_size($pv->{'pe_total'}*$pv->{'pe_size'}*1024)),
	      "</td>\n";

	print "</tr>\n";

	@lvinfo = &get_physical_volume_usage($pv);
	if (@lvinfo) {
		@lvs = &list_logical_volumes($in{'vg'});
		print "<tr> <td><b>$text{'pv_lvs'}</b></td> <td colspan=3>\n";
		foreach $l (@lvinfo) {
			print " , \n" if ($l ne $lvinfo[0]);
			($lv) = grep { $_->{'name'} eq $l->[0] } @lvs;
			print "<a href='edit_lv.cgi?vg=$in{'vg'}&lv=$lv->{'name'}'>$lv->{'name'}</a> ";
			print &nice_size($l->[2]*$pv->{'pe_size'}*1024),"\n";
			}
		print "</td> </tr>\n";
		}
	}
else {
	print "</tr>\n";
	}

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'pv'}) {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      " value='$text{'pv_delete2'}'></td>\n" if (@pvs > 1);
	}
else {
	print "<td><input type=submit value='$text{'pv_create2'}'></td>\n";
	}
print "</tr></table>\n";

&ui_print_footer("", $text{'index_return'});

