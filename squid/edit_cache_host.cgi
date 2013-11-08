#!/usr/local/bin/perl
# edit_cache_host.cgi
# Display a form for editing or creating a cache_host line

require './squid-lib.pl';
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&ReadParse();
$conf = &get_config();
$cache_host = $squid_version >= 2 ? "cache_peer" : "cache_host";
if ($in{'new'}) {
	&ui_print_header(undef, $text{'ech_header'}, "", undef, 0, 0, 0, &restart_button());
	}
else {
	&ui_print_header(undef, $text{'ech_header1'}, "", undef, 0, 0, 0, &restart_button());
	@chl = &find_config($cache_host, $conf);
	@ch = @{$chl[$in{'num'}]->{'values'}};
	for($i=4; $i<@ch; $i++) {
		if ($ch[$i] =~ /^(\S+)=(\S+)$/) { $opts{$1} = $2; }
		else { $opts{$ch[$i]} = 1; }
		}
	}

print "<form action=save_cache_host.cgi>\n";
if ($in{'new'}) { print "<input type=hidden name=new value=1>\n"; }
else { print "<input type=hidden name=num value=$in{'num'}>\n"; }
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'ech_cho'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'ech_h'}</b></td>\n";
print "<td><input name=host size=20 value=\"$ch[0]\"></td>\n";

%ts = (	"parent"=> $text{"ech_parent"},
	"sibling"=>$text{"ech_sibling"},
	"multicast"=>$text{"ech_multicast"} );
print "<td><b>$text{'ech_t'}</b></td>\n";
print "<td><select name=type>\n";
foreach $t (keys %ts) {
	printf "<option value=$t %s>$ts{$t}</option>\n", $t eq $ch[1] ? "selected" : "";
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'ech_pp'}</b></td>\n";
print "<td><input name=proxy size=6 value=\"$ch[2]\"></td>\n";

print "<td><b>$text{'ech_ip'}</b></td>\n";
print "<td><input name=icp size=6 value=\"$ch[3]\"></td> </tr>\n";

print "<tr> <td><b>$text{'ech_po'}</b></td>\n";
printf "<td><input type=radio name=proxy-only value=1 %s> $text{'ech_y'}\n",
	$opts{'proxy-only'} ? "checked" : "";
printf "<input type=radio name=proxy-only value=0 %s> $text{'ech_n'}</td>\n",
	$opts{'proxy-only'} ? "" : "checked";

print "<td><b>$text{'ech_siq'}</b></td>\n";
printf "<td><input type=radio name=no-query value=0 %s> $text{'ech_y'}\n",
	$opts{'no-query'} ? "" : "checked";
printf "<input type=radio name=no-query value=1 %s> $text{'ech_n'}</td> </tr>\n",
	$opts{'no-query'} ? "checked" : "";

print "<tr> <td><b>$text{'ech_dc'}</b></td>\n";
printf "<td><input type=radio name=default value=1 %s> $text{'ech_y'}\n",
	$opts{'default'} ? "checked" : "";
printf "<input type=radio name=default value=0 %s> $text{'ech_n'}</td>\n",
	$opts{'default'} ? "" : "checked";

print "<td><b>$text{'ech_rrc'}</b></td>\n";
printf "<td><input type=radio name=round-robin value=1 %s> $text{'ech_y'}\n",
	$opts{'round-robin'} ? "checked" : "";
printf "<input type=radio name=round-robin value=0 %s> $text{'ech_n'}</td> </tr>\n",
	$opts{'round-robin'} ? "" : "checked";

print "<tr> <td><b>$text{'ech_ittl'}</b></td>\n";
printf "<td><input type=radio name=ttl_def value=1 %s> $text{'ech_d'}\n",
	$opts{'ttl'} ? "" : "checked";
printf "<input type=radio name=ttl_def value=0 %s>\n",
	$opts{'ttl'} ? "checked" : "";
print "<input name=ttl size=6 value=\"$opts{'ttl'}\"></td>\n";

print "<td><b>$text{'ech_cw'}</b></td>\n";
printf "<td><input type=radio name=weight_def value=1 %s> $text{'ech_d'}\n",
	$opts{'weight'} ? "" : "checked";
printf "<input type=radio name=weight_def value=0 %s>\n",
	$opts{'weight'} ? "checked" : "";
