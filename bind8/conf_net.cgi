#!/usr/local/bin/perl
# conf_files.cgi
# Display global files options

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'net_ecannot'});
&ui_print_header(undef, $text{'net_title'}, "");

&ReadParse();
$conf = &get_config();
$options = &find("options", $conf);
$mems = $options->{'members'};

print "<form action=save_net.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'net_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td valign=top><b>$text{'net_listen'}</b></td> <td colspan=3>\n";
@listen = &find("listen-on", $mems);
printf "<input type=radio name=listen_def value=1 %s> %s\n",
	@listen ? "" : "checked", $text{'default'};
printf "<input type=radio name=listen_def value=0 %s> %s<br>\n",
	@listen ? "checked" : "", $text{'net_below'};

print "<table width=100% border>\n";
print "<tr $tb> <td><b>$text{'net_port'}</b></td> ",
      "<td><b>$text{'net_addrs'}</b></td> </tr>\n";
push(@listen, { });
for($i=0; $i<@listen; $i++) {
	printf "<tr $cb> <td><input type=radio name=pdef_$i value=1 %s> %s\n",
		$listen[$i]->{'value'} eq 'port' ? "" : "checked",
		$text{'default'};
	printf "<input type=radio name=pdef_$i value=0 %s>\n",
		$listen[$i]->{'value'} eq 'port' ? "checked" : "";
	printf "<input name=port_$i size=5 value='%s'></td>\n",
		$listen[$i]->{'value'} eq 'port' ?
			$listen[$i]->{'values'}->[1] : "";

	@vals = map { $_->{'name'} } @{$listen[$i]->{'members'}};
	printf "<td><input name=addrs_$i size=50 value='%s'></td> </tr>\n",
		join(" ", @vals);
	}
print "</table></td></tr>\n";

$src = &find("query-source", $mems);
$srcstr = join(" ", @{$src->{'values'}});
$sport = $1 if ($srcstr =~ /port\s+(\d+)/i);
$saddr = $1 if ($srcstr =~ /address\s+([0-9\.]+)/i);
print "<tr> <td><b>$text{'net_saddr'}</b></td> <td>\n";
printf "<input type=radio name=saddr_def value=1 %s> %s\n",
	$saddr ? "" : "checked", $text{'default'};
printf "<input type=radio name=saddr_def value=0 %s>\n",
	$saddr ? "checked" : "";
printf "<input name=saddr size=15 value='%s'></td>\n", $saddr;
print "<td><b>$text{'net_sport'}</b></td> <td>\n";
printf "<input type=radio name=sport_def value=1 %s> %s\n",
	$sport ? "" : "checked", $text{'default'};
printf "<input type=radio name=sport_def value=0 %s>\n",
	$sport ? "checked" : "";
printf "<input name=sport size=5 value='%s'></td> </tr>\n", $sport;

print "<tr>\n";
print &addr_match_input($text{'net_topol'}, 'topology', $mems, 1);
print &addr_match_input($text{'net_recur'}, 'allow-recursion', $mems, 1);
print "</tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});


