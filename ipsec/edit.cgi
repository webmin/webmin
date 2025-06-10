#!/usr/local/bin/perl
# edit.cgi
# Show a form for editing or creating a connection

require './ipsec-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "", "edit");
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "", "edit");
	@conf = &get_config();
	$conn = $conf[$in{'idx'}];
	}

print "<form action=save.cgi method=post>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Connection name
print "<tr> <td><b>$text{'edit_name'}</b></td>\n";
if ($conn->{'value'} eq '%default' || $in{'new'} == 2) {
	print "<td><i>$text{'edit_default'}</i></td>\n";
	}
else {
	printf "<td><input name=name size=20 value='%s'></td>\n",
		$conn->{'value'};
	}

# ipsec startup option
$a = $conn->{'values'}->{'auto'};
print "<td><b>$text{'edit_auto'}</b></td>\n";
print "<td>",&ui_select("auto", $a,
		[ [ "", $text{'edit_amode'} ],
		  [ "ignore", $text{'edit_amodeignore'} ],
		  [ "add", $text{'edit_amodeadd'} ],
		  [ "start", $text{'edit_amodestart'} ] ]),"</td> </tr>\n";

# compression option
$c = $conn->{'values'}->{'compress'};
print "<tr> <td><b>$text{'edit_comp'}</b></td> <td>\n";
print &ui_radio("comp", $c,
		[ [ "", $text{'edit_cmode'} ],
		  [ "yes", $text{'edit_cmodeyes'} ],
		  [ "no", $text{'edit_cmodeno'} ] ]),"</td>\n";

# connection type option
$t = $conn->{'values'}->{'type'};
print "<td><b>$text{'edit_type'}</b></td>\n";
print "<td>",&ui_select("type", $t,
		[ [ "", $text{'edit_tmode'} ],
		  [ "tunnel", $text{'edit_tmodetunnel'} ],
		  [ "transport", $text{'edit_tmodetransport'} ],
		  [ "passthrough", $text{'edit_tmodepassthrough'} ] ]),
       "</td> </tr>\n";

# authentication type option
$b = $conn->{'values'}->{'authby'};
print "<td><b>$text{'edit_authby'}</b></td>\n";
print "<td>",&ui_select("authby", $b,
			[ [ "", $text{'edit_authbydef'} ],
			  [ "rsasig", $text{'edit_rsasig'} ],
			  [ "secret", $text{'edit_secret'} ],
			  [ "rsasig|secret", $text{'edit_rsasigsecret'} ],
			  [ "never", $text{'edit_never'} ] ], 0,0, 1),"</td>\n";

# pfs option
$c = $conn->{'values'}->{'pfs'};
print "<td><b>$text{'edit_pfs'}</b></td> <td>\n";
print &ui_radio("pfs", $c, [ [ "yes", $text{'edit_pmodeyes'} ],
			     [ "no", $text{'edit_pmodeno'} ],
			     [ "", $text{'edit_pmode'} ] ]);
print "</td> </tr>\n";

# auth type option
$a = $conn->{'values'}->{'auth'};
print "<tr> <td><b>$text{'edit_auth'}</b></td>\n";
print "<td>",&ui_select("auth", $a,
		[ [ "", $text{'edit_authdef'} ],
		  [ "esp", $text{'edit_authesp'} ],
		  [ "ah", $text{'edit_authah'} ] ], 0, 0, 1),
      "</td>\n";

# keying tries option
$k = $conn->{'values'}->{'keyingtries'};
print "<td><b>$text{'edit_keying'}</b></td>\n";
print "<td>",&ui_opt_textbox("keying", $k, 10, $text{'default'}),
      "</td> </tr>\n";

