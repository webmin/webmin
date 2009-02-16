#!/usr/local/bin/perl
# edit_sync.cgi
# Display options for the automatic setting up of SSH for new users

require './sshd-lib.pl';
&ui_print_header(undef, $text{'sync_title'}, "");

print "$text{'sync_desc'}<p>\n";
print &ui_form_start("save_sync.cgi");
print &ui_table_start(undef, 2, 2);

# Create keys for new users
print &ui_table_row($text{'sync_create'},
	&ui_yesno_radio("create", $config{'sync_create'}));

# Authorize own key
print &ui_table_row($text{'sync_auth'},
	&ui_yesno_radio("auth", $config{'sync_auth'}));

# Use password as passphrase
print &ui_table_row($text{'sync_pass'},
	&ui_yesno_radio("pass", $config{'sync_pass'}));

# Key type
print &ui_table_row($text{'sync_type'},
      &ui_select("type", $config{'sync_type'},
		 [ [ "", $text{'sync_auto'} ],
		   [ "rsa" ], [ "dsa" ], [ "rsa1" ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

