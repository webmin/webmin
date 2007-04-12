#!/usr/local/bin/perl
# edit_ca.cgi
# Display the current CA or a form for creating one

require './webmin-lib.pl';
&ui_print_header(undef, $text{'ca_title'}, "");
&get_miniserv_config(\%miniserv);

%aclconfig = &foreign_config("acl");
&foreign_require("acl", "acl-lib.pl");
if (!$ENV{"MINISERV_CONFIG"}) {
	print "<p>$text{'ca_eminiserv'}<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
elsif (uc($ENV{'HTTPS'}) ne 'ON') {
	print "<p>$text{'ca_essl'}<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
elsif (!defined(&Net::SSLeay::X509_STORE_CTX_get_current_cert) ||
       !defined(&Net::SSLeay::CTX_load_verify_locations) ||
       !defined(&Net::SSLeay::CTX_set_verify)) {
	print "<p>$text{'ca_eversion'}<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
elsif (!&acl::get_ssleay()) {
	print "<p>",&text('ca_essleay',
			  "<tt>$aclconfig{'ssleay'}</tt>"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print -r $miniserv{'ca'} ? $text{'ca_newmsg1'} : $text{'ca_newmsg1'},"<p>\n";
print "<form action=setup_ca.cgi><table border>\n";
print "<tr $tb> <td><b>$text{'ca_header1'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td><b>$text{'ca_cn'}</b></td>\n";
print "<td><input name=commonName size=30></td> </tr>\n";

print "<tr> <td><b>$text{'ca_email'}</b></td>\n";
print "<td><input name=emailAddress size=30></td> </tr>\n";

print "<tr> <td><b>$text{'ca_ou'}</b></td>\n";
print "<td><input name=organizationalUnitName size=30></td> </tr>\n";

print "<tr> <td><b>$text{'ca_o'}</b></td>\n";
print "<td><input name=organizationName size=30></td> </tr>\n";

print "<tr> <td><b>$text{'ca_sp'}</b></td>\n";
print "<td><input name=stateOrProvinceName size=15></td> </tr>\n";

print "<tr> <td><b>$text{'ca_c'}</b></td>\n";
print "<td><input name=countryName size=2></td> </tr>\n";

print "<tr> <td><b>$text{'ssl_size'}</b></td>\n";
print "<td><input type=radio name=size_def value=1 checked> ",
      "$text{'default'} ($default_key_size)\n";
print "<input type=radio name=size_def value=0> ",
      "$text{'ssl_custom'}\n";
print "<input name=size size=6> $text{'ssl_bits'}</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'ca_create'}'></form>\n";

print "<hr>\n";
print -r $miniserv{'ca'} ? $text{'ca_oldmsg1'} : $text{'ca_oldmsg2'},"<p>\n";
print "<form action=change_ca.cgi method=post enctype=multipart/form-data>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'ca_header2'}</b></td> </tr>\n";
print "<tr $cb> <td><textarea rows=20 cols=70 name=cert>";
if ($miniserv{'ca'}) {
	open(CA, $miniserv{'ca'});
	while(<CA>) { print; }
	close(CA);
	}
print "</textarea></td> </tr>\n";
print "</table><input type=submit value='$text{'save'}'></form>\n";

if (-r $miniserv{'ca'}) {
	print "<hr>\n";
	print "<form action=stop_ca.cgi><table><tr>\n";
	print "<td><input type=submit value='$text{'ca_stop'}'></td>\n";
	print "<td>$text{'ca_stopmsg'}</td>\n";
	print "</tr></table></form>\n";
	}

&ui_print_footer("", $text{'index_return'});

