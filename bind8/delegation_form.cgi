#!/usr/local/bin/perl
# delegation_form.cgi
# A form for creating a new delegation-only

require './bind8-lib.pl';
$access{'delegation'} || &error($text{'dcreate_ecannot'});
$access{'ro'} && &error($text{'master_ero'});
&ui_print_header(undef, $text{'dcreate_title'}, "");

print "<form action=create_delegation.cgi>\n";
print "<table border width=100%>\n";
print "<tr> <td $tb><b>$text{'dcreate_opts'}</b></td> </tr>\n";
print "<tr> <td $cb><table width=100%>\n";

print "<tr> <td><b>$text{'fcreate_type'}</b></td>\n";
print "<td colspan=3><input type=radio name=rev value=0 checked>\n";
print "$text{'fcreate_fwd'}\n";
print "&nbsp;&nbsp;<input type=radio name=rev value=1>\n";
print "$text{'fcreate_rev'}</td> </tr>\n";

print "<tr> <td><b>$text{'fcreate_dom'}</b></td>\n";
print "<td colspan=3><input name=zone size=40></td> </tr>\n";

$conf = &get_config();
@views = &find("view", $conf);
if (@views) {
	print "<tr> <td><b>$text{'mcreate_view'}</b></td>\n";
	print "<td colspan=3><select name=view>\n";
	foreach $v (grep { &can_edit_view($_) } @views) {
		printf "<option value=%d>%s\n",
			$v->{'index'}, $v->{'value'};
		}
	print "</select></td> </tr>\n";
	}

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'create'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});
