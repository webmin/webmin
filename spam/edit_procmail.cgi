#!/usr/local/bin/perl
# Allow changing of the rule for delivering spam

require './spam-lib.pl';
&can_use_check("procmail");
&ui_print_header(undef, $text{'procmail_title'}, "");

print &text('procmail_desc', "<tt>$pmrc</tt>"),"<p>\n";

# Find the existing recipe
&foreign_require("procmail", "procmail-lib.pl");
@pmrcs = &get_procmailrc();
$pmrc = $pmrcs[$#pmrcs];
@recipes = &procmail::parse_procmail_file($pmrc);
$spamrec = &find_file_recipe(\@recipes);

if (!$spamrec) {
	$mode = 4;
	}
elsif ($spamrec->{'action'} eq "/dev/null") {
	$mode = 0;
	}
elsif ($spamrec->{'action'} =~ /^(.*)\/$/) {
	$mode = 2;
	$file = $1;
	}
elsif ($spamrec->{'action'} =~ /^(.*)\/\.$/) {
	$mode = 3;
	$file = $1;
	}
elsif ($spamrec->{'type'} eq '!') {
	$mode = 5;
	$email = $spamrec->{'action'};
	}
else {
	$mode = 1;
	$file = $spamrec->{'action'};
	}

print "<form action=save_procmail.cgi>\n";
print "<table>\n";

# Spam destination inputs
print "<tr> <td rowspan=6 valign=top><b>$text{'setup_to'}</b></td>\n";

printf "<td><input type=radio name=to value=0 %s> %s</td> </tr>\n",
	$mode == 0 ? "checked" : "", $text{'setup_null'};

printf "<td><input type=radio name=to value=4 %s> %s</td> </tr>\n",
	$mode == 4 ? "checked" : "", $text{'setup_default'};

printf "<td><input type=radio name=to value=1 %s> %s</td>\n",
	$mode == 1 ? "checked" : "", $text{'setup_file'};
printf "<td><input name=file size=30 value='%s'></td> </tr>\n",
	$mode == 1 ? $file : undef;

printf "<td><input type=radio name=to value=2 %s> %s</td>\n",
	$mode == 2 ? "checked" : "", $text{'setup_maildir'};
printf "<td><input name=maildir size=30 value='%s'></td> </tr>\n",
	$mode == 2 ? $file : undef;

printf "<td><input type=radio name=to value=3 %s> %s</td>\n",
	$mode == 3 ? "checked" : "", $text{'setup_mhdir'};
printf "<td><input name=mhdir size=30 value='%s'></td> </tr>\n",
	$mode == 3 ? $file : undef;

printf "<td><input type=radio name=to value=5 %s> %s</td>\n",
	$mode == 5 ? "checked" : "", $text{'setup_email'};
printf "<td><input name=email size=30 value='%s'></td> </tr>\n",
	$mode == 5 ? $email : undef;

print "</td></tr></table><br>\n";

if ($module_info{'usermin'}) {
	print "$text{'setup_rel'}<p>\n";
	}
else {
	print "$text{'setup_home'}<p>\n";
	}
print "$text{'setup_head'}<p>\n";

print "<input type=submit value='$text{'procmail_ok'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

