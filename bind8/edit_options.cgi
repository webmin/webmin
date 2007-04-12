#!/usr/local/bin/perl
# edit_options.cgi
# Display options for an existing master zone

require './bind8-lib.pl';
&ReadParse();
$bconf = $conf = &get_config();
if ($in{'view'} ne '') {
	$view = $conf->[$in{'view'}];
	$conf = $view->{'members'};
	}
$zconf = $conf->[$in{'index'}]->{'members'};
$dom = $conf->[$in{'index'}]->{'value'};
&can_edit_zone($conf->[$in{'index'}], $view) ||
	&error($text{'master_ecannot'});
$access{'opts'} || &error($text{'master_eoptscannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'master_opts'}, "");

# Form for editing zone options
print "<a name=options>\n";
print "<form action=save_master.cgi>\n";
print "<input type=hidden name=index value=\"$in{'index'}\">\n";
print "<input type=hidden name=view value=\"$in{'view'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'master_opts'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
print &choice_input($text{'master_check'}, "check-names", $zconf,
		    $text{'warn'}, "warn", $text{'fail'}, "fail",
		    $text{'ignore'}, "ignore", $text{'default'}, undef);
print &choice_input($text{'master_notify'}, "notify", $zconf,
		    $text{'yes'}, "yes", $text{'no'}, "no",
		    $text{'default'}, undef);
print "</tr>\n";

print "<tr>\n";
print &address_input($text{'master_update'}, "allow-update", $zconf);
print &address_input($text{'master_transfer'}, "allow-transfer", $zconf);
print "</tr>\n";

print "<tr>\n";
print &address_input($text{'master_query'}, "allow-query", $zconf);
print &address_input($text{'master_notify2'}, "also-notify", $zconf);
print "</tr>\n";

print "</table></td></tr> </table>\n";
print "<table width=100%><tr>\n";
print "<td width=33%><input type=submit value=\"$text{'save'}\"></td></form>\n";

@views = grep { &can_edit_view($_) } &find("view", $bconf);
if ($in{'view'} eq '' && @views || $in{'view'} ne '' && @views > 1) {
	print "<form action=move_zone.cgi>\n";
	print "<input type=hidden name=index value=\"$in{'index'}\">\n";
	print "<input type=hidden name=view value=\"$in{'view'}\">\n";
	print "<td width=33% align=middle>\n";
	print "<input type=submit value=\"$text{'master_move'}\">\n";
	print "<select name=newview>\n";
	foreach $v (@views) {
		printf "<option value=%d>%s\n", $v->{'index'}, $v->{'value'}
			if ($v->{'index'} ne $in{'view'});
		}
	print "</select></td></form>\n";
	}
else {
	print "<td width=33%></td>\n";
	}

if ($access{'slave'}) {
	print "<form action=convert_master.cgi>\n";
	print "<input type=hidden name=index value=\"$in{'index'}\">\n";
	print "<input type=hidden name=view value=\"$in{'view'}\">\n";
	print "<td width=33% align=right>\n";
	print "<input type=submit value=\"$text{'master_convert'}\">\n";
	print "</td></form>\n";
	}
else {
	print "<td width=33%></td>\n";
	}
print "</tr></table>\n";

&ui_print_footer("edit_master.cgi?index=$in{'index'}&view=$in{'view'}",
	$text{'master_return'});

