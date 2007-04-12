#!/usr/local/bin/perl
# user_grace_form.cgi
# Display a form for editing user grace times for some filesystem

require './quota-lib.pl';
&ReadParse();
$access{'ugrace'} && &can_edit_filesys($in{'filesys'}) ||
	&error($text{'ugracef_ecannot'});
&ui_print_header(undef, $text{'ugracef_title'}, "", "user_grace");

print "$text{'ugracef_info'}<p>\n";

@gr = &get_user_grace($in{'filesys'});
print "<form action=user_grace_save.cgi>\n";
print "<input type=hidden name=filesys value=\"$in{'filesys'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td colspan=2><b>",&text('ugracef_graces', $in{'filesys'}),"</b></td></tr>\n";

print "<tr $cb> <td width=20%><b>$text{'ugracef_block'}</b></td> <td>\n";
if (&default_grace()) {
	printf "<input type=radio name=bdef value=1 %s> $text{'default'}\n",
		$gr[0] ? "" : "checked";
	printf "<input type=radio name=bdef value=0 %s>\n",
		$gr[0] ? "checked" : "";
	}
print "<input name=btime size=6 value=\"$gr[0]\">";
&select_units("bunits", $gr[1]);
print "</td> </tr>\n";

print "<tr $cb> <td width=20%><b>$text{'ugracef_file'}</b></td> <td>\n";
if (&default_grace()) {
	printf "<input type=radio name=fdef value=1 %s> $text{'default'}\n",
		$gr[2] ? "" : "checked";
	printf "<input type=radio name=fdef value=0 %s>\n",
		$gr[2] ? "checked" : "";
	}
print "<input name=ftime size=6 value=\"$gr[2]\">";
&select_units("funits", $gr[3]);
print "</td> </tr>\n";

print "</table>\n";
print "<input type=submit value=$text{'ugracef_update'}></form>\n";

&ui_print_footer("list_users.cgi?dir=".&urlize($in{'filesys'}), $text{'ugracef_return'});

sub select_units
{
@uarr = &grace_units();
print "<select name=$_[0]>\n";
for($i=0; $i<@uarr; $i++) {
	printf "<option value=$i %s>$uarr[$i]\n",
		$i == $_[1] ? "selected" : "";
	}
print "</select>\n";
}

