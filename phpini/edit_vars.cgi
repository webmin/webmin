#!/usr/local/bin/perl
# Show options related to PHP variables

require './phpini-lib.pl';
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$conf = &get_config_as_user($in{'file'});

&ui_print_header("<tt>$in{'file'}</tt>", $text{'vars_title'}, "");

print &ui_form_start("save_vars.cgi", "post");
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_table_start($text{'vars_header'}, "width=100%", 4);

print &ui_table_row($text{'vars_magic'},
		    &onoff_radio("magic_quotes_gpc"));

print &ui_table_row($text{'vars_runtime'},
		    &onoff_radio("magic_quotes_runtime"));

print &ui_table_row($text{'vars_register'},
		    &onoff_radio("register_globals"));

print &ui_table_row($text{'vars_long'},
		    &onoff_radio("register_long_arrays"));

print &ui_table_row($text{'vars_args'},
		    &onoff_radio("register_argc_argv"));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("list_ini.cgi?file=".&urlize($in{'file'}),
		 $text{'list_return'});
