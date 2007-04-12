#!/usr/local/bin/perl
# edit_authparam.cgi
# A form for editing authentication programs

require './squid-lib.pl';
$access{'authparam'} || &error($text{'authparam_ecannot'});
&ui_print_header(undef, $text{'authparam_title'}, "", "edit_authparam", 0, 0, 0,
	&restart_button());
$conf = &get_config();

print "<form action=save_authparam.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'authparam_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($squid_version >= 2.5) {
	# Squid versions 2.5 and above use different config options for
	# the external authentication program
	local @auth = &find_config("auth_param", $conf);

	# Show basic authentication options
	local %basic = map { $_->{'values'}->[1], $_->{'values'} }
			grep { $_->{'values'}->[0] eq 'basic' } @auth;
	print "<tr> <td valign=top><b>$text{'authparam_bprogram'}</b></td>\n";
	print "<td nowrap>\n";
	local @p = @{$basic{'program'}};
	local $m = !@p ? 0 :
		   $p[2] =~ /^(\S+)/ && $1 eq $auth_program ? 2 : 1;
	printf "<input type=radio name=b_auth_mode value=0 %s> %s\n",
		$m == 0 ? "checked" : "", $text{'none'};
	printf "<input type=radio name=b_auth_mode value=2 %s> %s\n",
		$m == 2 ? "checked" : "", $text{'eprogs_capweb'};
	printf "<input type=radio name=b_auth_mode value=1 %s>\n",
		$m == 1 ? "checked" : "";
	printf "<input name=b_auth size=40 value='%s'> %s</td>\n",
		$m == 1 ? join(" ", @p[2..$#p]) : "",
		&file_chooser_button("b_auth");
	print "</tr>\n";

	local $c = $basic{'children'}->[2];
	print "<tr> <td><b>$text{'eprogs_noap'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=b_children_def value=1 %s> %s\n",
		$c eq "" ? "checked" : "", $text{'default'};
	printf "<input type=radio name=b_children_def value=0 %s>\n",
		$c eq "" ? "" : "checked";
	printf "<input name=b_children size=5 value='%s'></td> </tr>\n", $c;

	local @t = @{$basic{'credentialsttl'}};
	print "<tr> <td><b>$text{'eprogs_ttl'}</b></td>\n";
	printf "<td nowrap><input type=radio name=b_ttl_def value=1 %s> %s\n",
		!@t ? "checked" : "", $text{'default'};
	printf "<input type=radio name=b_ttl_def value=0 %s>\n",
		!@t ? "" : "checked";
	print &time_fields("b_ttl", 6, $t[2], $t[3]),"</td>\n";

	local @r = @{$basic{'realm'}};
	local $r = join(" ", @r[2..$#r]);
	print "<tr> <td><b>$text{'eprogs_realm'}</b></td> <td>\n";
	printf "<input type=radio name=b_realm_def value=1 %s> %s\n",
		$r eq "" ? "checked" : "", $text{'default'};
	printf "<input type=radio name=b_realm_def value=0 %s>\n",
		$r eq "" ? "" : "checked";
	printf "<input name=b_realm size=40 value='%s'></td> </tr>\n", $r;

	# Show digest authentication options
	print "<tr> <td colspan=2><hr></td> </tr>\n";
	local %digest = map { $_->{'values'}->[1], $_->{'values'} }
			grep { $_->{'values'}->[0] eq 'digest' } @auth;
	print "<tr> <td valign=top><b>$text{'authparam_dprogram'}</b></td>\n";
	print "<td nowrap>\n";
	local @p = @{$digest{'program'}};
	local $m = @p ? 1 : 0;
	printf "<input type=radio name=d_auth_mode value=0 %s> %s\n",
		$m == 0 ? "checked" : "", $text{'none'};
	printf "<input type=radio name=d_auth_mode value=1 %s>\n",
		$m == 1 ? "checked" : "";
	printf "<input name=d_auth size=40 value='%s'> %s</td>\n",
		$m == 1 ? join(" ", @p[2..$#p]) : "",
		&file_chooser_button("d_auth");
	print "</tr>\n";

	local $c = $digest{'children'}->[2];
	print "<tr> <td><b>$text{'eprogs_noap'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=d_children_def value=1 %s> %s\n",
		$c eq "" ? "checked" : "", $text{'default'};
	printf "<input type=radio name=d_children_def value=0 %s>\n",
		$c eq "" ? "" : "checked";
	printf "<input name=d_children size=5 value='%s'></td>\n", $c;

	local @r = @{$digest{'realm'}};
	local $r = join(" ", @r[2..$#r]);
	print "<tr> <td><b>$text{'eprogs_realm'}</b></td> <td>\n";
	printf "<input type=radio name=d_realm_def value=1 %s> %s\n",
		$r eq "" ? "checked" : "", $text{'default'};
	printf "<input type=radio name=d_realm_def value=0 %s>\n",
		$r eq "" ? "" : "checked";
	printf "<input name=d_realm size=40 value='%s'></td> </tr>\n", $r;

	# Show NTML authentication options
	print "<tr> <td colspan=2><hr></td> </tr>\n";
	local %ntlm = map { $_->{'values'}->[1], $_->{'values'} }
			grep { $_->{'values'}->[0] eq 'ntlm' } @auth;
	print "<tr> <td valign=top><b>$text{'authparam_nprogram'}</b></td>\n";
	print "<td nowrap>\n";
	local @p = @{$ntlm{'program'}};
	local $m = @p ? 1 : 0;
	printf "<input type=radio name=n_auth_mode value=0 %s> %s\n",
		$m == 0 ? "checked" : "", $text{'none'};
	printf "<input type=radio name=n_auth_mode value=1 %s>\n",
		$m == 1 ? "checked" : "";
	printf "<input name=n_auth size=40 value='%s'> %s</td>\n",
		$m == 1 ? join(" ", @p[2..$#p]) : "",
		&file_chooser_button("n_auth");
	print "</tr>\n";

	local $c = $ntlm{'children'}->[2];
	print "<tr> <td><b>$text{'eprogs_noap'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=n_children_def value=1 %s> %s\n",
		$c eq "" ? "checked" : "", $text{'default'};
	printf "<input type=radio name=n_children_def value=0 %s>\n",
		$c eq "" ? "" : "checked";
	printf "<input name=n_children size=5 value='%s'></td> </tr>\n", $c;

	local $r = $ntlm{'max_challenge_reuses'}->[2];
	print "<tr> <td><b>$text{'authparam_reuses'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=n_reuses_def value=1 %s> %s\n",
		$r eq "" ? "checked" : "", $text{'default'};
	printf "<input type=radio name=n_reuses_def value=0 %s>\n",
		$r eq "" ? "" : "checked";
	printf "<input name=n_reuses size=5 value='%s'></td> </tr>\n", $r;

	local @t = @{$ntlm{'max_challenge_lifetime'}};
	print "<tr> <td><b>$text{'authparam_lifetime'}</b></td>\n";
	printf "<td nowrap><input type=radio name=n_ttl_def value=1 %s> %s\n",
		!@t ? "checked" : "", $text{'default'};
	printf "<input type=radio name=n_ttl_def value=0 %s>\n",
		!@t ? "" : "checked";
	print &time_fields("n_ttl", 6, $t[2], $t[3]),"</td> </tr>\n";
	}
elsif ($squid_version >= 2) {
	# Squid versions 2 and above use a single external
	# authentication program
	print "<tr>\n";
	local $v = &find_config("authenticate_program", $conf);
	print "<td valign=top><b>$text{'eprogs_cap'}</b></td>\n";
	print "<td nowrap>\n";
	local $m = !$v ? 0 :
		   $v->{'value'} =~ /^(\S+)/ && $1 eq $auth_program ? 2 : 1;
	printf "<input type=radio name=auth_mode value=0 %s> %s\n",
		$m == 0 ? "checked" : "", $text{'none'};
	printf "<input type=radio name=auth_mode value=2 %s> %s\n",
		$m == 2 ? "checked" : "", $text{'eprogs_capweb'};
	printf "<input type=radio name=auth_mode value=1 %s>\n",
		$m == 1 ? "checked" : "";
	printf "<input name=auth size=40 value='%s'> %s</td>\n",
		$m == 1 ? $v->{'value'} : "", &file_chooser_button("auth");
	print "</tr>\n";

        print "<tr>\n";
        print &opt_input($text{'eadm_par'}, "proxy_auth_realm",
                         $conf, $text{'eadm_default'}, 40); 
        print "</tr>\n";      

	print "<tr>\n";
	print &opt_input($text{'eprogs_noap'},
			 "authenticate_children", $conf, $text{'default'}, 6);
	print "</tr>\n";

	if ($squid_version >= 2.4) {
		print "<tr>\n";
		print &opt_time_input($text{'authparam_ttl'},
		    "authenticate_ttl", $conf, $text{'default'}, 6);
		print "</tr>\n";
		print "<tr>\n";
		print &opt_time_input($text{'authparam_ipttl'},
		    "authenticate_ip_ttl", $conf, $text{'authparam_never'}, 6);
		print "</tr>\n";
		}
	}
print "<tr> <td colspan=2><hr></td> </tr>\n";
print "<tr> <td colspan=2>".$text{'authparam_mui_msg'}."</td> </tr>\n";
	print "<tr> <td colspan=2><hr></td> </tr>\n";
# my stuff
	local $taa = &find_value("authenticate_ip_ttl", $conf);
	if($taa ne ""){
		(@ta[0],@ta[1])=split(/\s+/,$taa);
	}
	print "<tr> <td><b>$text{'eprogs_aittl'}</b></td>\n";
	printf "<td nowrap><input type=radio name=b_aittl_def value=1 %s> %s\n",
		!@ta ? "checked" : "", $text{'default'};
	printf "<input type=radio name=b_aittl_def value=0 %s>\n",
		!@ta ? "" : "checked";
	print &time_fields("b_aittl", 6, $ta[0], $ta[1]),"</td></tr>\n";
	print "<tr> <td colspan=2><hr></td> </tr>\n";
# end my stuff
print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'buttsave'}'></form>\n";

&ui_print_footer("", $text{'eprogs_return'});

