#!/usr/local/bin/perl
# edit_host.cgi
# Display options for a new or existing host config

require './sshd-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'host_create'}, "", "chost");
	}
else {
	&ui_print_header(undef, $text{'host_edit'}, "", "ehost");
	$hconf = &get_client_config();
	$host = $hconf->[$in{'idx'}];
	$conf = $host->{'members'};
	}

print "<form action=save_host.cgi>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'host_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

&scmd(1);
print "<td><b>$text{'host_name'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=name_def value=1 %s> %s\n",
	$host->{'values'}->[0] eq '*' ? 'checked' : '', $text{'hosts_all'};
printf "<input type=radio name=name_def value=0 %s>\n",
	$host->{'values'}->[0] eq '*' ? '' : 'checked'; 
printf "<input name=name size=40 value='%s'></td>\n",
	$host->{'values'}->[0] eq '*' ? '' : $host->{'values'}->[0];
&ecmd();

&scmd();
$user = &find_value("User", $conf);
print "<td><b>$text{'host_user'}</b></td> <td nowrap>\n";
printf "<input type=radio name=user_def value=1 %s> %s\n",
	$user ? "" : "checked", $text{'host_user_def'};
printf "<input type=radio name=user_def value=0 %s>\n",
	$user ? "checked" : "";
print "<input name=user size=13 value='$user'></td>\n";
&ecmd();

&scmd();
$keep = &find_value("KeepAlive", $conf);
print "<td><b>$text{'host_keep'}</b></td> <td>\n";
printf "<input type=radio name=keep value=1 %s> %s\n",
	lc($keep) eq 'yes' ? "checked" : "", $text{'yes'};
printf "<input type=radio name=keep value=0 %s> %s\n",
	lc($keep) eq 'no' ? "checked" : "", $text{'no'};
printf "<input type=radio name=keep value=2 %s> %s</td>\n",
	!$keep ? "checked" : "", $text{'default'};
&ecmd();

&scmd();
$hostname = &find_value("HostName", $conf);
print "<td><b>$text{'host_hostname'}</b></td> <td nowrap>\n";
printf "<input type=radio name=hostname_def value=1 %s> %s\n",
	$hostname ? "" : "checked", $text{'host_hostname_def'};
printf "<input type=radio name=hostname_def value=0 %s>\n",
	$hostname ? "checked" : "";
print "<input name=hostname size=20 value='$hostname'></td>\n";
&ecmd();

&scmd();
$batch = &find_value("BatchMode", $conf);
print "<td><b>$text{'host_batch'}</b></td> <td>\n";
printf "<input type=radio name=batch value=0 %s> %s\n",
	lc($batch) eq 'no' ? "checked" : "", $text{'yes'};
printf "<input type=radio name=batch value=1 %s> %s\n",
	lc($batch) eq 'yes' ? "checked" : "", $text{'no'};
printf "<input type=radio name=batch value=2 %s> %s</td>\n",
	!$batch ? "checked" : "", $text{'default'};
&ecmd();

&scmd();
$port = &find_value("Port", $conf);
print "<td><b>$text{'host_port'}</b></td> <td nowrap>\n";
printf "<input type=radio name=port_def value=1 %s> %s\n",
	$port ? "" : "checked", $text{'default'};
printf "<input type=radio name=port_def value=0 %s>\n",
	$port ? "checked" : "";
print "<input name=port size=6 value='$port'></td>\n";
&ecmd();

&scmd();
$comp = &find_value("Compression", $conf);
print "<td><b>$text{'host_comp'}</b></td> <td>\n";
printf "<input type=radio name=comp value=1 %s> %s\n",
	lc($comp) eq 'yes' ? "checked" : "", $text{'yes'};
printf "<input type=radio name=comp value=0 %s> %s\n",
	lc($comp) eq 'no' ? "checked" : "", $text{'no'};
printf "<input type=radio name=comp value=2 %s> %s</td>\n",
	!$comp ? "checked" : "", $text{'default'};
&ecmd();

&scmd();
$escape = &find_value("EscapeChar", $conf);
print "<td><b>$text{'host_escape'}</b></td> <td nowrap>\n";
printf "<input type=radio name=escape_def value=1 %s> %s\n",
	$escape eq "" ? "checked" : "", $text{'default'};
