#!/usr/local/bin/perl
# cert_form.cgi

require './acl-lib.pl';
&ui_print_header(undef, $text{'cert_title'}, "", undef, undef, undef, undef, undef, undef,
	"language=VBSCRIPT onload='postLoad()'");
eval "use Net::SSLeay";

print "<p>$text{'cert_msg'}<p>\n";
if ($ENV{'SSL_USER'}) {
	print &text('cert_already', "<tt>$ENV{'SSL_USER'}</tt>"),
	      "<p>\n";
	}

if ($ENV{'HTTP_USER_AGENT'} =~ /Mozilla/i) {
	# Output a form that works for netscape and mozilla
	print "<form action=cert_issue.cgi>\n";
	print "<table border>\n";
	print "<tr $tb> <td><b>$text{'cert_header'}</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";

	print "<tr> <td><b>$text{'cert_cn'}</b></td>\n";
	print "<td><input name=commonName size=30></td> </tr>\n";

	print "<tr> <td><b>$text{'cert_email'}</b></td>\n";
	print "<td><input name=emailAddress size=30></td> </tr>\n";

	print "<tr> <td><b>$text{'cert_ou'}</b></td>\n";
	print "<td><input name=organizationalUnitName size=30></td> </tr>\n";

	print "<tr> <td><b>$text{'cert_o'}</b></td>\n";
	print "<td><input name=organizationName size=30></td> </tr>\n";

	print "<tr> <td><b>$text{'cert_sp'}</b></td>\n";
	print "<td><input name=stateOrProvinceName size=15></td> </tr>\n";

	print "<tr> <td><b>$text{'cert_c'}</b></td>\n";
	print "<td><input name=countryName size=2></td> </tr>\n";

	print "<tr> <td><b>$text{'cert_key'}</b></td>\n";
	print "<td><keygen name=key></td> </tr>\n";

	print "</table></td></tr></table>\n";
	print "<input type=submit value='$text{'cert_issue'}'>\n";
	print "</form>\n";
	}
else {
	# Unsupported browser!
	print "<p><b>",&text('cert_ebrowser',
			     "<tt>$ENV{'HTTP_USER_AGENT'}</tt>"),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

