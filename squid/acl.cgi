#!/usr/local/bin/perl
# acl.cgi
# Display a form for editing or creating a new ACL

require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
$conf = &get_config();

if ($in{'type'}) {
	&ui_print_header(undef, $text{'acl_header1'}, "", undef, 0, 0, 0, &restart_button());
	$type = $in{'type'};
	}
else {
	&ui_print_header(undef, $text{'acl_header2'}, "", undef, 0, 0, 0, &restart_button());
	@acl = @{$conf->[$in{'index'}]->{'values'}};
	$type = $acl[1];
	if (($type eq "external" ||
	     &indexof($type, @caseless_acl_types) >= 0) &&
	    $acl[3] =~ /^"(.*)"$/) {
		# Extra parameters come from file
		@vals = ( $acl[2] );
		$file = $1;
		}
	elsif ($acl[2] =~ /^"(.*)"$/) {
		# All values come from a file
		$file = $1;
		}
	else {
		# All values come from acl parameters
		@vals = @acl[2..$#acl];
		}
	if ($file) {
		open(FILE, $file);
		chop(@newvals = <FILE>);
		close(FILE);
		push(@vals, @newvals);
		}
	if ($type =~ /^(src|dst|srcdomain|dstdomain|user|myip)$/) {
		@vals = sort { $a cmp $b } @vals;
		}
	elsif ($type eq "port") {
		@vals = sort { $a <=> $b } @vals;
		}
	@deny = grep { $_->{'values'}->[1] eq $acl[0] }
			&find_config("deny_info", $conf);
	}

print "<form action=acl_save.cgi method=post enctype=multipart/form-data>\n";
if (@acl) {
	print "<input type=hidden name=index value=$in{'index'}>\n";
	}
if (@deny) {
	print "<input type=hidden name=dindex value=$deny[0]->{'index'}>\n";
	}
print "<input type=hidden name=type value=$type>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$acl_types{$type} ACL</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td nowrap><b>$text{'acl_name'}</b></td>\n";
print "<td><input name=name size=20 value=\"$acl[0]\"></td>\n";

if ($type eq "src" || $type eq "dst") {
	print "<tr> <td colspan=2><table>\n";
	print "<tr> <td><b>$text{'acl_fromip'}</b></td> ",
		"<td><b>$text{'acl_toip'}</b></td>\n";
	print "     <td><b>$text{'acl_nmask'}</b></td> </tr>\n";
	for($i=0; $i<=@vals; $i++) {
		if ($vals[$i] =~ /^([a-z0-9\.\:]+)-([a-z0-9\.\:]+)\/([\d\.]+)$/) {
			$from = $1; $to = $2; $mask = $3;
			}
		elsif ($vals[$i] =~ /^([a-z0-9\.\:]+)-([a-z0-9\.\:]+)$/) {
			$from = $1; $to = $2; $mask = "";
			}
		elsif ($vals[$i] =~ /^([a-z0-9\.\:]+)\/([\d\.]+)$/) {
			$from = $1; $to = ""; $mask = $2;
			}
		elsif ($vals[$i] =~ /^([a-z0-9\.\:]+)$/) {
			$from = $1; $to = ""; $mask = "";
			}
		else { $from = $to = $mask = ""; }
		print "<tr>\n";
		print "<td><input name=from_$i size=15 value=\"$from\"></td>\n";
		print "<td><input name=to_$i size=15 value=\"$to\"></td>\n";
		print "<td><input name=mask_$i size=15 value=\"$mask\"></td>\n";
		print "</tr>\n";
		}
	print "</table></td> </tr>\n";
	}
elsif ($type eq "myip") {
	print "<tr> <td colspan=2><table>\n";
	print "<tr> <td><b>$text{'acl_ipaddr'}</b></td> ",
		"<td><b>$text{'acl_nmask'}</b></td> </tr>\n";
	for($i=0; $i<=@vals; $i++) {
		if ($vals[$i] =~ /^([a-z0-9\.\:]+)\/([\d\.]+)$/) {
			$ip = $1; $mask = $2;
			}
		else { $ip = $mask = ""; }
		print "<tr>\n";
		print "<td><input name=ip_$i size=15 value=\"$ip\"></td>\n";
		print "<td><input name=mask_$i size=15 value=\"$mask\"></td>\n";
		print "</tr>\n";
		}
	print "</table></td> </tr>\n";
	}
elsif ($type eq "srcdomain") {
	print "<tr> <td valign=top><b>$text{'acl_domains'}</b></td>\n";
	print "<td><textarea name=vals rows=6 cols=40>",join("\n", @vals),
	      "</textarea></td> </tr>\n";
	}
elsif ($type eq "dstdomain") {
	print "<tr> <td valign=top><b>$text{'acl_domains'}</b></td>\n";
	print "<td><textarea name=vals rows=6 cols=40>",join("\n", @vals),
	      "</textarea></td> </tr>\n";
	}
elsif ($type eq "time") {
	local $vals = join(' ', @vals);
	if ($vals =~ /[A-Z]+/) {
		foreach $d (split(//, $vals)) {
			$day{$d}++;
			}
		}
	if ($vals =~ /(\d+):(\d+)-(\d+):(\d+)/) {
		$h1 = $1; $m1 = $2;
		$h2 = $3; $m2 = $4;
		$hour++;
		}
	print "<tr> <td valign=top><b>$text{'acl_dofw'}</b></td> <td>\n";
	printf "<input type=radio name=day_def value=1 %s> $text{'acl_all'}\n",
		%day ? "" : "checked";
	printf "<input type=radio name=day_def value=0 %s> $text{'acl_sel'}<br>\n",
		%day ? "checked" : "";
	%day_name = ( 'S', $text{'acl_dsun'}, 
                      'M', $text{'acl_dmon'}, 
                      'T', $text{'acl_dtue'},
		      'W', $text{'acl_dwed'}, 
                      'H', $text{'acl_dthu'}, 
                      'F', $text{'acl_dfri'},
		      'A', $text{'acl_dsat'} );
	print "<select name=day multiple size=7>\n";
	foreach $d ('S', 'M', 'T', 'W', 'H', 'F', 'A') {
		printf "<option value=$d %s>$day_name{$d}</option>\n",
			$day{$d} ? "selected" : "";
		}
	print "</select></td> </tr>\n";

	print "<tr> <td valign=top><b>$text{'acl_hofd'}</b></td> <td>\n";
	printf "<input type=radio name=hour_def value=1 %s> $text{'acl_all'}\n",
		$hour ? "" : "checked";
	printf "&nbsp;<input type=radio name=hour_def value=0 %s>\n",
		$hour ? "checked" : "";
	print "<input name=h1 size=2 value=\"$h1\">:";
	print "<input name=m1 size=2 value=\"$m1\"> $text{'acl_to'} ";
	print "<input name=h2 size=2 value=\"$h2\">:";
	print "<input name=m2 size=2 value=\"$m2\"></td> </tr>\n";
	}
elsif ($type eq "url_regex") {
	print "<tr> <td valign=top><b>$text{'acl_regexp'}</b></td>\n";
	local $caseless;
	if ($vals[0] eq '-i') {
		$caseless++;
		shift(@vals);
		}
	printf "<td><input type=checkbox name=caseless value=1 %s> %s<br>\n",
		$caseless ? 'checked' : '', $text{'acl_case'};
	print "<textarea name=vals rows=6 cols=40>",join("\n", @vals),
	      "</textarea></td> </tr>\n";
	}
elsif ($type eq "urlpath_regex") {
	print "<tr> <td valign=top><b>$text{'acl_regexp'}</b></td>\n";
	local $caseless;
	if ($vals[0] eq '-i') {
		$caseless++;
		shift(@vals);
		}
	printf "<td><input type=checkbox name=caseless value=1 %s> %s<br>\n",
		$caseless ? 'checked' : '', $text{'acl_case'};
	print "<textarea name=vals rows=6 cols=40>",join("\n", @vals),
	      "</textarea></td> </tr>\n";
	}
elsif ($type eq "port") {
	print "<tr> <td valign=top><b>$text{'acl_tcpports'}</b></td>\n";
	printf "<td><input name=vals size=30 value=\"%s\"></td> </tr>\n",
		join(" ", @vals);
	}
elsif ($type eq "proto") {
	print "<tr> <td valign=top><b>$text{'acl_urlproto'}</b></td> <td>\n";
	foreach $p (@vals) { $proto{$p}++; }
	foreach $p ('http', 'ftp', 'gopher', 'wais', 'cache_object') {
		printf "<input type=checkbox name=vals value=$p %s> $p\n",
			$proto{$p} ? "checked" : "";
		}
	print "</td> </tr>\n";
	}
elsif ($type eq "method") {
	print "<tr> <td valign=top><b>$text{'acl_reqmethods'}</b></td> <td>\n";
	foreach $m (@vals) { $meth{$m}++; }
	foreach $m ('GET', 'POST', 'HEAD', 'CONNECT', 'PUT', 'DELETE') {
		printf "<input type=checkbox name=vals value=$m %s> $m\n",
			$meth{$m} ? "checked" : "";
		}
	print "</td> </tr>\n";
	}
elsif ($type eq "browser") {
	print "<tr> <td valign=top><b>$text{'acl_bregexp'}</b></td>\n";
	printf "<td><input name=vals size=30 value=\"%s\"></td> </tr>\n",
		join(' ', @vals);
	}
elsif ($type eq "user") {
	print "<tr> <td valign=top><b>$text{'acl_pusers'}</b></td>\n";
	print "<td><textarea name=vals rows=6 cols=40 wrap>",
		join("\n", @vals),"</textarea></td> </tr>\n";
	}
elsif ($type eq "src_as" || $type eq "dst_as") {
	print "<tr> <td valign=top><b>$text{'acl_asnum'}</b></td>\n";
	printf "<td><input name=vals size=20 value=\"%s\"></td> </tr>\n",
		join(' ', @vals);
	}
elsif ($type eq "proxy_auth" && $squid_version < 2.3) {
	print "<tr> <td valign=top><b>$text{'acl_rtime'}</b></td>\n";
	print "<td><input name=vals size=8 value=\"$vals[0]\"></td> </tr>\n";
	}
elsif ($type eq "proxy_auth" && $squid_version >= 2.3) {
	print "<tr> <td valign=top><b>$text{'acl_eusers'}</b></td>\n";
	printf "<td><input type=radio name=authall value=1 %s> %s\n",
		$vals[0] eq 'REQUIRED' || $in{'type'} ? "checked" : "",
		$text{'acl_eusersall'};
	printf "<input type=radio name=authall value=0 %s> %s<br>\n",
		$vals[0] eq 'REQUIRED' || $in{'type'} ? "" : "checked",
		$text{'acl_euserssel'};
	print "<textarea name=vals rows=6 cols=40 wrap>",
		$vals[0] eq 'REQUIRED' || $in{'type'} ? "" : join("\n", @vals),
		"</textarea></td> </tr>\n";
	}
elsif ($type eq "proxy_auth_regex") {
	print "<tr> <td valign=top><b>$text{'acl_eusers'}</b></td>\n";
	local $caseless;
	if ($vals[0] eq '-i') {
		$caseless++;
		shift(@vals);
		}
	printf "<td><input type=checkbox name=caseless value=1 %s> %s<br>\n",
		$caseless ? 'checked' : '', $text{'acl_case'};
	print "<textarea name=vals rows=6 cols=40 wrap>",
		join("\n", @vals),"</textarea></td> </tr>\n";
	}
elsif ($type eq "srcdom_regex" || $type eq "dstdom_regex") {
	print "<tr> <td valign=top><b>$text{'acl_regexp'}</b></td>\n";
	local $caseless;
	if ($vals[0] eq '-i') {
		$caseless++;
		shift(@vals);
		}
	printf "<td><input type=checkbox name=caseless value=1 %s> %s<br>\n",
		$caseless ? 'checked' : '', $text{'acl_case'};
	print "<textarea name=vals rows=6 cols=40>",join("\n", @vals),
	      "</textarea></td> </tr>\n";
	}
elsif ($type eq "ident") {
	print "<tr> <td valign=top><b>$text{'acl_rfcusers'}</b></td>\n";
	print "<td><textarea name=vals rows=6 cols=40 wrap>",
		join(' ', @vals),"</textarea></td> </tr>\n";
	}
elsif ($type eq "ident_regex") {
	print "<tr> <td valign=top><b>$text{'acl_rfcusersr'}</b></td>\n";
	local $caseless;
	if ($vals[0] eq '-i') {
		$caseless++;
		shift(@vals);
		}
	printf "<td><input type=checkbox name=caseless value=1 %s> %s<br>\n",
		$caseless ? 'checked' : '', $text{'acl_case'};
	print "<textarea name=vals rows=6 cols=40 wrap>",
		join("\n", @vals),"</textarea></td> </tr>\n";
	}
elsif ($type eq "maxconn") {
	print "<tr> <td valign=top><b>$text{'acl_mcr'}</b></td>\n";
	print "<td><input name=vals size=8 value=\"$vals[0]\"></td> </tr>\n";
	}
elsif ($type eq "max_user_ip") {
	local $mipstrict;
	if ($vals[0] eq '-s') {
		$mipstrict++;
		shift(@vals);
	}
	print "<tr><td><b>$text{'acl_mai'}</b></td><td><input name=vals size=8 value=\"$vals[0]\"></td> </tr>\n";
#	print "<tr> <td valign=top><b>$text{'acl_extargs'}</b></td>\n";
	print "<tr><td>$text{'acl_maistrict'}</td>";
	printf "<td><input type=checkbox name=strict value=1 %s></td></tr>\n",
		$mipstrict ? 'checked' : '';
	print "<tr><td colspan=2>$text{'acl_mairemind'}</td></tr>";

#	printf "<td><input name=args size=25 value=\"%s\"></td> </tr>\n",
#		join(" ", @vals[0]);
	}

elsif ($type eq "myport") {
	print "<tr> <td valign=top><b>$text{'acl_psp'}</b></td>\n";
	print "<td><input name=vals size=8 value=\"$vals[0]\"></td> </tr>\n";
	}
elsif ($type eq "snmp_community") {
	print "<tr> <td valign=top><b>$text{'acl_scs'}</b></td>\n";
	print "<td><input name=vals size=15 value=\"$vals[0]\"></td> </tr>\n";
	}
elsif ($type eq "req_mime_type") {
	print "<tr> <td valign=top><b>$text{'acl_rmt'}</b></td>\n";
	print "<td><input name=vals size=15 value=\"$vals[0]\"></td> </tr>\n";
	}
elsif ($type eq "rep_mime_type") {
	print "<tr> <td valign=top><b>$text{'acl_rpmt'}</b></td>\n";
	print "<td><input name=vals size=15 value=\"$vals[0]\"></td> </tr>\n";
	}
elsif ($type eq "arp") {
	print "<tr> <td valign=top><b>$text{'acl_arp'}</b></td>\n";
	print "<td><textarea name=vals rows=6 cols=40>",join("\n", @vals),
	      "</textarea></td> </tr>\n";
	}
elsif ($type eq "external") {
	print "<tr> <td valign=top><b>$text{'acl_extclass'}</b></td>\n";
	print "<td><select name=class>\n";
	foreach $c (&find_config("external_acl_type", $conf)) {
		printf "<option %s>%s</option>\n",
			$c->{'values'}->[0] eq $vals[0] ? "selected" : "",
			$c->{'values'}->[0];
		}
	print "</select></td> </tr>\n";
	print "<tr> <td valign=top><b>$text{'acl_extargs'}</b></td>\n";
	printf "<td><input name=args size=25 value=\"%s\"></td> </tr>\n",
		join(" ", @vals[1..$#vals]);
	}

# Show URL to redirect on failure
print "<tr> <td><b>$text{'acl_failurl'}</b></td>\n";
printf "<td><input name=deny size=35 value=\"%s\"></td> </tr>\n",
	@deny ? $deny[0]->{'values'}->[0] : "";

# Show file in which ACL is stored
print "<tr> <td><b>$text{'acl_file'}</b></td>\n";
print "<td>",&ui_opt_textbox("file", $file, 40, $text{'acl_nofile'},
			     $text{'acl_infile'})," ",
	     &file_chooser_button("file"),"</td> </tr>\n";

if ($in{'type'}) {
	print "<tr> <td></td>\n";
	print "<td>",&ui_checkbox("keep", 1, $text{'acl_keep'}, 0),"</td> </tr>\n";
	}

print "</table></td></tr></table>\n";
print "<input type=submit value=$text{'acl_buttsave'}>\n";
if (!$in{'type'}) { print "<input type=submit value=$text{'acl_buttdel'} name=delete>\n"; }
print "</form>\n";

&ui_print_footer("edit_acl.cgi?mode=acls", $text{'acl_return'},
		 "", $text{'index_return'});

