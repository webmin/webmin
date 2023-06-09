#!/usr/local/bin/perl
# edit_lang.cgi
# Language config form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'lang_title'}, "");

print $text{'lang_intro'},"<p>\n";

print &ui_form_start("change_lang.cgi", "post");
print &ui_table_start($text{'lang_title2'}, undef, 2, [ "width=40%" ]);

# Language
$clang = $gconfig{'lang'} ? safe_language($gconfig{'lang'}) : $default_lang;
my ($linfo) = grep { $_->{'lang'} eq $clang } &list_languages();
my $clangauto = defined($gconfig{'langauto'}) ? $gconfig{'langauto'} : $linfo->{'auto'};
print &ui_table_row($text{'lang_lang'},
	&ui_select("lang", $clang,
	   [ map { [ $_->{'lang'}, "$_->{'desc'}" ] }
		 &list_languages() ])." ". 
	&ui_checkbox("langauto", 1, $text{'langauto_include'}, $clangauto));

# Old datetime format or a new locale
eval "use DateTime; use DateTime::Locale; use DateTime::TimeZone;";
if (!$@ && $] > 5.011) {
	my $locales = &list_locales();
	my %localesrev = reverse %{$locales};
	my $locale_auto = &parse_accepted_language();
	print &ui_table_row($text{'lang_locale'},
		&ui_select("locale", $locale_auto || $gconfig{'locale'} || &get_default_system_locale(),
			   [ map { [ $localesrev{$_}, $_ ] } sort values %{$locales} ]).
			   &ui_hidden("dateformat", $gconfig{'dateformat'}), 
			   undef, [ "valign=middle","valign=middle" ]);
	}
else {
	print &ui_table_row($text{'lang_dateformat'},
		&ui_select("dateformat", $gconfig{'dateformat'} || "dd/mon/yyyy",
			   [ map { [ $_, $text{'lang_dateformat_'.$_} ] }
			   @webmin_date_formats ]).
			   &ui_hidden("locale", $gconfig{'locale'}),
			   undef, [ "valign=middle","valign=middle" ]);
	}

# Use language from browser?
print &ui_table_row($text{'lang_accept'},
	&ui_yesno_radio("acceptlang", int($gconfig{'acceptlang'})));


print &ui_table_end();
print &ui_form_end([ [ "", $text{'lang_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

