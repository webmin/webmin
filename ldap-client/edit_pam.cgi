#!/usr/local/bin/perl
# Show a form for editing the LDAP PAM options

require './ldap-client-lib.pl';
&ui_print_header(undef, $text{'pam_title'}, "", "pam");

$conf = &get_config();
print &ui_form_start("save_pam.cgi", "post");
print &ui_table_start($text{'pam_header'}, "width=100%", 2);

print &ui_table_row($text{'pam_filter'},
	&ui_opt_textbox("filter", &find_svalue("pam_filter", $conf),
			30, $text{'pam_none'}));

print &ui_table_row($text{'pam_login'},
	&ui_opt_textbox("login", &find_svalue("pam_login_attribute", $conf),
			20, $text{'default'}." (<tt>uid</tt>)"));

print &ui_table_row($text{'pam_groupdn'},
	&ui_opt_textbox("groupdn", &find_svalue("pam_groupdn", $conf),
			30, $text{'pam_ignored'})." ".
	&base_chooser_button("groupdn", 1));

print &ui_table_row($text{'pam_member'},
	&ui_opt_textbox("member", &find_svalue("pam_member_attribute", $conf),
			30, $text{'default'}));

print &ui_table_row($text{'pam_password'},
	&ui_select("password", &find_svalue("pam_password", $conf),
		   [ [ "", $text{'default'} ],
		     [ "clear", $text{'pam_clear'} ],
		     [ "crypt", $text{'pam_crypt'} ],
		     [ "md5", $text{'pam_md5'} ],
		     [ "nds", $text{'pam_nds'} ],
		     [ "ad", $text{'pam_ad'} ],
		     [ "exop", $text{'pam_exop'} ] ],
		    1, 0, 1));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


