#!/usr/local/bin/perl
# Display a page for authentication options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-client-lib.pl';
our (%text);
my $conf = &get_iscsi_config();

&ui_print_header(undef, $text{'auth_title'}, "");

print &ui_form_start("save_auth.cgi", "post");
print &ui_table_start($text{'auth_header'}, undef, 2);

# Initiator name
print &ui_table_row($text{'auth_name'},
	&ui_textbox("name", &get_initiator_name(), 40)." ".
	&ui_checkbox("newname", 1, $text{'auth_newname'}, 0,
		     "onChange='form.name.disabled = checked'"));

# Authentication method
my $method = &find_value($conf, "node.session.auth.authmethod");
print &ui_table_row($text{'auth_method'},
	&ui_select("method", $method || "None",
		   [ [ "None", $text{'auth_method_none'} ],
		     [ "CHAP" ] ], 1, 0, 1));

# Login and password to iSCSI server
my $username = &find_value($conf, "node.session.auth.username");
my $password = &find_value($conf, "node.session.auth.password");
print &ui_table_row($text{'auth_userpass'},
	&ui_radio("username_def", $username ? 0 : 1,
		  [ [ 1, $text{'auth_userpass_def'} ],
		    [ 0, $text{'auth_userpass_user'} ] ])." ".
	&ui_textbox("username", $username, 20)." ".
	$text{'auth_userpass_pass'}." ".
	&ui_textbox("password", $password, 20));

# Login and password by the iSCSI server to the client
my $username_in = &find_value($conf, "node.session.auth.username_in");
my $password_in = &find_value($conf, "node.session.auth.password_in");
print &ui_table_row($text{'auth_userpass_in'},
	&ui_radio("username_in_def", $username_in ? 0 : 1,
		  [ [ 1, $text{'auth_userpass_def'} ],
		    [ 0, $text{'auth_userpass_user'} ] ])." ".
	&ui_textbox("username_in", $username_in, 20)." ".
	$text{'auth_userpass_pass'}." ".
	&ui_textbox("password_in", $password_in, 20));

print &ui_table_hr();

# Discovery uthentication method
my $dmethod = &find_value($conf, "discovery.sendtargets.auth.authmethod");
print &ui_table_row($text{'auth_dmethod'},
	&ui_select("dmethod", $dmethod || "None",
		   [ [ "None", $text{'auth_method_none'} ],
		     [ "CHAP" ] ], 1, 0, 1));

# Login and password to iSCSI server
my $dusername = &find_value($conf, "discovery.sendtargets.auth.username");
my $dpassword = &find_value($conf, "discovery.sendtargets.auth.password");
print &ui_table_row($text{'auth_duserpass'},
	&ui_radio("dusername_def", $dusername ? 0 : 1,
		  [ [ 1, $text{'auth_userpass_def'} ],
		    [ 0, $text{'auth_userpass_user'} ] ])." ".
	&ui_textbox("dusername", $dusername, 20)." ".
	$text{'auth_userpass_pass'}." ".
	&ui_textbox("dpassword", $dpassword, 20));

# Login and password by the iSCSI server to the client
my $dusername_in = &find_value($conf, "discovery.sendtargets.auth.username_in");
my $dpassword_in = &find_value($conf, "discovery.sendtargets.auth.password_in");
print &ui_table_row($text{'auth_duserpass_in'},
	&ui_radio("dusername_in_def", $dusername_in ? 0 : 1,
		  [ [ 1, $text{'auth_userpass_def'} ],
		    [ 0, $text{'auth_userpass_user'} ] ])." ".
	&ui_textbox("dusername_in", $dusername_in, 20)." ".
	$text{'auth_userpass_pass'}." ".
	&ui_textbox("dpassword_in", $dpassword_in, 20));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


