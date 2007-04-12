#!/usr/local/bin/perl
# edit_soptions.cgi
# Display options for an existing slave or stub zone

require './bind8-lib.pl';
&ReadParse();
$bconf = $conf = &get_config();
if ($in{'view'} ne '') {
	$view = $conf->[$in{'view'}];
	$conf = $view->{'members'};
	}
$zconf = $conf->[$in{'index'}]->{'members'};
$file = &find_value("file", $zconf);
$dom = $conf->[$in{'index'}]->{'value'};
&can_edit_zone($conf->[$in{'index'}], $view) ||
	&error($text{'slave_ecannot'});
$access{'opts'} || &error($text{'slave_ecannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'master_opts'}, "");

print "<form action=save_slave.cgi>\n";
print "<input type=hidden name=index value=\"$in{'index'}\">\n";
print "<input type=hidden name=view value=\"$in{'view'}\">\n";
print "<input type=hidden name=slave_stub value=\"$scriptname\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'slave_opts'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
print &address_port_input($text{'slave_masters'},
			  $text{'slave_masterport'},
			  $text{'slave_master_port'}, 
			  $text{'default'}, 
			  "masters",
			  "port",
			  $zconf,
			  5);
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'slave_max'}, "max-transfer-time-in",
		 $zconf, $text{'default'}, 4, $text{'slave_mins'});
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'slave_file'}, "file", $zconf, $text{'slave_none'}, 40);
print "</tr>\n";

print "<tr>\n";
print &choice_input($text{'slave_check'}, "check-names", $zconf,
		    $text{'warn'}, "warn", $text{'fail'}, "fail",
		    $text{'ignore'}, "ignore", $text{'default'}, undef);
print &choice_input($text{'slave_notify'}, "notify", $zconf,
		    $text{'yes'}, "yes", $text{'no'}, "no",
		    $text{'default'}, undef);
print "</tr>\n";

print "<tr>\n";
print &addr_match_input($text{'slave_update'}, "allow-update", $zconf);
print &addr_match_input($text{'slave_transfer'}, "allow-transfer", $zconf);
print "</tr>\n";

print "<tr>\n";
print &addr_match_input($text{'slave_query'}, "allow-query", $zconf);
print &address_input($text{'slave_notify2'}, "also-notify", $zconf);
print "</tr>\n";

print "</table></td></tr> </table>\n";

print "<table width=100%><tr><td width=25% align=left>\n";
print "<input type=submit value='$text{'save'}'></td></form>\n";

@views = &find("view", $bconf);
if ($in{'view'} eq '' && @views || $in{'view'} ne '' && @views > 1) {
	print "<form action=move_zone.cgi>\n";
	print "<input type=hidden name=index value=\"$in{'index'}\">\n";
	print "<input type=hidden name=view value=\"$in{'view'}\">\n";
	print "<td align=center>\n";
	print "<input type=submit value=\"$text{'master_move'}\">\n";
	print "<select name=newview>\n";
	foreach $v (@views) {
		printf "<option value=%d>%s\n",
		    $v->{'index'}, $v->{'value'}
			if ($v->{'index'} ne $in{'view'});
		}
	print "</select></td></form>\n";
	}

if ($access{'master'} && -s &make_chroot($file)) {
	print "<form action=convert_slave.cgi>\n";
	print "<input type=hidden name=index value='$in{'index'}'>\n";
	print "<input type=hidden name=view value='$in{'view'}'>\n";
	print "<td align=right><input type=submit ",
	      "value=\"$text{'slave_convert'}\"></td></form>\n";
	}
print "</table>\n";

&ui_print_footer("edit_slave.cgi?index=$in{'index'}&view=$in{'view'}", $text{'master_return'});

