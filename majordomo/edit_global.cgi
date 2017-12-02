#!/usr/local/bin/perl
# edit_global.cgi
# Edit global majordomo options

require './majordomo-lib.pl';
&ReadParse();

$conf = &get_config();
%access = &get_module_acl();
$access{'global'} || &error($text{'global_ecannot'});
&ui_print_header(undef, $text{'global_title'}, "");

local $bcss=' style="display: box; float: left; padding: 10px;"';
print  "<div $bcss>".ui_form_start("check_inst.cgi", "post").
                        &ui_submit($text{'check_title'}).ui_form_end()."</div>";

print ui_form_start('save_global.cgi', 'post');
print ui_table_start(&text('global_header'), undef, 2);

$whereami = &find_value("whereami", $conf);
print ui_columns_row(["<b>$text{'global_whereami'}</b>", ui_textbox('whereami', $whereami, 40)], undef);

$whoami = &find_value("whoami", $conf);
print ui_columns_row(["<b>$text{'global_whoami'}</b>", ui_textbox('whoami', $whoami, 40)], undef);

$whoami_o = &find_value("whoami_owner", $conf);
print ui_columns_row(["<b>$text{'global_owner'}</b>", ui_textbox('whoami_owner', $whoami_o, 40)], undef);

$sendmail = &find_value("sendmail_command", $conf);
print ui_columns_row(["<b>$text{'global_sendmail'}</b>", ui_textbox('whoami_command', $sendmail, 40).
		&file_chooser_button("sendmail_command", 0)], undef);

print "<tr>\n";
print &multi_input("global_taboo_headers", $text{'access_theader'}, $conf);
print "</tr>\n";

print "<tr>\n";
print &multi_input("global_taboo_body", $text{'access_tbody'}, $conf);
print "</tr>\n";

print ui_table_span(ui_alert_box($text{'access_taboo'}, 'info'));

print ui_table_end();
print  &ui_submit($text{'save'}), ui_form_end();

&ui_print_footer("", $text{'index_return'});

