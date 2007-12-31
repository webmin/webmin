#!/usr/local/bin/perl
# index_run.cgi
# Allows running of a new command

require './proc-lib.pl';
if (!$access{'run'}) {
	&redirect("index_tree.cgi");
	}
use Config;
&ui_print_header(undef, $text{'index_title'}, "", "run", !$no_module_config, 1);
&ReadParse();
&index_links("run");

print &ui_form_start("run.cgi", "post");
print &ui_table_start(undef, undef, 2);

# Command to run
print &ui_table_row(&hlink($text{'run_command'}, "cmd"),
	&ui_textbox("cmd", undef, 60)." ".
	&ui_submit($text{'run_submit'}));

# Foreground mode
print &ui_table_row(&hlink($text{'run_mode'}, "mode"),
	&ui_radio("mode", 0, [ [ 1, $text{'run_bg'} ],
			       [ 0, $text{'run_fg'} ] ]));

# Run as user
if (&supports_users()) {
	if ($< == 0) {
		print &ui_table_row(&hlink($text{'run_as'}, "runas"),
			&ui_user_textbox("user", $default_run_user));
		}
	else {
		print &ui_hidden("user", $remote_user),"\n";
		}
	}

# Input to command
print &ui_table_row(&hlink($text{'run_input'}, "input"),
	&ui_textarea("input", undef, 5, 60));
print &ui_table_end();
print &ui_form_end();

&ui_print_footer("/", $text{'index'});