# esp type option
$e = $conn->{'values'}->{'esp'};
$eonly = ($e =~ s/\!//g ? "!" : "");
print "<tr> <td><b>$text{'edit_esp'}</b></td>\n";
print "<td>",&ui_select("esp", $e,
		[ [ "", $text{'edit_espdef'} ],
		  [ "3des-md5", $text{'edit_espmd5'} ],
		  [ "3des-sha", $text{'edit_espsha'} ],
		  [ "aes-128-md5", $text{'edit_esp128'} ] ], 0, 0, 1),
      "</td>\n";

print "<td><b>$text{'edit_esponly'}</b></td>\n";
print "<td>",&ui_radio("esp_only", $eonly,
	[ [ "!", $text{'yes'} ], [ "", $text{'no'} ] ]),"</td> </tr>\n";

# key lifetime option
$l = $conn->{'values'}->{'keylife'};
$lu = $l =~ s/([^0-9])$// ? $1 : "s";
print "<tr> <td><b>$text{'edit_keylife'}</b></td>\n";
print "<td>",&ui_opt_textbox("keylife", $l, 5, $text{'default'})," ",
	     &ui_select("keylife_units", $lu,
			[ [ "s", $text{'edit_unit_s'} ],
			  [ "m", $text{'edit_unit_m'} ],
			  [ "h", $text{'edit_unit_h'} ],
			  [ "d", $text{'edit_unit_d'} ] ]),"</td>\n";

# keying channel lifetime option
$l = $conn->{'values'}->{'ikelifetime'};
$lu = $l =~ s/([^0-9])$// ? $1 : "s";
print "<td><b>$text{'edit_ikelifetime'}</b></td>\n";
print "<td>",&ui_opt_textbox("ikelifetime", $l, 5, $text{'default'})," ",
	     &ui_select("ikelifetime_units", $lu,
			[ [ "s", $text{'edit_unit_s'} ],
			  [ "m", $text{'edit_unit_m'} ],
			  [ "h", $text{'edit_unit_h'} ],
			  [ "d", $text{'edit_unit_d'} ] ]),"</td>\n";

foreach $d ('left', 'right') {
	print "</table></td></tr></table><br>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>",$text{'edit_'.$d},"</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	# left/right
	$a = $conn->{'values'}->{$d};
	$amode = $a eq '%defaultroute' ? 0 :
		 $a eq '%any' ? 1 : 
		 $a eq '%opportunistic' ? 2 : 3;
	if ($a eq '' && $conn->{'value'} eq '%default' || $in{'new'} == 2) {
		$amode = -1;
		}
	print "<tr> <td><b>$text{'edit_addr'}</b></td> <td colspan=3>\n";
	foreach $m ($amode == -1 ? (-1 .. 3) : (0 .. 3)) {
		printf "<input type=radio name=${d}_mode value=%s %s>%s\n",
		     $m, $m == $amode ? "checked" : "", $text{'edit_addr'.$m};
		}
	printf "<input name=$d size=15 value='%s'></td> </tr>\n",
		$amode == 3 ? $a : undef;

	# leftid/rightid
	$i = $conn->{'values'}->{$d."id"};
	$imode = $i =~ /^\@/ ? 2 : $i eq '' ? 0 : 1;
	print "<tr> <td><b>$text{'edit_id'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=${d}_id_mode value=0 %s> %s\n",
		$imode == 0 ? "checked" : "", $text{'default'};
	printf "<input type=radio name=${d}_id_mode value=1 %s> %s\n",
		$imode == 1 ? "checked" : "", $text{'edit_id1'};
	printf "<input type=radio name=${d}_id_mode value=2 %s> %s\n",
		$imode == 2 ? "checked" : "", $text{'edit_id2'};
	printf "<input name=${d}_id size=20 value='%s'>\n",
		$imode == 2 ? substr($i, 1) : $i;

	# leftsubnet/rightsubnet
	$s = $conn->{'values'}->{$d.'subnet'};
	print "<tr> <td><b>$text{'edit_subnet'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=${d}_subnet_def value=1 %s> %s\n",
		$s ? "" : "checked", $text{'edit_none'};
	printf "<input type=radio name=${d}_subnet_def value=0 %s> %s\n",
		$s ? "checked" : "";
	print "<input name=${d}_subnet size=20 value='$s'></td> </tr>\n";

	# leftrsasigkey/rightrsasigkey
	$k = $conn->{'values'}->{$d.'rsasigkey'};
	if ($in{'new'} == 1 && $d eq 'left') {
		$k = &get_public_key();
		}
	$kmode = $k eq '%dns' ? 1 : $k ? 2 : 0;
	print "<tr> <td valign=top><b>$text{'edit_key'}</b></td> ",
	      "<td colspan=3>\n";
	foreach $m (0 .. 2) {
		printf "<input type=radio name=${d}_key_mode value=%s %s> %s\n",
			$m, $kmode == $m ? "checked" : "", $text{'edit_key'.$m};
		}
	print "<textarea name=${d}_key rows=4 cols=81 wrap=hard>",
		$kmode == 2 ? join("\n", &wrap_lines($k, 80)) : "",
		"</textarea></td> </tr>\n";

	# leftnexthop/rightnexthop
	$h = $conn->{'values'}->{$d.'nexthop'};
	$hmode = $h eq '%direct' ? 1 :
		 $h eq '%defaultroute' ? 3 :
		 $h ? 2 : 0;
	print "<tr> <td><b>$text{'edit_hop'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=${d}_hop_mode value=0 %s> %s\n",
		$hmode == 0 ? "checked" : "", $text{'default'};
	printf "<input type=radio name=${d}_hop_mode value=1 %s> %s\n",
		$hmode == 1 ? "checked" : "", $text{'edit_hopdir'};
	printf "<input type=radio name=${d}_hop_mode value=3 %s> %s\n",
		$hmode == 3 ? "checked" : "", $text{'edit_hoproute'};
	printf "<input type=radio name=${d}_hop_mode value=2 %s> %s\n",
		$hmode == 2 ? "checked" : "", $text{'edit_hopip'};
	printf "<input name=${d}_hop size=15 value='%s'></td> </tr>\n",
		$hmode == 2 ? $h : undef;

	# leftcert/rightcert
	$s = $conn->{'values'}->{$d.'cert'};
	print "<tr> <td><b>$text{'edit_cert'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=${d}_cert_def value=1 %s> %s\n",
		$s ? "" : "checked", $text{'edit_none'};
	printf "<input type=radio name=${d}_cert_def value=0 %s> %s\n",
		$s ? "checked" : "";
	print "<input name=${d}_cert size=40 value='$s'></td> </tr>\n";
	}

print "</table></td></tr></table>\n";

print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	if ($conn->{'value'} ne '%default') {
		print "<td align=center><input type=submit name=export ",
		      "value='$text{'edit_export'}'></td>\n";
		}
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});


