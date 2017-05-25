#!/usr/local/bin/perl
# edit_lang.cgi
# Language config form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'lang_title'}, "");

print $text{'lang_intro'},"<p>\n";

print &ui_form_start("change_lang.cgi", "post");
print &ui_table_start($text{'lang_title2'}, undef, 2, [ "width=40%" ]);

# Language
$clang = $gconfig{'lang'} ? $gconfig{'lang'} : $default_lang;
print &ui_table_row($text{'lang_lang'},
	&ui_select("lang", $clang,
	   [ map { [ $_->{'lang'}, "$_->{'desc'} (".uc($_->{'lang'}).")" ] }
		 &list_languages($clang) ]));

# Character set
print &ui_table_row($text{'lang_charset'},
	&ui_opt_textbox("charset", $gconfig{'charset'}, 15,
			$text{'lang_chardef'}));

# Use language from browser?
print &ui_table_row($text{'lang_accept'},
	&ui_yesno_radio("acceptlang", int($gconfig{'acceptlang'})));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'lang_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

