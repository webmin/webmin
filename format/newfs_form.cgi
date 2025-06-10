#!/usr/local/bin/perl
# newfs_form.cgi
# Display a form asking for new filesystem details

require './format-lib.pl';
$access{'view'} && &error($text{'ecannot'});
&ReadParse();
&can_edit_disk($in{'dev'}) || &error("You are not allowed to format this disk");
&ui_print_header(undef, "Create Filesystem", "");

print "<form action=newfs.cgi>\n";
print "<input type=hidden name=dev value=\"$in{dev}\">\n";
print &text('newfs_desc', "<b>".&fstype_name("ufs")."</b>",
			  "<b><tt>$in{dev}</tt></b>"),"<p>\n";

if ((@stat = &device_status($in{dev})) && $stat[1] ne "swap") {
	print &text('newfs_warn', "<tt>$stat[0]</tt>"),"<p>\n";
	}

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'newfs_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
&opt_input("ufs_a", "", 1);
&opt_input("ufs_b", "bytes", 0);
&opt_input("ufs_c", "", 1);
&opt_input("ufs_d", "ms", 0);
&opt_input("ufs_f", "bytes", 1);
&opt_input("ufs_i", "bytes", 0);
&opt_input("ufs_m", "%", 1);
&opt_input("ufs_n", "", 0);
print "<tr> <td align=right><b>$text{'ufs_o'}</b></td>\n";
print "<td><select name=ufs_o>\n";
print "<option value=''>$text{'default'}</option>\n";
print "<option value=space>$text{'newfs_space'}</option>\n";
print "<option value=time>$text{'newfs_time'}</option>\n";
print "</select></td>\n";
&opt_input("ufs_r", "rpm", 0);
&opt_input("ufs_s", "sectors", 1);
&opt_input("ufs_t", "", 0);
&opt_input("ufs_cb", "", 1);
print "</table></td></tr></table><br>\n";

print "<div align=right>\n";
print "<input type=submit value=\"$text{'newfs_create'}\"></form>\n";
print "</div>\n";

&ui_print_footer("", $text{'index_return'});

