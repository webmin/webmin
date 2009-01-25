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

print &ui_form_start("setup.cgi", "post");
print &ui_table_start(undef, undef, 2);
print $form_hiddens;

# Spam destination inputs
$mbox = $module_info{'usermin'} ? "mail/spam" : "\$HOME/spam";
print &ui_table_row($text{'setup_to'},
	&ui_radio_table("to", 1,
	  [ [ 0, $text{'setup_null'} ],
	    [ 4, $text{'setup_default'} ],
	    [ 1, $text{'setup_file'},
		 &ui_textbox("mbox", $mbox, 40) ],
	    [ 2, $text{'setup_maildir'},
		 &ui_textbox("maildir", "", 40) ],
	    [ 3, $text{'setup_mhdir'},
		 &ui_textbox("mhdir", "", 40) ],
	    [ 5, $text{'setup_email'},
		 &ui_textbox("email", "", 40) ] ]));

# Run mode input
if (!$module_info{'usermin'}) {
	print &ui_table_row($text{'setup_drop'},
		&ui_radio("drop", 1, [ [ 1, $text{'setup_drop1'} ],
				       [ 0, $text{'setup_drop0'} ] ]));
	}

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
print &ui_form_end([ [ undef, $text{'setup_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