printf "<input type=radio name=escape_def value=2 %s> %s\n",
	$escape eq "none" ? "checked" : "", $text{'host_escape_none'};
printf "<input type=radio name=escape_def value=0 %s>\n",
	$escape eq "" || $escape eq "none" ? "" : "checked";
printf "<input name=escape size=2 value='%s'></td>\n",
	$escape eq "" || $escape eq "none" ? "" : $escape;
&ecmd();

if ($version{'type'} ne 'ssh' || $version{'number'} < 3) {
	&scmd();
	$clevel = &find_value("CompressionLevel", $conf);
	print "<td><b>$text{'host_clevel'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=clevel_def value=1 %s> %s\n",
		$clevel ? "" : "checked", $text{'default'};
	printf "<input type=radio name=clevel_def value=0 %s>\n",
		$clevel ? "checked" : "";
	print "<select name=clevel>\n";
	foreach $l (1 .. 9) {
		printf "<option %s value=%s>%s %s\n", $clevel == $l ? 'selected' : '',
			$l, $l, $text{"host_clevel_$l"};
		}
	print "</select></td>\n";
	&ecmd();

	&scmd();
	$attempts = &find_value("ConnectionAttempts", $conf);
	print "<td><b>$text{'host_attempts'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=attempts_def value=1 %s> %s\n",
		$attempts ? "" : "checked", $text{'default'};
	printf "<input type=radio name=attempts_def value=0 %s>\n",
		$attempts ? "checked" : "";
	print "<input name=attempts size=2 value='$attempts'></td>\n";
	&ecmd();

	&scmd();
	$priv = &find_value("UsePrivilegedPort", $conf);
	print "<td><b>$text{'host_priv'}</b></td> <td>\n";
	printf "<input type=radio name=priv value=1 %s> %s\n",
		lc($priv) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=priv value=0 %s> %s\n",
		lc($priv) eq 'no' ? "checked" : "", $text{'no'};
	printf "<input type=radio name=priv value=2 %s> %s</td>\n",
		!$priv ? "checked" : "", $text{'default'};
	&ecmd();

	&scmd();
	$rsh = &find_value("FallBackToRsh", $conf);
	print "<td><b>$text{'host_rsh'}</b></td> <td>\n";
	printf "<input type=radio name=rsh value=1 %s> %s\n",
		lc($rsh) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=rsh value=0 %s> %s\n",
		lc($rsh) eq 'no' ? "checked" : "", $text{'no'};
	printf "<input type=radio name=rsh value=2 %s> %s</td>\n",
		!$rsh ? "checked" : "", $text{'default'};
	&ecmd();

	&scmd();
	$usersh = &find_value("UseRsh", $conf);
	print "<td><b>$text{'host_usersh'}</b></td> <td>\n";
	printf "<input type=radio name=usersh value=1 %s> %s\n",
		lc($usersh) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=usersh value=0 %s> %s\n",
		lc($usersh) eq 'no' ? "checked" : "", $text{'no'};
	printf "<input type=radio name=usersh value=2 %s> %s</td>\n",
		!$usersh ? "checked" : "", $text{'default'};
	&ecmd();
	}

&scmd();
$agent = &find_value("ForwardAgent", $conf);
print "<td><b>$text{'host_agent'}</b></td> <td>\n";
printf "<input type=radio name=agent value=1 %s> %s\n",
	lc($agent) eq 'yes' ? "checked" : "", $text{'yes'};
printf "<input type=radio name=agent value=0 %s> %s\n",
	lc($agent) eq 'no' ? "checked" : "", $text{'no'};
printf "<input type=radio name=agent value=2 %s> %s</td>\n",
	!$agent ? "checked" : "", $text{'default'};
&ecmd();

&scmd();
$x11 = &find_value("ForwardX11", $conf);
print "<td><b>$text{'host_x11'}</b></td> <td>\n";
printf "<input type=radio name=x11 value=1 %s> %s\n",
	lc($x11) eq 'yes' ? "checked" : "", $text{'yes'};
printf "<input type=radio name=x11 value=0 %s> %s\n",
	lc($x11) eq 'no' ? "checked" : "", $text{'no'};
