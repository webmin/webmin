#!/usr/local/bin/perl
# edit_lang.cgi
# Language config form

require './usermin-lib.pl';
$access{'lang'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'lang_title'}, "");

&get_usermin_config(\%uconfig);
print $text{'lang_intro'},"<p>\n";

print &ui_form_start("change_lang.cgi", "post");
print &ui_table_start($text{'lang_title2'}, undef, 2);

# Language
$clang = $uconfig{'lang'} ? safe_language($uconfig{'lang'}) : $default_lang;
print &ui_table_row($text{'lang_lang'},
        &ui_select("lang", $clang,
           [ map { [ $_->{'lang'}, &html_escape($_->{'desc'}) ] }
                 &list_languages() ]));

# Old datetime format or a new locale
eval "use DateTime; use DateTime::Locale; use DateTime::TimeZone;";
if (!$@ && $] > 5.011) {
        my $locales = &list_locales();
        my %localesrev = reverse %{$locales};
        my $locale_auto = &parse_accepted_language(\%uconfig);
        print &ui_table_row($text{'lang_locale'},
                &ui_select("locale", $locale_auto || $uconfig{'locale'} || &get_default_system_locale(),
                           [ map { [ $localesrev{$_}, $_ ] } sort values %{$locales} ]).
                           &ui_hidden("dateformat", $uconfig{'dateformat'}));
        }

else {
        print &ui_table_row($text{'lang_dateformat'},
                &ui_select("dateformat", $uconfig{'dateformat'} || "dd/mon/yyyy",
                           [ map { [ $_, $text{'lang_dateformat_'.$_} ] }
                           @webmin::webmin_date_formats ]).
                           &ui_hidden("locale", $uconfig{'locale'}));
        }

# Use language from browser?
print &ui_table_row($text{'lang_accept'},
        &ui_yesno_radio("acceptlang", int($uconfig{'acceptlang'})));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'lang_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

