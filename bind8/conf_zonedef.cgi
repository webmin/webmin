#!/usr/local/bin/perl
# conf_zonedef.cgi
# Display defaults for master zones

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'zonedef_ecannot'});
&ui_print_header(undef, $text{'zonedef_title'}, "");

print "<form action=save_zonedef.cgi>\n";

&get_zone_defaults(\%zd);
print "<table border>\n";
print "<tr $tb> <td><b>$text{'zonedef_msg'}</b></td> </tr>\n";
print "<tr $cb> <td><table cellpadding=5>\n";

print "<tr> <td><b>$text{'master_refresh'}</b></td>\n";
print "<td><input name=refresh size=10 value='$zd{'refresh'}'>\n";
print &time_unit_choice("refunit", $zd{'refunit'});
print "</td>\n";
print "<td><b>$text{'master_retry'}</b></td>\n";
print "<td><input name=retry size=10 value='$zd{'retry'}'>\n";
print &time_unit_choice("retunit", $zd{'retunit'});
print "</td> </tr>\n";

print "<tr> <td><b>$text{'master_expiry'}</b></td>\n";
print "<td><input name=expiry size=10 value='$zd{'expiry'}'>\n";
print &time_unit_choice("expunit", $zd{'expunit'});
print "</td>\n";
print "<td><b>$text{'master_minimum'}</b></td>\n";
print "<td><input name=minimum size=10 value='$zd{'minimum'}'>\n";
print &time_unit_choice("minunit", $zd{'minunit'});
print "</td>\n";

print "<tr> <td valign=top><b>$text{'master_tmplrecs'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'master_name'}</b></td> ",
      "<td><b>$text{'master_type'}</b></td> ",
      "<td><b>$text{'master_value'}</b></td> </tr>\n";
for($i=0; $i<2 || $config{"tmpl_".($i-1)}; $i++) {
	@c = split(/\s+/, $config{"tmpl_$i"}, 3);
	print "<tr $cb>\n";
	print "<td><input name=name_$i size=15 value='$c[0]'></td>\n";
	print "<td><select name=type_$i>\n";
	foreach $t ('A', 'CNAME', 'MX', 'NS', 'TXT', 'HINFO') {
		printf "<option value=%s %s>%s\n",
			$t, $c[1] eq $t ? 'selected' : '', $text{"type_$t"};
		}
	print "</select></td>\n";
	printf "<td><input type=radio name=def_$i value=1 %s> %s\n",
		$c[2] ? '' : 'checked', $text{'master_user'};
	printf "<input type=radio name=def_$i value=0 %s>\n",
		$c[2] ? 'checked' : '';
	print "<input name=value_$i size=15 value='$c[2]'></td> </tr>\n";
	}
print "</table>\n";

print "<b>$text{'master_include'}</b>\n";
printf "<input name=include size=40 value='%s'> %s\n",
	$config{'tmpl_include'}, &file_chooser_button("include");
print "</td> </tr>\n";

print "<tr> <td><b>$text{'zonedef_email'}</b></td>\n";
print "<td colspan=3>",&ui_textbox("email", $config{'tmpl_email'}, 40),
      "</td> </tr>\n";

print "<tr> <td><b>$text{'zonedef_prins'}</b></td>\n";
print "<td colspan=3>",&ui_opt_textbox("prins", $config{'default_prins'}, 30,
		&text('zonedef_this', "<tt>".&get_system_hostname()."</tt>")),
		"</td> </tr>\n";

print "</tr> </table></td></tr></table><br>\n";

$conf = &get_config();
$options = &find("options", $conf);
$mems = $options->{'members'};
foreach $c (&find("check-names", $mems)) {
	$check{$c->{'values'}->[0]} = $c->{'values'}->[1];
	}

print "<table border>\n";
print "<tr $tb> <td><b>$text{'zonedef_msg2'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr>\n";
print &addr_match_input($text{'zonedef_transfer'}, "allow-transfer", $mems);
print &addr_match_input($text{'zonedef_query'}, "allow-query", $mems);
print "</tr>\n";

print "<tr>\n";
&ignore_warn_fail($text{'zonedef_cmaster'}, 'master', $check{'master'});
&ignore_warn_fail($text{'zonedef_cslave'}, 'slave', $check{'slave'});
print "</tr>\n";

print "<tr>\n";
&ignore_warn_fail($text{'zonedef_cresponse'}, 'response', $check{'response'});
print &choice_input($text{'zonedef_notify'}, "notify", $mems,
		    $text{'yes'}, "yes", $text{'no'}, "no",
		    $text{'default'}, undef);
print "</tr>\n";

print "</tr> </table></td></tr></table><br>\n";

print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

# ignore_warn_fail(text, name, value)
sub ignore_warn_fail
{
print "<td><b>$_[0]</b></td> <td>\n";
printf "<input type=radio name=$_[1] value=ignore %s> $text{'ignore'}\n",
	$_[2] eq 'ignore' ? 'checked' : '';
printf "<input type=radio name=$_[1] value=warn %s> $text{'warn'}\n",
	$_[2] eq 'warn' ? 'checked' : '';
printf "<input type=radio name=$_[1] value=fail %s> $text{'fail'}\n",
	$_[2] eq 'fail' ? 'checked' : '';
printf "<input type=radio name=$_[1] value='' %s> $text{'default'}</td>\n",
	!$_[2] ? 'checked' : '';
}

