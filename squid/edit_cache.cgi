#!/usr/local/bin/perl
# edit_cache.cgi
# A form for editing cache options

require './squid-lib.pl';
$access{'copts'} || &error($text{'ec_ecannot'});
&ui_print_header(undef, $text{'ec_header'}, "", "edit_cache", 0, 0, 0, &restart_button());
$conf = &get_config();

print "<form action=save_cache.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'ec_cro'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
@dirs = &find_config("cache_dir", $conf);
print "<td valign=top><b>$text{'ec_cdirs'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=cache_dir_def value=1 %s> $text{'ec_default'} ($config{'cache_dir'})\n",
	@dirs ? "" : "checked";
printf "<input type=radio name=cache_dir_def value=0 %s> $text{'ec_listed'}<br>\n",
	@dirs ? "checked" : "";
print "<table border>\n";
if ($squid_version >= 2) {
	print "<tr $tb> <td><b>$text{'ec_directory'}</b></td>\n";
	if ($squid_version >= 2.3) {
		print "<td><b>$text{'ec_type'}</b></td>\n";
		}
	print "<td><b>$text{'ec_size'}</b></td>\n";
	print "<td><b>$text{'ec_1dirs'}</b></td>\n";
	print "<td><b>$text{'ec_2dirs'}</b></td>\n";
	if ($squid_version >= 2.4) {
		print "<td><b>$text{'ec_opts'}</b></td>\n";
		}
	print "</tr>\n";
	}
