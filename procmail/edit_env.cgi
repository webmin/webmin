#!/usr/local/bin/perl
# edit_env.cgi
# Edit an environment variable setting

require './procmail-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'env_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'env_title2'}, "");
	@conf = &get_procmailrc();
	$env = $conf[$in{'idx'}];
	}

print &ui_form_start("save_env.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'env_header'}, "width=100%", 2);

# Variable name
print &ui_table_row($text{'env_name'},
	&ui_textbox("name", $env->{'name'}, 60));

# Value or values
print &ui_table_row($text{'env_value'},
	$env->{'value'} =~ /\n/ ? &ui_textarea("value", $env->{'value'}, 4, 60)
				: &ui_textbox("value", $env->{'value'}, 60));

# Show save buttons
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

