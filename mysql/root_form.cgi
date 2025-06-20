#!/usr/local/bin/perl
# Show a form for changing the MySQL root password

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} == 1 || &error($text{'perms_ecannot'});
&ui_print_header(undef, $text{'root_title'}, "");

$mode = &mysql_login_type($mysql_login || 'root');
if ($mode eq 'socket') {
	print &ui_alert_box(&text('root_socket', $mysql_login), 'warn');
	}
else {
	print &ui_form_start("save_root.cgi", "post");
	print &ui_table_start($text{'root_header'}, undef, 2);

	print &ui_table_row($text{'root_user'},
		$mysql_login ? "<tt>$mysql_login</tt>"
			     : "<label>$text{'root_auto'}</label>");
	print &ui_table_row($text{'root_pass'},
		$mysql_pass ? "<tt>".&ui_text_mask($mysql_pass)."</tt>"
			    : &ui_text_color($text{'root_none'}, 'danger'));
	print &ui_table_row($text{'root_newpass1'},
		&ui_password("newpass1", undef, 20));
	print &ui_table_row($text{'root_newpass2'},
		&ui_password("newpass2", undef, 20));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'root_ok'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});
