#!/usr/local/bin/perl
# conf_net.cgi
# Display Unix networking options

require './samba-lib.pl';

# check acls

&error_setup("<blink><font color=red>$text{'eacl_aviol'}</font></blink>");
&error("$text{'eacl_np'} $text{'eacl_pcn'}") unless $access{'conf_net'};

&ui_print_header(undef, $text{'net_title'}, "");

&get_share("global");

print "<form action=save_net.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'net_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
print "<tr> <td><b>$text{'net_idle'}</b></td>\n";
printf "<td><input type=radio name=dead_time_def value=1 %s> $text{'config_never'}\n",
	&getval("deadtime") eq "" ? "checked" : "";
printf "<input type=radio name=dead_time_def value=0 %s>\n",
	&getval("deadtime") eq "" ? "" : "checked";
printf "<input name=dead_time size=5 value=\"%s\"> $text{'config_mins'}</td> </tr>\n",
	&getval("deadtime");

print "<tr> <td><b>$text{'net_trustlist'}</b></td>\n";
printf "<td><input type=radio name=hosts_equiv_def value=1 %s> $text{'config_none'}\n",
	&getval("hosts equiv") eq "" ? "checked" : "";
printf "<input type=radio name=hosts_equiv_def value=0 %s>",
	&getval("hosts equiv") eq "" ? "" : "checked";
printf "<input name=hosts_equiv size=20 value=\"%s\">\n",
	&getval("hosts equiv");
print &file_chooser_button("hosts_equiv", 0);
print "</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'net_netinterface'}</b></td>\n";
print "<td>\n";
printf "<input type=radio name=interfaces_def value=1 %s> $text{'net_auto'}&nbsp;\n",
	&getval("interfaces") ? "" : "checked";
printf "<input type=radio name=interfaces_def value=0 %s> $text{'net_uselist'}<br>\n",
	&getval("interfaces") ? "checked" : "";
print "<table border>\n";
print "<tr> <td><b>$text{'net_interface'}</b></td> <td><b>$text{'net_netmask'}</b></td> </tr>\n";
@iflist = split(/\s+/, &getval("interfaces"));
$len = @iflist ? @iflist+1 : 2;
for($i=0; $i<$len; $i++) {
	print "<tr>\n";
	if ($iflist[$i] =~ /^([0-9\.]+)\/([0-9]+)$/) {
		for($j=0; $j<$2; $j++) { $pw += 2**(31-$j); }
		$n = sprintf "%u.%u.%u.%u",
				($pw>>24)&0xff, ($pw>>16)&0xff,
				($pw>>8)&0xff, ($pw)&0xff;
		print "<td><input name=interface_ip$i value=$1 size=15></td>\n";
		print "<td><input name=interface_nm$i value=$n size=15></td>\n";
		}
	elsif ($iflist[$i] =~ /^([0-9\.]+)\/([0-9\.]+)$/) {
		print "<td><input name=interface_ip$i value=$1 size=15></td>\n";
		print "<td><input name=interface_nm$i value=$2 size=15></td>\n";
		}
	elsif ($iflist[$i] =~ /^(\S+)$/) {
		print "<td><input name=interface_ip$i value=$1 size=15></td>\n";
		print "<td><input name=interface_nm$i size=15></td>\n";
		}
	else {
		print "<td><input name=interface_ip$i size=15></td>\n";
		print "<td><input name=interface_nm$i size=15></td>\n";
		}
	print "</tr>\n";
	}
print "</table></td> </tr>\n";

print "<tr> <td><b>$text{'net_keepalive'}</b></td>\n";
printf "<td><input type=radio name=keepalive_def value=1 %s> $text{'net_notsend'}\n",
	&getval("keepalive") eq "" ? "checked" : "";
printf "<input type=radio name=keepalive_def value=0 %s>\n",
	&getval("keepalive") eq "" ? "" : "checked";
print "$text{'net_every'}\n";
printf "<input name=keepalive size=5 value=\"%s\">$text{'config_secs'}</td> </tr>\n",
	&getval("keepalive");

print "<tr> <td><b>$text{'net_maxpacket'}</b></td>\n";
printf "<td><input type=radio name=max_xmit_def value=1 %s> $text{'default'}\n",
	&getval("max xmit") eq "" ? "checked" : "";
printf "<input type=radio name=max_xmit_def value=0 %s>\n",
	&getval("max xmit") eq "" ? "" : "checked";
printf "<input name=max_xmit size=5 value=\"%s\"> $text{'config_bytes'}</td> </tr>\n",
	&getval("max xmit");

print "<tr> <td><b>$text{'net_listen'}</b></td>\n";
printf "<td><input type=radio name=socket_address_def value=1 %s> $text{'config_all'}\n",
	&getval("socket address") eq "" ? "checked" : "";
printf "<input type=radio name=socket_address_def value=0 %s>\n",
	&getval("socket address") eq "" ? "" : "checked";
printf "<input name=socket_address size=15 value=\"%s\"></td> </tr>\n",
	&getval("socket address");

print "<tr> <td valign=top><b>$text{'net_socket'}</b></td>\n";
print "<td><table>\n";
foreach (split(/\s+/, &getval("socket options"))) {
	if (/^([A-Z\_]+)=(.*)/) { $sopts{$1} = $2; }
	else { $sopts{$_} = ""; }
	}
for($i=0; $i<@sock_opts; $i++) {
	$sock_opts[$i] =~ /^([A-Z\_]+)(.*)$/;
	if ($i%2 == 0) { print "<tr>\n"; }
	printf "<td><input type=checkbox name=$1 value=1 %s> $1\n",
		defined($sopts{$1}) ? "checked" : "";
	if ($2 eq "*") {
		printf "<input size=5 name=\"$1_val\" value=\"%s\">\n",
			$sopts{$1};
		}
	print "</td>\n";
	if ($i%2 == 1) { print "<tr>\n"; }
	}
print "</table></td> </tr>\n";

print "</table></td></tr></table><p>\n";
print "<input type=submit value=$text{'save'}></form>\n";

&ui_print_footer("", $text{'index_sharelist'});