print "<input name=weight size=6 value=\"$opts{'weight'}\"></td> </tr>\n";

if ($squid_version >= 2) {
	print "<tr> <td><b>$text{'ech_co'}</b></td>\n";
	printf "<td><input type=radio name=closest-only value=1 %s> $text{'ech_y'}\n",
		$opts{'closest-only'} ? "checked" : "";
	printf "<input type=radio name=closest-only value=0 %s> $text{'ech_n'}</td>\n",
		$opts{'closest-only'} ? "" : "checked";

	print "<td><b>$text{'ech_nd'}</b></td>\n";
	printf "<td><input type=radio name=no-digest value=1 %s> $text{'ech_y'}\n",
		$opts{'no-digest'} ? "checked" : "";
	printf "<input type=radio name=no-digest value=0 %s> $text{'ech_n'}</td> </tr>\n",
		$opts{'no-digest'} ? "" : "checked";

	print "<tr> <td><b>$text{'ech_nne'}</b></td>\n";
	printf "<td><input type=radio name=no-netdb-exchange value=1 %s> $text{'ech_y'}\n",
		$opts{'no-netdb-exchange'} ? "checked" : "";
	printf "<input type=radio name=no-netdb-exchange value=0 %s> $text{'ech_n'}</td>\n",
		$opts{'no-netdb-exchange'} ? "" : "checked";

	print "<td><b>$text{'ech_nd1'}</b></td>\n";
	printf "<td><input type=radio name=no-delay value=1 %s> $text{'ech_y'}\n",
		$opts{'no-delay'} ? "checked" : "";
	printf "<input type=radio name=no-delay value=0 %s> $text{'ech_n'}</td> </tr>\n",
		$opts{'no-delay'} ? "" : "checked";
	}

if ($squid_version >= 2.1) {
	local $mode = $opts{'login'} eq 'PASS' ? 2 :
		      $opts{'login'} =~ /^\*:\S+$/ ? 3 :
		      $opts{'login'} ? 1 : 0;
	local @up = split(/:/, $opts{'login'});
	print "<tr> <td valign=top><b>$text{'ech_ltp'}</b></td>\n";
	print "<td colspan=3>\n";
	printf "<input type=radio name=login value=0 %s> $text{'ech_nl'}<br>\n",
		$mode == 0 ? "checked" : "";
	printf "<input type=radio name=login value=1 %s>\n",
		$mode == 1 ? "checked" : "";
	printf "$text{'ech_u'} <input name=login_user size=15 value=\"%s\">\n", $mode == 1 ? $up[0] : "";
		
	printf "$text{'ech_p'} <input name=login_pass size=15 value=\"%s\"><br>\n", $mode == 1 ? $up[1] : "";
	if ($squid_version >= 2.5 || $mode > 1) {
		printf "<input type=radio name=login value=2 %s> %s<br>\n",
			$mode == 2 ? "checked" : "",
			$text{'ech_pass'};
		printf "<input type=radio name=login value=3 %s> %s\n",
			$mode == 3 ? "checked" : "",
			$text{'ech_upass'};
		printf "<input name=login_pass2 size=15 value=\"%s\">\n",
			$mode == 3 ? $up[1] : "";
		}
	print "</td> </tr>\n";
	}

