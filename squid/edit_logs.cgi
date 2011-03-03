#!/usr/local/bin/perl
# edit_logs.cgi
# A form for editing logging options

require './squid-lib.pl';
$access{'logging'} || &error($text{'elogs_ecannot'});
&ui_print_header(undef, $text{'elogs_header'}, "", "edit_logs", 0, 0, 0, &restart_button());
$conf = &get_config();

print "<form action=save_logs.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'elogs_lalo'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($squid_version < 2.6) {
	# Just a single logging directive
	print "<tr>\n";
	print &opt_input($text{'elogs_alf'}, "cache_access_log", $conf, $text{'default'}, 50);
	print "</tr>\n";
	}
else {
	# Supports definition of log formats and files
	@logformat = &find_config("logformat", $conf);
	$ltable = &ui_radio("logformat_def", @logformat ? 0 : 1,
			    [ [ 1, $text{'elogs_logformat1'} ],
			      [ 0, $text{'elogs_logformat0'} ] ])."<br>\n";
	$ltable .= &ui_columns_start([ $text{'elogs_fname'},
				      $text{'elogs_ffmt'} ]);
	$i = 0;
	foreach $f (@logformat, { }) {
		($fname, @ffmt) = @{$f->{'values'}};
		$ltable .= &ui_columns_row([
			&ui_textbox("fname_$i", $fname, 20),
			&ui_textbox("ffmt_$i", join(" ", @ffmt), 60)
			]);
		$i++;
		}
	$ltable .= &ui_columns_end();
	print "<tr> <td valign=top><b>$text{'elogs_logformat'}</b></td>\n";
	print "<td colspan=3>$ltable</td> </tr>\n";

	# Show log files
	@access = &find_config("access_log", $conf);
	$atable = &ui_columns_start([ $text{'elogs_afile'},
				      $text{'elogs_afmt'},
				      $text{'elogs_aacls'} ]);
	$i = 0;
	foreach $a (@access, { }) {
		($afile, $afmt, @aacls) = @{$a->{'values'}};
		$atable .= &ui_columns_row([
		  &ui_radio("afile_def_$i",
			    !$afile ? 1 : $afile eq "none" ? 2 : 0,
			    [ [ 1, $text{'elogs_notset'} ],
			      [ 2, $text{'elogs_dont'} ],
			      [ 0, &text('elogs_file',
				    &ui_textbox("afile_$i",
						$afile eq "none" ? "" : $afile,
						30)) ] ]),
		  &ui_select("afmt_$i", $afmt,
			     [ [ "", "&lt;".$text{'default'}."&gt;" ],
			       map { [ $_->{'values'}->[0] ] } @logformat ]),
		  &ui_textbox("aacls_$i", join(" ", @aacls), 20)
		  ]);
		$i++;
		}
	$atable .= &ui_columns_end();
	print "<tr> <td valign=top><b>$text{'elogs_access'}</b></td>\n";
	print "<td colspan=3>$atable</td> </tr>\n";

	print "<tr> <td colspan=4><hr></td> </tr>\n";
	print "</table><table width=100%>\n";
	}

print "<tr>\n";
print &opt_input($text{'elogs_dlf'}, "cache_log", $conf, $text{'default'}, 50);
print "</tr>\n";

print "<tr>\n";
$cslv = &find_config("cache_store_log", $conf);
$cslm = $cslv->{'value'} eq 'none' ? 2 : $cslv->{'value'} ? 0 : 1;
print "<td valign=top><b>$text{'elogs_slf'}</b></td>\n";
print "<td nowrap colspan=3>\n";
printf "<input type=radio name=cache_store_log_def value=1 %s> %s\n",
	$cslm == 1 ? "checked" : "", $text{'default'};
printf "<input type=radio name=cache_store_log_def value=2 %s> %s\n",
	$cslm == 2 ? "checked" : "", $text{'elogs_none'};
printf "<input type=radio name=cache_store_log_def value=0 %s>\n",
	$cslm == 0 ? "checked" : "";
printf "<input name=cache_store_log size=50 value=\"%s\"></td>\n",
	$cslm == 0 ? $cslv->{'value'} : "";
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'elogs_cmf'}, "cache_swap_log", $conf, $text{'default'}, 50);
print "</tr>\n";

print "<tr>\n";
print &choice_input($text{'elogs_uhlf'}, "emulate_httpd_log", $conf,
		    "off", $text{'yes'}, "on", $text{'no'}, "off");
print &choice_input($text{'elogs_lmh'}, "log_mime_hdrs", $conf,
		    "off", $text{'yes'}, "on", $text{'no'}, "off");
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'elogs_ualf'}, "useragent_log", $conf, $text{'none'}, 20);
print &opt_input($text{'elogs_pf'}, "pid_filename", $conf, $text{'default'}, 20);
print "</tr>\n";

if ($squid_version >= 2.2) {
	@ident = &find_config("ident_lookup_access", $conf);
	foreach $i (@ident) {
		local @v = @{$i->{'values'}};
		if ($v[0] eq "allow") { map { $ila{$_}++ } @v[1..$#v]; }
		elsif ($v[0] eq "deny" && $v[1] ne "all") { $bad_ident++; }
		}
	if (!$bad_ident) {
		print "<tr><td valign=top><b>$text{'elogs_prilfa'}</b></td> <td colspan=3>\n";
		@acls = &find_config("acl", $conf);
		unshift(@acls, { 'values' => [ 'all' ] })
			if ($squid_version >= 3);
		foreach $acl (@acls) {
			$aclv = $acl->{'values'}->[0];
			next if ($doneacl{$aclv}++);
			printf "<input type=checkbox name=ident_lookup_access ".
			       "value=$aclv %s>$aclv\n",
				$ila{$aclv} ? "checked" : "";
			}
		print "</td> </tr>\n";
		}
	else { print "<input type=hidden name=complex_ident value=1>\n"; }
	print "<tr>\n";
	print &opt_time_input($text{'elogs_rit'}, "ident_timeout",
			      $conf, $text{'default'}, 6);
	}
else {
	print "<tr>\n";
	print &choice_input($text{'elogs_dril'}, "ident_lookup", $conf,
			    "off", $text{'yes'}, "on", $text{'no'}, "off");
	}
print &choice_input($text{'elogs_lfh'}, "log_fqdn", $conf,
		    "off", $text{'yes'}, "on", $text{'no'}, "off");
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'elogs_ln'}, "client_netmask", $conf, $text{'default'}, 15);
print &opt_input($text{'elogs_do'}, "debug_options", $conf, $text{'default'}, 15);
print "</tr>\n";

if ($squid_version >= 2) {
	print "<tr>\n";
	print &opt_input($text{'elogs_mht'}, "mime_table",
			 $conf, $text{'default'}, 20);
	print "</tr>\n";
	}

print "</table></td></tr></table>\n";
print "<input type=submit value=$text{'buttsave'}></form>\n";

&ui_print_footer("", $text{'elogs_return'});

