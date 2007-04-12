#!/usr/local/bin/perl
# edit_setup.cgi
# Display a form for setting up SpamAssassin, either locally or globally

require './spam-lib.pl';
&can_use_check("setup");
&ui_print_header(undef, $text{'setup_title'}, "");

&foreign_require("procmail", "procmail-lib.pl");
@pmrcs = &get_procmailrc();
$pmrc = $pmrcs[$#pmrcs];
if ($module_info{'usermin'}) {
	print &text('setup_desc_usermin', "<tt>$pmrc</tt>"),"<p>\n";
	}
else {
	print &text('setup_desc_webmin', "<tt>$pmrc</tt>"),"<p>\n";
	}

print "<form action=setup.cgi>\n";
print "<table>\n";

# Spam destination inputs
print "<tr> <td rowspan=6 valign=top><b>$text{'setup_to'}</b></td>\n";

print "<td><input type=radio name=to value=0> $text{'setup_null'}</td> </tr>\n";

print "<td><input type=radio name=to value=4> $text{'setup_default'}</td> </tr>\n";

print "<td><input type=radio name=to value=1 checked> $text{'setup_file'}</td>\n";
printf "<td><input name=file size=30 value='%s'></td> </tr>\n",
	$module_info{'usermin'} ? "mail/spam" : "\$HOME/spam";

print "<td><input type=radio name=to value=2> $text{'setup_maildir'}</td>\n";
print "<td><input name=maildir size=30></td> </tr>\n";

print "<td><input type=radio name=to value=3> $text{'setup_mhdir'}</td>\n";
print "<td><input name=mhdir size=30></td> </tr>\n";

print "<td><input type=radio name=to value=5> $text{'setup_email'}</td>\n";
print "<td><input name=email size=30></td> </tr>\n";

# Run mode input
if (!$module_info{'usermin'}) {
	print "<tr> <td valign=top><b>$text{'setup_drop'}</b></td> <td>\n";
	print "<input type=radio name=drop value=1 checked> ",
	      "$text{'setup_drop1'}\n";
	print "<input type=radio name=drop value=0> ",
	      "$text{'setup_drop0'}</td> </tr>\n";
	}

print "</td></tr></table><br>\n";

if ($module_info{'usermin'}) {
	print "$text{'setup_rel'}<p>\n";
	}
else {
	print "$text{'setup_home'}<p>\n";
	}
print "$text{'setup_head'}<p>\n";

print "<input type=submit value='$text{'setup_ok'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

