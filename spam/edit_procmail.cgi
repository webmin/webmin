#!/usr/local/bin/perl
# Allow changing of the rule for delivering spam

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
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
elsif ($spamrec->{'action'} eq "\$DEFAULT") {
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

print &ui_form_start("save_procmail.cgi", "post");
print &ui_table_start(undef, undef, 2);
print $form_hiddens;

# Spam destination inputs
print &ui_table_row($text{'setup_to'},
	&ui_radio_table("to", $mode,
	  [ [ 0, $text{'setup_null'} ],
	    [ 4, $text{'setup_default'} ],
	    [ 1, $text{'setup_file'},
		 &ui_textbox("mbox", $mode == 1 ? $file : "", 40) ],
	    [ 2, $text{'setup_maildir'},
		 &ui_textbox("maildir", $mode == 2 ? $file : "", 40) ],
	    [ 3, $text{'setup_mhdir'},
		 &ui_textbox("mhdir", $mode == 3 ? $file : "", 40) ],
	    [ 5, $text{'setup_email'},
		 &ui_textbox("email", $mode == 5 ? $email : "", 40) ] ]));

# Message about path
if ($module_info{'usermin'}) {
	$msg = "$text{'setup_rel'}<p>\n";
	}
else {
	$msg = "$text{'setup_home'}<p>\n";
	}
$msg .= "$text{'setup_head'}<p>\n";
print &ui_table_row(undef, $msg, 2);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'procmail_ok'} ] ]);

&ui_print_footer($redirect_url, $text{'index_return'});