for($i=0; $i<=@dirs; $i++) {
	@dv = $i<@dirs ? @{$dirs[$i]->{'values'}} : ();
	print "<tr $cb>\n";
	if ($squid_version >= 2.4) {
		print "<td><input name=cache_dir_$i size=30 ",
		      "value=\"$dv[1]\"></td>\n";
		print "<td><select name=cache_type_$i>\n";
		printf "<option value=ufs %s>$text{'ec_u'}\n",
			$dv[0] eq 'ufs' ? 'selected' : '';
		printf "<option value=diskd %s>$text{'ec_diskd'}\n",
			$dv[0] eq 'diskd' ? 'selected' : '';
		printf "<option value=aufs %s>$text{'ec_ua'}\n",
			$dv[0] eq 'aufs' ? 'selected' : '';
		printf "<option value=coss %s>$text{'ec_coss'}\n",
			$dv[0] eq 'coss' ? 'selected' : '';
		print "</select></td>\n";
		print "<td><input name=cache_size_$i size=8 ",
		      "value=\"$dv[2]\"></td>\n";
		print "<td><input name=cache_lv1_$i size=8 ",
		      "value=\"$dv[3]\"></td>\n";
		print "<td><input name=cache_lv2_$i size=8 ",
		      "value=\"$dv[4]\"></td>\n";
		print "<td><input name=cache_opts_$i size=10 ",
		      "value=\"",join(" ",@dv[5..$#dv]),"\"></td>\n";
		}
	elsif ($squid_version >= 2.3) {
		print "<td><input name=cache_dir_$i size=30 ",
		      "value=\"$dv[1]\"></td>\n";
		print "<td><select name=cache_type_$i>\n";
		printf "<option value=ufs %s>$text{'ec_u'}\n",
			$dv[0] eq 'ufs' ? 'selected' : '';
		printf "<option value=asyncufs %s>$text{'ec_ua'}\n",
			$dv[0] eq 'asyncufs' ? 'selected' : '';
		print "</select></td>\n";
		print "<td><input name=cache_size_$i size=8 ",
		      "value=\"$dv[2]\"></td>\n";
		print "<td><input name=cache_lv1_$i size=8 ",
		      "value=\"$dv[3]\"></td>\n";
		print "<td><input name=cache_lv2_$i size=8 ",
		      "value=\"$dv[4]\"></td>\n";
		}
	elsif ($squid_version >= 2) {
		print "<td><input name=cache_dir_$i size=30 ",
		      "value=\"$dv[0]\"></td>\n";
		print "<td><input name=cache_size_$i size=8 ",
		      "value=\"$dv[1]\"></td>\n";
		print "<td><input name=cache_lv1_$i size=8 ",
		      "value=\"$dv[2]\"></td>\n";
		print "<td><input name=cache_lv2_$i size=8 ",
		      "value=\"$dv[3]\"></td>\n";
		}
	else {
		print "<td><input name=cache_dir_$i size=30 ",
		      "value=\"$dv[0]\"></td>\n";
		}
	print "</tr>\n";
	}
print "</table></td> </tr>\n";
print "<tr> <td colspan=4><hr></td> </tr>\n";

if ($squid_version < 2) {
	print "<tr>\n";
	print &opt_input($text{'ec_1dirs1'}, "swap_level1_dirs", $conf,
			 $text{'ec_default'}, 6);
	print &opt_input($text{'ec_2dirs2'}, "swap_level2_dirs", $conf,
			 $text{'ec_default'}, 6);
	print "</tr>\n";
	}

print "<tr>\n";
if ($squid_version < 2) {
	print &opt_input($text{'ec_aos'}, "store_avg_object_size", $conf,
			 $text{'ec_default'}, 6, $text{'ec_kb'});
	}
else {
	print &opt_bytes_input($text{'ec_aos'}, "store_avg_object_size",
			       $conf, $text{'ec_default'}, 6);
	}
print &opt_input($text{'ec_opb'}, "store_objects_per_bucket", $conf,
		 $text{'ec_default'}, 6);
print "</tr>\n";

if ($squid_version < 2) {
	print "<tr>\n";
	print &list_input($text{'ec_ncuc'}, "cache_stoplist",
			  $conf, 1, $text{'ec_default'});
	print "</tr>\n";

	print "<tr>\n";
	print &list_input($text{'ec_ncum'}, "cache_stoplist_pattern",
			  $conf, 1, $text{'ec_default'});
	print "</tr>\n";
	}

# ACLs not to cache
print "<tr> <td valign=top><b>$text{'ec_ncua'}</b></td> <td>\n";
print "<table>\n";
@acls = grep { !$acldone{$_->{'values'}->[0]}++ } &find_config("acl", $conf);
unshift(@acls, { 'values' => [ 'all' ] }) if ($squid_version >= 3);
if ($squid_version >= 2.6) {
	# 2.6+ plus uses "cache deny"
	@v = &find_config("cache", $conf);
	}
else {
	# Older versions use cache
	@v = &find_config("no_cache", $conf);
	}
foreach $v (@v) {
	foreach $ncv (@{$v->{'values'}}) {
		$noca{$ncv}++;
		}
	}
$i = 0;
foreach $acl (@acls) {
	print "<tr>\n" if ($i%3 == 0);
	$aclv = $acl->{'values'}->[0];
	printf "<td nowrap><input type=checkbox name=no_cache value=$aclv %s>$aclv</td>\n",
		$noca{$aclv} ? "checked" : "";
	print "</tr>\n" if ($i++%3 == 2);
	}
print "</table></td>\n";

print &opt_time_input($text{'ec_mct'}, "reference_age", $conf,
		      $text{'default'}, 6);
print "</tr>\n";

print "<tr>\n";
if ($squid_version >= 2) {
	if ($squid_version >= 2.3) {
		print &opt_bytes_input($text{'ec_mrbs'},
			"request_body_max_size", $conf, $text{'default'}, 6);
		print &opt_bytes_input($text{'ec_mrhs'},
			"request_header_max_size", $conf, $text{'default'}, 6);
		print "</tr>\n";

		print "<tr>\n";
		if ($squid_version < 2.5) {
			print &opt_bytes_input($text{'ec_mrbs1'},
			   "reply_body_max_size", $conf, $text{'default'}, 6);
			}
		else {
			print &opt_bytes_input($text{'ec_gap'},
			   "read_ahead_gap", $conf, $text{'default'}, 6);
			}
		}
	else {
		print &opt_bytes_input($text{'ec_mrs'}, "request_size",
				       $conf, $text{'default'}, 6);
		}
	print &opt_time_input($text{'ec_frct'},
			      "negative_ttl", $conf, $text{'default'}, 4);
	}
else {
	print &opt_input($text{'ec_mrs'}, "request_size", $conf,
			 $text{'default'}, 8, $text{'ec_kb'});
	print &opt_input($text{'ec_frct'}, "negative_ttl", $conf,
			 $text{'default'}, 4, $text{'ec_mins'});
	}
print "</tr>\n";

if ($squid_version >= 2.5) {
	# Max reply size can be limited by ACL
	print "<tr>\n";
	print "<td valign=top><b>$text{'ec_maxreplies'}</b></td>\n";
	print "<td colspan=3><table border>\n";
	print "<tr $tb> <td><b>$text{'ec_maxrn'}</b></td> ",
	      "<td><b>$text{'ec_maxracls'}</b></td> </tr>\n";
	@maxrs = &find_config("reply_body_max_size", $conf);
	$i = 0;
	foreach $m (@maxrs, { }) {
		local ($s, @a) = @{$m->{'values'}};
		print "<tr $cb>\n";
		printf "<td><input name=reply_body_max_size_%d size=8 value='%s'></td>\n",
			$i, $s;
		printf "<td><input name=reply_body_max_acls_%d size=50 value='%s'></td>\n",
			$i, join(" ", @a);
		print "</tr>\n";
		$i++;
		}
	print "</table></tr>\n";
	}

print "<tr>\n";
if ($squid_version < 2) {
	print &opt_input($text{'ec_dlct'}, "positive_dns_ttl", $conf,
			 $text{'default'}, 4, $text{'ec_mins'});
	print &opt_input($text{'ec_fdct'}, "negative_dns_ttl", $conf,
			 $text{'default'}, 4, $text{'ec_mins'});
	}
else {
	print &opt_time_input($text{'ec_dlct'}, "positive_dns_ttl",
			      $conf, $text{'default'}, 4);
	print &opt_time_input($text{'ec_fdct'}, "negative_dns_ttl",
			      $conf, $text{'default'}, 4);
	}
print "</tr>\n";

if ($squid_version < 2) {
	print "<tr>\n";
	print &opt_input($text{'ec_ct'}, "connect_timeout", $conf,
			 $text{'default'}, 4, $text{'ec_secs'});
	print &opt_input($text{'ec_rt'}, "read_timeout", $conf,
			 $text{'default'}, 4, $text{'ec_secs'});
	print "</tr>\n";

	print "<tr>\n";
	print &opt_input($text{'ec_mcct'}, "client_lifetime", $conf,
			 $text{'default'}, 4, $text{'ec_mins'});
	print &opt_input($text{'ec_mst'}, "shutdown_lifetime", $conf,
			 $text{'default'}, 4, $text{'ec_mins'});
	print "</tr>\n";
	}
else {
	print "<tr>\n";
	print &opt_time_input($text{'ec_ct'}, "connect_timeout", $conf,
			      $text{'default'}, 4);
	print &opt_time_input($text{'ec_rt'}, "read_timeout", $conf,
			      $text{'default'}, 4);
	print "<tr>\n";

	print "</tr>\n";
	print &opt_time_input($text{'ec_sst'}, "siteselect_timeout",
			      $conf, $text{'default'}, 4);
	print &opt_time_input($text{'ec_crt'}, "request_timeout",
			      $conf, $text{'default'}, 4);
	print "</tr>\n";

	print "<tr>\n";
	print &opt_time_input($text{'ec_mcct'}, "client_lifetime",
			      $conf, $text{'default'}, 4);
	print &opt_time_input($text{'ec_mst'}, "shutdown_lifetime",
			      $conf, $text{'default'}, 4);
	print "</tr>\n";

	print "<tr>\n";
	print &choice_input($text{'ec_hcc'}, "half_closed_clients",
			    $conf, "on", $text{'on'},"on", $text{'off'},"off");
	print &opt_time_input($text{'ec_pt'}, "pconn_timeout",
			      $conf, $text{'default'}, 4);
	print "</tr>\n";
	}

if ($squid_version < 2) {
	print "<tr> <td><b>$text{'ec_wr'}</b></td> <td colspan=3>\n";
	$v = &find_config("wais_relay", $conf);
	printf "<input type=radio name=wais_relay_def value=1 %s> $text{'none'}\n",
		$v ? "" : "checked";
	printf "<input type=radio name=wais_relay_def value=0 %s> $text{'ec_host'}\n",
		$v ? "checked" : "";
	@wrv = $v ? @{$v->{'values'}} : ();
	print "<input size=20 name=wais_relay1 value=\"$wrv[0]\">&nbsp;$text{'ec_port'}\n";
	print "<input size=6 name=wais_relay2 value=\"$wrv[1]\"></td>\n";
	print "</tr>\n";
	}
else {
	print "<tr>\n";
	print &opt_input($text{'ec_wrh'}, "wais_relay_host",
			 $conf, $text{'none'}, 20);
	print &opt_input($text{'ec_wrp'}, "wais_relay_port",
			 $conf, $text{'default'}, 6);
	print "</tr>\n";
	}

print "</table></td></tr></table>\n";
print "<input type=submit value=$text{'buttsave'}></form>\n";

&ui_print_footer("", $text{'ec_return'});

