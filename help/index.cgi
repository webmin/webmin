#!/usr/local/bin/perl
# index.cgi
# Display the help search form

require './help-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 0, 1);
my @list_modules;
foreach $m (&list_modules()) {
    push(@list_modules, [ $m->[0], $m->[1]->{'desc'} ]);
}

print &ui_form_start("search.cgi", "post");
print &ui_table_start($text{'index_header'}, undef, 2);
print &ui_table_row($text{'index_terms'},
	&ui_textbox("terms", undef, 50));
print &ui_table_row($text{'index_mods'}, 
        &ui_radio("all", 1,
		[ [ 1, $text{'index_all'} ],
		[ 0, $text{'index_sel'} ] ])."<br>\n".
        &ui_select("mods", undef, \@list_modules, 5, 1));
print ui_table_end();
print &ui_form_end([ [ undef, $text{'index_search'} ] ]);

&ui_print_footer("/", $text{'index'});

