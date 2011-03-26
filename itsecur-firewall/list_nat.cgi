#!/usr/bin/perl
# list_nat.cgi
# Show NAT enable form

require './itsecur-lib.pl';
&can_use_error("nat");
&header($text{'nat_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

print "<form action=save_nat.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'nat_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

($iface, @nets) = &get_nat();
@maps = grep { ref($_) } @nets;
@nets = grep { !ref($_) } @nets;
print "<tr> <td valign=top><b>$text{'nat_desc'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=nat value=0 %s> %s<br>\n",
	$iface ? "" : "checked", $text{'nat_disabled'};
printf "<input type=radio name=nat value=1 %s> %s\n",
	$iface ? "checked" : "", $text{'nat_enabled'};
print &iface_input("iface", $iface);
print "</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'nat_nets'}</b></td>\n";
print "<td valign=top><table>\n";
$i = 0;
foreach $n ((grep { $_ !~ /^\!/ } @nets), undef, undef, undef) {
	print "<tr> <td>",&group_input("net_$i", $n, 1),"</td> </tr>\n";
	$i++;
	}
print "</table></td>\n";

print "<td valign=top><b>$text{'nat_excl'}</b></td>\n";
print "<td valign=top><table>\n";
$i = 0;
foreach $n ((grep { $_ =~ /^\!/ } @nets), undef, undef, undef) {
	print "<tr> <td>",&group_input("excl_$i", $n =~ /^\!(.*)/ ? $1 : undef, 1),"</td> </tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'nat_maps'}</b>",
      "<br>$text{'nat_mapsdesc'}</td> <td colspan=3>\n";
print "<table>\n";
print "<tr> <td><b>$text{'nat_ext'}</b></td> ",
      "<td><b>$text{'nat_int'}</b></td> ",
      "<td><b>$text{'nat_virt'}</b></td> </tr>\n";
$i = 0;
foreach $m (@maps, [ ], [ ], [ ]) {
	#print "<tr>\n";
	#printf "<td><input name=ext_%d size=20 value='%s'></td>\n",
	#	$i, $m->[0];
	#printf "<td><input name=int_%d size=20 value='%s'></td>\n",
	#	$i, $m->[1];
	#print "<td>",&iface_input("virt_$i", $m->[2], 1, 1, 1),"</td>\n";
	#print "</tr>\n";
	print "<tr>"	;	
	printf "<td><input name=ext_%d size=20 value='%s'></td>\n",
		$i, $m->[0];
	print "<td>",&group_input("int_$i", $m->[1], 1),"</td>\n";
	print "<td>",&iface_input("virt_$i", $m->[2], 1, 1, 1),"</td>\n";		
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";
&can_edit_disable("nat");

print "<hr>\n";
&footer("", $text{'index_return'});
