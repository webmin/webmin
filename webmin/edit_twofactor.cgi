#!/usr/local/bin/perl
# Show two-factor authentication options

require './webmin-lib.pl';
ui_print_header(undef, $text{'twofactor_title'}, "");
get_miniserv_config(\%miniserv);

print "$text{'twofactor_desc'}<p>\n";

print ui_form_start("change_twofactor.cgi", "post");
print ui_table_start($text{'twofactor_header'}, undef, 2);

# Two-factor provider
print ui_table_row($text{'twofactor_provider'},
	ui_select("twofactor_provider", $miniserv{'twofactor_provider'},
		  [ [ "", "&lt;".$text{'twofactor_none'}."&gt;" ],
		    map { [ $_->[0], $_->[1]." - ".$_->[2] ] }
			&list_twofactor_providers() ]));

# API key
print ui_table_row($text{'twofactor_apikey'},
	ui_textbox("twofactor_apikey", $miniserv{'twofactor_apikey'}, 40));

print ui_table_end();
print ui_form_end([ [ "save", $text{'save'} ] ]);

ui_print_footer("", $text{'index_return'});

