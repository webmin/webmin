#!/usr/local/bin/perl
# edit_bind.cgi
# Display port / address form

require './usermin-lib.pl';
$access{'bind'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'bind_title'}, "");
&get_usermin_miniserv_config(\%miniserv);

print $text{'bind_desc2'},"<p>\n";

print "<form action=change_bind.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$webmin::text{'bind_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Build list of sockets
@sockets = &webmin::get_miniserv_sockets(\%miniserv);

# Show table of all bound IPs and ports
print "<tr> <td valign=top><b>$webmin::text{'bind_sockets'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$webmin::text{'bind_sip'}</b></td> ",
      "<td><b>$webmin::text{'bind_sport'}</b></td> </tr>\n";
$i = 0;
foreach $s (@sockets, [ undef, "*" ]) {
	print "<tr $cb>\n";
	print "<td><select name=ip_def_$i>\n";
	printf "<option value=0 %s>&nbsp;\n",
		$s->[0] ? "" : "selected";
	printf "<option value=1 %s>%s\n",
		$s->[0] eq "*" ? "selected" : "", $webmin::text{'bind_sip1'};
	printf "<option value=2 %s>%s\n",
		$s->[0] eq "*" || !$s->[0] ? "" : "selected",$webmin::text{'bind_sip2'};
	print "</select>\n";
	printf "<input name=ip_$i size=20 value='%s'></td>\n",
		$s->[0] eq "*" ? undef : $s->[0];

	print "<td>\n";
	print "<select name=port_def_$i>\n";
	if ($i) {
		printf "<option value=0 %s>%s\n",
			$s->[1] eq "*" ? "selected" : "", $webmin::text{'bind_sport0'};
		}
	printf "<option value=1 %s>%s\n",
		$s->[1] eq "*" ? "" : "selected", $webmin::text{'bind_sport1'};
	print "</select>\n";
	printf "<input name=port_$i size=5 value='%s'></td>\n",
		$s->[1] eq "*" ? undef : $s->[1];
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";

# Show web server hostname
print "<tr> <td nowrap><b>$webmin::text{'bind_hostname'}</b></td>\n";
print "<td>",&ui_radio("hostname_def", $miniserv{"host"} ? 0 : 1,
	[ [ 1, $webmin::text{'bind_auto'} ],
	  [ 0, &ui_textbox("hostname", $miniserv{"host"}, 25) ] ]),
	"</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

