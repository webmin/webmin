#!/usr/local/bin/perl
# cert_form.cgi

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access);
&ui_print_header(undef, $text{'cert_title'}, "", undef, undef, undef, undef,
		 undef, undef, "language=VBSCRIPT onload='postLoad()'");
eval "use Net::SSLeay";

print "<p>$text{'cert_msg'}<p>\n";
if ($ENV{'SSL_USER'}) {
	print &text('cert_already', "<tt>$ENV{'SSL_USER'}</tt>"),
	      "<p>\n";
	}

if ($ENV{'HTTP_USER_AGENT'} =~ /Mozilla/i) {
	# Output a form that works for netscape and mozilla
	print &ui_form_start("cert_issue.cgi", "post");
	print &ui_table_start($text{'cert_header'}, undef, 2);

	print &ui_table_row($text{'cert_cn'},
		&ui_textbox("commonName", undef, 30));

	print &ui_table_row($text{'cert_email'},
		&ui_textbox("emailAddress", undef, 30));

	print &ui_table_row($text{'cert_ou'},
		&ui_textbox("organizationalUnitName", undef, 30));

	print &ui_table_row($text{'cert_o'},
		&ui_textbox("organizationName", undef, 30));

	print &ui_table_row($text{'cert_sp'},
		&ui_textbox("stateOrProvinceName", undef, 30));

	print &ui_table_row($text{'cert_c'},
		&ui_textbox("countryName", undef, 30));

	print &ui_table_row($text{'cert_key'},
		"<keygen name=key>");

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'cert_issue'} ] ]);
	}
else {
	# Unsupported browser!
	print "<p><b>",&text('cert_ebrowser',
			     "<tt>$ENV{'HTTP_USER_AGENT'}</tt>"),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

