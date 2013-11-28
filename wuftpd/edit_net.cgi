#!/usr/local/bin/perl
# edit_net.cgi
# Display network-related options

require './wuftpd-lib.pl';
&ui_print_header(undef, $text{'net_title'}, "", "net");

$conf = &get_ftpaccess();
@class = &find_value("class", $conf);

print "<form action=save_net.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'net_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Display TCP window options
@tcp = ( &find_value('tcpwindow', $conf), [ ] );
print "<tr> <td valign=top><b>$text{'net_tcp'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'net_tsize'}</b></td> ",
      "<td><b>$text{'net_tclass'}</b></td> </tr>\n";
$i = 0;
foreach $t (@tcp) {
	print "<tr $cb>\n";
	print "<td><input name=tsize_$i size=5 value='$t->[0]'></td>\n";
	print "<td><select name=tclass_$i>\n";
	printf "<option value='' %s>%s</option>\n",
		$t->[1] ? '' : 'checked', $text{'net_tall'};
	foreach $c (@class) {
		printf "<option %s>%s</option>\n",
			$t->[1] eq $c->[0] ? 'selected' : '', $c->[0];
		}
	print "</select></td> </tr>\n";
	$i++;
	}
print "</table></td>\n";
print "<tr> <td colspan=4><hr></td> </tr>\n";

# passive address options
@pasv = ( ( grep { $_->[0] eq 'address' } &find_value('passive', $conf) ), [ ]);
print "<tr> <td valign=top><b>$text{'net_pasvaddr'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'net_pip'}</b></td> ",
      "<td><b>$text{'net_pcidr'}</b></td> </tr>\n";
$i = 0;
foreach $p (@pasv) {
	print "<tr $cb>\n";
	print "<td><input name=aip_$i size=15 value='$p->[1]'></td>\n";
	local @ci = split(/\//, $p->[2]);
	print "<td><input name=anet_$i size=15 value='$ci[0]'> /\n";
	print "<input name=acidr_$i size=2 value='$ci[1]'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table></td></tr>\n";

# passive port options
@pasv = ( ( grep { $_->[0] eq 'ports' } &find_value('passive', $conf) ), [ ] );
print "<tr> <td valign=top><b>$text{'net_pasvport'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'net_prange'}</b></td> ",
      "<td><b>$text{'net_pcidr'}</b></td> </tr>\n";
$i = 0;
foreach $p (@pasv) {
	print "<tr $cb>\n";
	print "<td><input name=pmin_$i size=5 value='$p->[2]'> -\n";
	print "<input name=pmax_$i size=5 value='$p->[3]'></td>\n";
	local @ci = split(/\//, $p->[1]);
	print "<td><input name=pnet_$i size=15 value='$ci[0]'> /\n";
	print "<input name=pcidr_$i size=2 value='$ci[1]'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table></td></tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

