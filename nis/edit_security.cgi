#!/usr/local/bin/perl
# edit_security.cgi
# Show NIS server security options

require './nis-lib.pl';
&ui_print_header(undef, $text{'security_title'}, "");

if (&get_server_mode() == 0 || !(&get_nis_support() & 2)) {
	print "<p>$text{'security_enis'}<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print "<form action=save_security.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'security_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($config{'securenets'}) {
	print "<tr> <td valign=top><b>$text{'security_nets'}</b></td>\n";
	print "<td><table border>\n";
	print "<tr $tb> <td><b>$text{'security_mask'}</b></td> ",
	      "<td><b>$text{'security_net'}</b></td> </tr>\n";
	open(NETS, $config{'securenets'});
	while(<NETS>) {
		s/#.*$//;
		if (/(\S+)\s+(\S+)/) {
			push(@nets, [ $1 eq '255.255.255.255' ? 1 :
				      $1 eq 'host' ? 1 :
				      $1 eq '0.0.0.0' ? 2 : 0, $1, $2 ]);
			}
		}
	close(NETS);
	local $i = 0;
	foreach $n (@nets, [ -1, "", "" ]) {
		print "<tr $cb>\n";
		printf "<td><input type=radio name=def_$i value=-1 %s> %s\n",
			$n->[0] == -1 ? 'checked' : '', $text{'security_none'};
		printf "<input type=radio name=def_$i value=2 %s> %s\n",
			$n->[0] == 2 ? 'checked' : '', $text{'security_any'};
		printf "<input type=radio name=def_$i value=1 %s> %s\n",
			$n->[0] == 1 ? 'checked' : '', $text{'security_single'};
		printf "<input type=radio name=def_$i value=0 %s> %s\n",
			$n->[0] == 0 ? 'checked' : '', $text{'security_mask'};
		printf "<input name=mask_$i size=15 value='%s'></td>\n",
			$n->[0] == 0 ? $n->[1] : '';
		printf "<td><input name=net_$i size=15 value='%s'></td>\n",
			$n->[0] == 2 ? "" : $n->[2];
		print "</tr>\n";
		$i++;
		}
	print "</table></td></tr>\n";
	}

&show_server_security();

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'security_ok'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

