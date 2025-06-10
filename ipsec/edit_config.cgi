#!/usr/local/bin/perl
# edit_config.cgi
# Show global configuration options

require './ipsec-lib.pl';
&ui_print_header(undef, $text{'config_title'}, "");

@conf = &get_config();
($config) = grep { $_->{'name'} eq 'config' } @conf;

print "<form action=save_config.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'config_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Get list of interfaces
&foreign_require("net", "net-lib.pl");
@allifaces = &unique(sort { $a cmp $b }
                (map { $_->{'fullname'} } &net::active_interfaces()),
                (map { $_->{'fullname'} } &net::boot_interfaces()) );

# Show interfaces to listen on
$i = $config->{'values'}->{'interfaces'};
$imode = $i eq '%none' ? 1 :
	 $i eq '%defaultroute' ? 2 :
	 $i ? 3 : 0;
print "<tr> <td valign=top><b>$text{'config_ifaces'}</b></td> <td colspan=3>\n";
foreach $m (0 .. 3) {
	printf "<input type=radio name=ifaces_mode value=%s %s> %s\n",
		$m, $m == $imode ? "checked" : "", $text{'config_ifaces'.$m};
	}
@iflist = $imode == 3 ? split(/\s+/, $i) : ();
print "<br><table border>\n";
print "<tr $tb> <td><b>$text{'config_riface'}</b></td> ",
      "<td><b>$text{'config_iiface'}</b></td> </tr>\n";
$n = 0;
foreach $ifc (@iflist, "") {
	local ($ii, $ri) = split(/=/, $ifc);
	print "<tr $cb>\n";

	$found = 0;
	print "<td><select name=ri_$n>\n";
	print "<option value=''>&nbsp;</option>\n";
	foreach $r (@allifaces) {
		next if ($r =~ /^ipsec/ || $r =~ /:/);
		printf "<option value=%s %s>%s (%s)</option>\n",
			$r, $ri eq $r ? "selected" : "", $r,
			&net::iface_type($r);
		$found++ if ($ri eq $r);
		}
	print "<option value=$ri selected>$ri</option>\n" if (!$found && $ri);
	print "</select></td>\n";

	$found = 0;
	print "<td><select name=ii_$n>\n";
	foreach $k (0 .. 4) {
		printf "<option value=ipsec%d %s>ipsec%d</option>\n",
			$k, $ii eq "ipsec$k" ? "selected" : "", $k;
		$found++ if ($ii eq "ipsec$k");
		}
	print "<option value=$ii selected>$ii</option>\n" if (!$found && $ii);
	print "</select></td>\n";

	print "</tr>\n";
	$n++;
	}
print "</table></td></tr>\n";

# syslog facility/level
&foreign_require("syslog", "syslog-lib.pl");
$s = $config->{'values'}->{'syslog'};
print "<tr> <td><b>$text{'config_syslog'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=syslog_def value=1 %s> %s (<tt>%s</tt>)\n",
	$s ? "" : "checked", $text{'default'}, "daemon.error";
printf "<input type=radio name=syslog_def value=0 %s> %s\n",
	$s ? "checked" : "", $text{'config_fac'};
($fac, $pri) = split(/\./, $s);
$pri =~ s/warn$/warning/;
$pri =~ s/panic$/emerg/;
$pri =~ s/error$/err/;
print "<select name=fac>\n";
foreach $f (split(/\s+/, $syslog::config{'facilities'})) {
	printf "<option %s>%s</option>\n", $f eq $fac ? "selected" : "", $f;
	}
print "</select> $text{'config_pri'}\n";
print "<select name=pri>\n";
foreach $p (&syslog::list_priorities()) {
	printf "<option %s>%s</option>\n", $p eq $pri ? "selected" : "", $p;
	}
print "</select></td> </tr>\n";

# automatic forwarding enable
$f = $config->{'values'}->{'forwardcontrol'};
print "<tr> <td><b>$text{'config_fwd'}</b></td>\n";
print "<td>",&ui_radio("fwd", $f || "no",
       [ [ "yes", $text{'yes'} ], [ "no", $text{'no'} ] ]),"</td>\n";

# nat traversal enable
$n = $config->{'values'}->{'nat_traversal'};
print "<td><b>$text{'config_nat'}</b></td>\n";
print "<td>",&ui_radio("nat", $n || "no",
       [ [ "yes", $text{'yes'} ], [ "no", $text{'no'} ] ]),"</td> </tr>\n";

print "<td colspan=2></td>\n";
print "</tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