if ($squid_version >= 2.6) {
	print "<tr> <td><b>$text{'ech_timeo'}</b></td>\n";
	printf "<td><input type=radio name=connect-timeout_def value=1 %s> $text{'ech_d'}\n",
		$opts{'connect-timeout'} ? "" : "checked";
	printf "<input type=radio name=connect-timeout_def value=0 %s>\n",
		$opts{'connect-timeout'} ? "checked" : "";
	print "<input name=connect-timeout size=6 value=\"$opts{'connect-timeout'}\"></td>\n";

	print "<td><b>$text{'ech_digest'}</b></td>\n";
	printf "<td><input type=radio name=digest-url_def value=1 %s> $text{'ech_d'}\n",
		$opts{'digest-url'} ? "" : "checked";
	printf "<input type=radio name=digest-url_def value=0 %s>\n",
		$opts{'digest-url'} ? "checked" : "";
	print "<input name=digest-url size=20 value=\"$opts{'digest-url'}\"></td> </tr>\n";

	print "<tr> <td><b>$text{'ech_miss'}</b></td>\n";
	printf "<td><input type=radio name=allow-miss value=1 %s> $text{'ech_y'}\n",
		$opts{'allow-miss'} ? "checked" : "";
	printf "<input type=radio name=allow-miss value=0 %s> $text{'ech_n'}</td>\n",
		$opts{'allow-miss'} ? "" : "checked";

	print "<td><b>$text{'ech_maxconn'}</b></td>\n";
	printf "<td><input type=radio name=max-conn_def value=1 %s> $text{'ech_d'}\n",
		$opts{'max-conn'} ? "" : "checked";
	printf "<input type=radio name=max-conn_def value=0 %s>\n",
		$opts{'max-conn'} ? "checked" : "";
	print "<input name=max-conn size=6 value=\"$opts{'max-conn'}\"></td> </tr>\n";

	print "<tr> <td><b>$text{'ech_htcp'}</b></td>\n";
	printf "<td><input type=radio name=htcp value=1 %s> $text{'ech_y'}\n",
		$opts{'htcp'} ? "checked" : "";
	printf "<input type=radio name=htcp value=0 %s> $text{'ech_n'}</td>\n",
		$opts{'htcp'} ? "" : "checked";

	print "<td><b>$text{'ech_force'}</b></td>\n";
	printf "<td><input type=radio name=forceddomain_def value=1 %s> %s\n",
		$opts{'forceddomain'} ? "" : "checked", $text{'ech_same'};
	printf "<input type=radio name=forceddomain_def value=0 %s>\n",
		$opts{'forceddomain'} ? "checked" : "";
	print "<input name=forceddomain size=20 value=\"$opts{'forceddomain'}\"></td> </tr>\n";

	print "<tr> <td><b>$text{'ech_origin'}</b></td>\n";
	printf "<td><input type=radio name=originserver value=1 %s> $text{'ech_y'}\n",
		$opts{'originserver'} ? "checked" : "";
	printf "<input type=radio name=originserver value=0 %s> $text{'ech_n'}</td>\n",
		$opts{'originserver'} ? "" : "checked";

	print "<td><b>$text{'ech_ssl'}</b></td>\n";
	printf "<td><input type=radio name=ssl value=1 %s> $text{'ech_y'}\n",
		$opts{'ssl'} ? "checked" : "";
	printf "<input type=radio name=ssl value=0 %s> $text{'ech_n'}</td> </tr>\n",
		$opts{'ssl'} ? "" : "checked";
	}

print "<tr> <td><b>$text{'ech_mr'}</b></td>\n";
printf "<td><input type=radio name=multicast-responder value=1 %s> $text{'ech_y'}\n",
	$opts{'multicast-responder'} ? "checked" : "";
printf "<input type=radio name=multicast-responder value=0 %s> $text{'ech_n'}</td>\n",
	$opts{'multicast-responder'} ? "" : "checked";
print "</tr>\n";

if (!$in{'new'}) {
	@chd = &find_config($cache_host."_domain", $conf);
	foreach $chd (@chd) {
		@chdv = @{$chd->{'values'}};
		if ($chdv[0] eq $ch[0]) {
			# found a record for this host..
			for($i=1; $i<@chdv; $i++) {
				if ($chdv[$i] =~ /^\!(\S+)$/) {
					push(@dontq, $1);
					}
				else { push(@doq, $chdv[$i]); }
				}
			}
		}
	}
print "<tr> <td valign=top><b>$text{'ech_qhfd'}</b></td>\n";
print "<td><textarea name=doq rows=6 cols=25>",join("\n", @doq),
      "</textarea></td>\n";
print "<td valign=top><b>$text{'ech_dqfd'}</b></td>\n";
print "<td><textarea name=dontq rows=6 cols=25>",join("\n", @dontq),
      "</textarea></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
print "<td><input type=submit value=$text{'ech_buttsave'}></td> <td align=right>\n";
if (!$in{'new'}) { print "<input type=submit value=$text{'ech_buttdel'} name=delete>\n"; }
print "</td></tr></table>\n";
print "</form>\n";

&ui_print_footer("edit_icp.cgi", $text{'ech_return'},
	"", $text{'index_return'});

