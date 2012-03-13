#!/usr/local/bin/perl
# Show options for report colour styling

require './sarg-lib.pl';

$conf = &get_config();
&ui_print_header(undef, $text{'style_title'}, "");
print &ui_form_start("save_style.cgi", "post");
print &ui_table_start($text{'style_header'}, "width=100%", 4);
$config_prefix = "style_";

if (&get_sarg_version() < 2.3) {
	print &config_language($conf, "language", 3,
			       "$module_root_directory/languages");
	print &config_language($conf, "charset", 3,
			       "$module_root_directory/charsets");
	print &ui_table_hr();
	}

print &config_opt_textbox($conf, "title", 40, 3);
print &config_opt_textbox($conf, "title_color", 20, 3);
print &config_opt_textbox($conf, "font_face", 20, 3);
print &config_opt_textbox($conf, "header_color", 20, 3);
print &config_opt_textbox($conf, "header_bgcolor", 20, 3);
print &config_opt_textbox($conf, "header_font_size", 10, 3);
print &config_opt_textbox($conf, "text_color", 20, 3);
print &config_opt_textbox($conf, "text_bgcolor", 20, 3);

print &ui_table_hr();

print &config_opt_textbox($conf, "logo_image", 40, 3,
			  $text{'style_none'});
print &config_opt_textbox($conf, "image_size", 10, 3);	# XXX two numbers!
print &config_opt_textbox($conf, "logo_text", 40, 3);
print &config_opt_textbox($conf, "logo_text_color", 40, 3);

print &ui_table_hr();

print &config_opt_textbox($conf, "background_image", 40, 3,
			  $text{'style_none'});
print &config_opt_textbox($conf, "background_color", 20, 3);

print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'save'} ] ], "100%");
&ui_print_footer("", $text{'index_return'});
