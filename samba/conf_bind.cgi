#!/usr/local/bin/perl
# conf_bind.cgi
# Display winbind-related options

require './samba-lib.pl';

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcm'}") unless $access{'conf_bind'};

&ui_print_header(undef, $text{'bind_title'}, "");

&get_share("global");

print &ui_form_start("save_bind.cgi", "post");
print &ui_table_start($text{'bind_title'}, undef, 2);

print &ui_table_row($text{'bind_local'},
	&yesno_input("winbind enable local accounts", "local"));

print &ui_table_row($text{'bind_trust'},
	&yesno_input("winbind trusted domains only", "trust"));

print &ui_table_row($text{'bind_users'},
	&yesno_input("winbind enum users", "users"));

print &ui_table_row($text{'bind_groups'},
	&yesno_input("winbind enum groups", "groups"));

print &ui_table_row($text{'bind_defaultdomain'},
	&yesno_input("winbind use default domain", "defaultdomain"));

print &ui_table_row($text{'bind_realm'},
	&ui_textbox("realm", &getval("realm"), 20));

print &ui_table_row($text{'bind_cache'},
	&ui_textbox("cache", &getval("winbind cache time"), 20));

print &ui_table_row($text{'bind_uid'},
	&ui_textbox("uid", &getval("idmap uid"), 20));

print &ui_table_row($text{'bind_gid'},
	&ui_textbox("gid", &getval("idmap gid"), 20));

$backend = &getval("idmap backend");
print &ui_table_row($text{'bind_backend'},
	&ui_radio("backend_def", $backend ? 0 : 1,
		  [ [ 1, $text{'default'} ],
		    [ 0, &ui_textbox("backend", $backend, 50) ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_sharelist'});


