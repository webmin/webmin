#!/usr/local/bin/perl
# edit_range.cgi
# Edit or create an IP range bootup interface

require './net-lib.pl';
$access{'ifcs'} == 2 || $access{'ifcs'} == 3 || &error($text{'ifcs_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'range_create'}, "");
	}
else {
	@boot = &boot_interfaces();
	$b = $boot[$in{'idx'}];

	if ($access{'ifcs'} == 3) {
		map { $can_interfaces{$_}++ } split(/\s+/, $access{'interfaces'});
		if (! $can_interfaces{$b->{'fullname'}}) {
			&error($text{'ifcs_ecannot_this'});
			}
		}
	
	&ui_print_header(undef, $text{'range_edit'}, "");
	}

print "<form action=save_range.cgi>\n";
print "<input type=hidden name=new value=\"$in{'new'}\">\n";
print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
print "<table border width=100%>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'range_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

&range_input($b);

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value=\"$text{'create'}\"></td>\n";
	print "<td align=right><input type=submit ",
	      "name=activate value=\"$text{'bifc_capply'}\"></td>\n";
	}
else {
	print "<td><input type=submit value=\"$text{'save'}\"></td>\n"
		unless $always_apply_ifcs;
	if (defined(&apply_interface)) {
		print "<td align=center><input type=submit ",
		      "name=activate value=\"$text{'bifc_apply'}\"></td>\n";
		}
	if (defined(&unapply_interface)) {
		print "<td align=center><input type=submit ",
		      "name=unapply value=\"$text{'bifc_dapply'}\"></td>\n";
		}
	print "<td align=right><input type=submit name=delete ",
	      "value=\"$text{'delete'}\"></td>\n"
		unless $noos_support_delete_ifcs;
	}
print "</tr></table></form>\n";

&ui_print_footer("list_ifcs.cgi?mode=boot", $text{'ifcs_return'});