printf "<input type=radio name=x11 value=2 %s> %s</td>\n",
	!$x11 ? "checked" : "", $text{'default'};
&ecmd();

&scmd();
$strict = &find_value("StrictHostKeyChecking", $conf);
print "<td><b>$text{'host_strict'}</b></td> <td>\n";
printf "<input type=radio name=strict value=0 %s> %s\n",
	lc($strict) eq 'no' ? "checked" : "", $text{'yes'};
printf "<input type=radio name=strict value=1 %s> %s\n",
	lc($strict) eq 'yes' ? "checked" : "", $text{'no'};
printf "<input type=radio name=strict value=3 %s> %s\n",
	lc($strict) eq 'ask' ? "checked" : "", $text{'host_ask'};
printf "<input type=radio name=strict value=2 %s> %s</td>\n",
	!$strict ? "checked" : "", $text{'default'};
&ecmd();

if ($version{'type'} eq 'openssh') {
	&scmd();
	$checkip = &find_value("CheckHostIP", $conf);
	print "<td><b>$text{'host_checkip'}</b></td> <td>\n";
	printf "<input type=radio name=checkip value=1 %s> %s\n",
		lc($checkip) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=checkip value=0 %s> %s\n",
		lc($checkip) eq 'no' ? "checked" : "", $text{'no'};
	printf "<input type=radio name=checkip value=2 %s> %s</td>\n",
		!$checkip ? "checked" : "", $text{'default'};
	&ecmd();

	&scmd(1);
	$prots = &find_value("Protocol", $conf);
	@prots = split(/,/, $prots);
	print "<td><b>$text{'host_prots'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=prots_def value=1 %s> %s\n",
		$prots ? '' : 'checked', $text{'default'};
	printf "<input type=radio name=prots_def value=0 %s> %s\n",
		$prots ? 'checked' : '', $text{'host_prots_sel'};
	foreach $p (1, 2) {
		printf "<input type=checkbox name=prots value=%s %s> %s\n",
			$p, &indexof($p, @prots) >= 0 ? "checked" : "",
			$text{"net_prots_$p"};
		}
	print "</td>\n";
	&ecmd();
	}

&scmd(1);
print "<td colspan=4><hr></td>\n";
&ecmd();

&scmd(1);
print "<td valign=top><b>$text{'host_lforward'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'host_llport'}</b></td> ",
      "<td><b>$text{'host_lrhost'}</b></td> ",
      "<td><b>$text{'host_lrport'}</b></td> </tr>\n";
@lforward = &find("LocalForward", $conf);
$i = 0;
foreach $l (@lforward, { }) {
	local ($lp, $rh, $rp) = ( $l->{'values'}->[0],
				  split(/:/, $l->{'values'}->[1]) );
	print "<tr>\n";
	print "<td><input name=llport_$i size=8 value='$lp'></td>\n";
	print "<td><input name=lrhost_$i size=40 value='$rh'></td>\n";
	print "<td><input name=lrport_$i size=8 value='$rp'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table></td>\n";
&ecmd();

&scmd(1);
print "<td colspan=4><hr></td>\n";
&ecmd();

&scmd(1);
print "<td valign=top><b>$text{'host_rforward'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'host_rrport'}</b></td> ",
      "<td><b>$text{'host_rlhost'}</b></td> ",
      "<td><b>$text{'host_rlport'}</b></td> </tr>\n";
@rforward = &find("RemoteForward", $conf);
$i = 0;
foreach $r (@rforward, { }) {
	local ($rp, $lh, $lp) = ( $r->{'values'}->[0],
				  split(/:/, $r->{'values'}->[1]) );
	print "<tr>\n";
	print "<td><input name=rrport_$i size=8 value='$rp'></td>\n";
	print "<td><input name=rlhost_$i size=40 value='$lh'></td>\n";
	print "<td><input name=rlport_$i size=8 value='$lp'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table></td>\n";
&ecmd();

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
print "<td><input type=submit value='$text{'save'}'></td>\n";
print "<td align=right><input type=submit name=delete ",
      "value='$text{'delete'}'></td>\n";
print "</tr></table>\n";

&ui_print_footer("list_hosts.cgi", $text{'hosts_return'},
	"", $text{'index_return'});

