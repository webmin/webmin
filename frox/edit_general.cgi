#!/usr/local/bin/perl
# Show general options

require './frox-lib.pl';
&ui_print_header(undef, $text{'general_title'}, "");
$conf = &get_config();

print &ui_form_start("save_general.cgi", "post");
print &ui_table_start($text{'general_header'}, "width=100%", 4);

print &config_user($conf, "User");

print &config_group($conf, "Group");

print &config_textbox($conf, "WorkingDir", 30, 3);

print &config_yesno($conf, "DontChroot", $text{'no'}, $text{'yes'}, "no");

print &config_opt_textbox($conf, "LogLevel", 4);

print &config_opt_textbox($conf, "PidFile", 30, 3, $text{'general_nowhere'});

print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'save'} ] ], "100%");

&ui_print_footer("", $text{'index_return'});

