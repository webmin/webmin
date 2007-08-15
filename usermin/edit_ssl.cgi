#!/usr/local/bin/perl
# edit_ssl.cgi
# Configure whether Usermin uses SSL or not

require './usermin-lib.pl';
$access{'ssl'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'ssl_title'}, "");
&get_usermin_miniserv_config(\%miniserv);

eval "use Net::SSLeay";
if ($@) {
	print &text('ssl_essl', "http://www.webmin.com/ssl.html"),"\n";
	}
else {
	print $text{'ssl_desc1'},"<p>\n";
	print $text{'ssl_desc2'},"<br>\n";

	print "<form action=change_ssl.cgi>\n";
	print "<table border>\n";
	print "<tr $tb> <td><b>$webmin::text{'ssl_header'}</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";

	print "<tr> <td><b>$webmin::text{'ssl_on'}</b></td>\n";
	printf "<td><input type=radio name=ssl value=1 %s> %s\n",
		$miniserv{'ssl'} ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=ssl value=0 %s> %s</td> </tr>\n",
		$miniserv{'ssl'} ? "" : "checked", $text{'no'};

	print "<tr> <td><b>$webmin::text{'ssl_key'}</b></td>\n";
	printf "<td><input name=key size=40 value='%s'> %s</td> </tr>\n",
		$miniserv{'keyfile'}, &file_chooser_button("key");

	print "<tr> <td valign=top><b>$webmin::text{'ssl_cert'}</b></td>\n";
	printf "<td><input type=radio name=cert_def value=1 %s> %s<br>\n",
		$miniserv{'certfile'} ? "" : "checked",
		$webmin::text{'ssl_cert_def'};
	printf "<input type=radio name=cert_def value=0 %s> %s\n",
		$miniserv{'certfile'} ? "checked" : "",
		$webmin::text{'ssl_cert_oth'};
	printf "<input name=cert size=40 value='%s'> %s</td> </tr>\n",
		$miniserv{'certfile'}, &file_chooser_button("cert");

	print "<tr> <td><b>$webmin::text{'ssl_redirect'}</b></td>\n";
	printf "<td><input type=radio name=ssl_redirect value=1 %s> %s\n",
		$miniserv{'ssl_redirect'} ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=ssl_redirect value=0 %s> %s</td></tr>\n",
		$miniserv{'ssl_redirect'} ? "" : "checked", $text{'no'};

	print "<tr> <td><b>$webmin::text{'ssl_version'}</b></td>\n";	
	print "<td>",&ui_opt_textbox("version", $miniserv{'ssl_version'}, 4,
				     $webmin::text{'ssl_auto'}),"</td> </tr>\n";

	print "<tr> <td valign=top><b>$webmin::text{'ssl_extracas'}</b></td>\n";
	print "<td><textarea name=extracas rows=3 cols=40>";
	foreach $e (split(/\s+/, $miniserv{'extracas'})) {
		print "$e\n";
		}
	print "</textarea></td> </tr>\n";

	print "</table></td></tr></table>\n";
	print "<input type=submit value=\"$text{'save'}\"></form>\n";

	print "<hr>\n";

	# Table listing per-IP SSL certs
	print "$webmin::text{'ssl_ipkeys'}<p>\n";
	@ipkeys = &webmin::get_ipkeys(\%miniserv);
	if (@ipkeys) {
		print &ui_columns_start([ $webmin::text{'ssl_ips'},
					  $webmin::text{'ssl_key'},
					  $webmin::text{'ssl_cert'} ]);
		foreach $k (@ipkeys) {
			print &ui_columns_row([
				"<a href='edit_ipkey.cgi?idx=$k->{'index'}'>".
				join(", ", @{$k->{'ips'}})."</a>",
				"<tt>$k->{'key'}</tt>",
				$k->{'cert'} ? "<tt>$k->{'cert'}</tt>" : "<br>"
				]);
			}
		print &ui_columns_end();
		}
	else {
		print "<b>$webmin::text{'ssl_ipkeynone'}</b><p>\n";
		}
	print "<a href='edit_ipkey.cgi?new=1'>$webmin::text{'ssl_addipkey'}</a><p>\n";

	# SSL key generation form
	print "<hr>\n";
	print "$text{'ssl_newkey'}\n";
	local $curkey = `cat $miniserv{'keyfile'} 2>/dev/null`;
	local $origkey = `cat $miniserv{'root'}/miniserv.pem 2>/dev/null`;
	if ($curkey eq $origkey) {
		# System is using the original (insecure) Usermin key!
		print "<b>$text{'ssl_hole'}</b>\n";
		}
	print "<p>\n";

	print "<form action=newkey.cgi>\n";
	print "<table border>\n";
	print "<tr $tb> <td><b>$webmin::text{'ssl_header1'}</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";
	print "<tr> <td><b>$webmin::text{'ssl_cn'}</b></td>\n";
	print "<td><input type=radio name=commonName_def value=1 checked> ",
	      "$webmin::text{'ssl_all'}\n";
	print "<input type=radio name=commonName_def value=0>\n";
	$host = $ENV{'HTTP_HOST'};
	$host =~ s/:.*//;
	print "<input name=commonName size=30 value='$host'></td> </tr>\n";

	print "<tr> <td><b>$webmin::text{'ca_email'}</b></td>\n";
	printf "<td><input name=emailAddress size=30 value='%s'></td> </tr>\n",
		"usermin\@".&get_system_hostname();

	print "<tr> <td><b>$webmin::text{'ca_ou'}</b></td>\n";
	print "<td><input name=organizationalUnitName size=30></td> </tr>\n";

	$hostname = &get_system_hostname();
	print "<tr> <td><b>$webmin::text{'ca_o'}</b></td>\n";
	print "<td><input name=organizationName size=30 ",
	      "value='Usermin Webserver on $hostname'></td> </tr>\n";

	print "<tr> <td><b>$webmin::text{'ca_city'}</b></td>\n";
	print "<td><input name=cityName size=30></td> </tr>\n";

	print "<tr> <td><b>$webmin::text{'ca_sp'}</b></td>\n";
	print "<td><input name=stateOrProvinceName size=15></td> </tr>\n";

	print "<tr> <td><b>$webmin::text{'ca_c'}</b></td>\n";
	print "<td><input name=countryName size=2></td> </tr>\n";

	print "<tr> <td><b>$webmin::text{'ssl_size'}</b></td>\n";
	print "<td><input type=radio name=size_def value=1 checked> ",
	      "$text{'default'} ($default_key_size)\n";
	print "<input type=radio name=size_def value=0> ",
	      "$webmin::text{'ssl_custom'}\n";
	print "<input name=size size=6> $webmin::text{'ssl_bits'}</td> </tr>\n";

	print "<tr> <td><b>$webmin::text{'ssl_days'}</b></td>\n";
	print "<td><input name=days size=8 value='1825'></td> </tr>\n";

	print "<tr> <td><b>$webmin::text{'ssl_newfile'}</b></td>\n";
	printf "<td><input name=newfile size=40 value='%s'></td> </tr>\n",
		"$config{'usermin_dir'}/miniserv.pem";

	print "<tr> <td><b>$webmin::text{'ssl_usenew'}</b></td> <td>\n";
	print "<input type=radio name=usenew value=1 checked> $text{'yes'}\n";
	print "<input type=radio name=usenew value=0> $text{'no'}</td> </tr>\n";

	print "</table></td></tr></table>\n";
	print "<input type=submit value='$webmin::text{'ssl_create'}'></form>\n";
	}

&ui_print_footer("", $text{'index_return'});

