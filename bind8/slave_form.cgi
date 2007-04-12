#!/usr/local/bin/perl
# slave_form.cgi
# A form for creating a new slave or stub zone

require './bind8-lib.pl';
$type = ($0 =~ /slave_form/);
$access{'slave'} || &error($type ? $text{'screate_ecannot1'}
				 : $text{'screate_ecannot2'});
&ui_print_header(undef, $type ? $text{'screate_title1'} : $text{'screate_title2'}, "");

print "<form action=create_slave.cgi>\n";
print "<input type=hidden name=type value=\"$type\">\n";
print "<table border width=100%>\n";
print "<tr> <td $tb><b>",$type ? $text{'screate_header1'}
			       : $text{'screate_header2'},"</b></td> </tr>\n";
print "<tr> <td $cb><table width=100%>\n";

print "<tr> <td><b>$text{'screate_type'}</b></td>\n";
print "<td colspan=3><input type=radio name=rev value=0 checked>\n";
print "$text{'screate_fwd'}\n";
print "&nbsp;&nbsp;<input type=radio name=rev value=1>\n";
print "$text{'screate_rev'}</td> </tr>\n";

print "<tr> <td><b>$text{'screate_dom'}</b></td>\n";
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

print "<tr> <td><b>$text{'slave_file'}</b></td> <td colspan=3>\n";
print "<input type=radio name=file_def value=1> $text{'slave_none'}\n";
print "<input type=radio name=file_def value=2 checked> $text{'slave_auto'}\n";
print "<input type=radio name=file_def value=0>\n";
print "<input name=file size=30>",&file_chooser_button("file"),"</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'slave_masters'}</b></td> <td>\n";
print "<textarea name=masters rows=4 cols=30>",
	join("\n", split(/\s+/, $config{'default_master'})),"</textarea></td>";
print "<td valign=top><b>$text{'slave_masterport'}</b></td> <td valign=top>\n";
print "<input type=radio name=port_def value=1 checked> $text{'default'}\n";
print "<input type=radio name=port_def value=0> $text{'slave_master_port'}\n";
print "<input name=port size=5> </td> </tr>\n";

# Create on slave servers?
@servers = grep { $_->{'sec'} } &list_slave_servers();
if (@servers && $access{'remote'}) {
	print "<tr> <td><b>$text{'master_onslave'}</b></td>\n";
	print "<td colspan=3>",&ui_yesno_radio("onslave", 1),"</td> </tr>\n";
	}

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'create'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

