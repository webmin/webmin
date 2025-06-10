#!/usr/local/bin/perl
# Save options for report colour styling

require './sarg-lib.pl';
&ReadParse();
$conf = &get_config();
$config_prefix = "style_";
&error_setup($text{'style_err'});

&lock_sarg_files();
if (&get_sarg_version() < 2.3) {
	&save_language($conf, "language");
	&save_language($conf, "charset");
	}
&save_opt_textbox($conf, "title", \&check_title);
&save_opt_textbox($conf, "title_color", \&check_colour);
&save_opt_textbox($conf, "font_face", \&check_font);
&save_opt_textbox($conf, "header_color", \&check_colour);
&save_opt_textbox($conf, "header_bgcolor", \&check_colour);
&save_opt_textbox($conf, "header_font_size", \&check_fontsize);
&save_opt_textbox($conf, "text_color", \&check_colour);
&save_opt_textbox($conf, "text_bgcolor", \&check_colour);

&save_opt_textbox($conf, "logo_image");
&save_opt_textbox($conf, "image_size", \&check_size);
&save_opt_textbox($conf, "logo_text");
&save_opt_textbox($conf, "logo_text_color", \&check_colour);

&save_opt_textbox($conf, "background_image");
&save_opt_textbox($conf, "background_color", \&check_colour);

&flush_file_lines();
&unlock_sarg_files();
&webmin_log("style");
&redirect("");

sub check_title
{
return $_[0] =~ /\S/ ? undef : $text{'style_etitle'};
}

sub check_colour
{
return $_[0] =~ /^\S+$/ ? undef : $text{'style_ecolour'};
}

sub check_font
{
return $_[0] =~ /^\S+$/ ? undef : $text{'style_efont'};
}

sub check_fontsize
{
return $_[0] =~ /^\-?\d+$/ ? undef : $text{'style_efontsize'};
}

sub check_size
{
return $_[0] =~ /^\d+\s+\d+$/ ? undef : $text{'style_esize'};
}

