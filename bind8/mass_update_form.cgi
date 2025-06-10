#!/usr/local/bin/perl
# Show a form for changing the IPs in multiple zones

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'umass_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'umass_enone'});

&ui_print_header(undef, $text{'umass_title'}, "");

print &ui_form_start("mass_update.cgi", "post");
foreach $d (@d) {
	print &ui_hidden("d", $d),"\n";
	$dc++;
	}
print &ui_table_start($text{'umass_header'}, undef, 2);

# Number of domains selected
print &ui_table_row($text{'umass_sel'}, $dc);

# Type to change
@rtypes = ( 'ttl', 'A', 'CNAME', 'NS', 'MX', 'PTR', 'TXT', 'SPF',
	    $config{'support_aaaa'} ? ( "AAAA" ) : ( ) );
print &ui_table_row($text{'umass_type'},
	&ui_select("type", "A",
		   [ map { [ $_, $text{'recs_'.$_} ] } @rtypes ]));

# Value to change
print &ui_table_row($text{'umass_old'},
		    &ui_opt_textbox("old", undef, 30, $text{'umass_any'}));

# New value
print &ui_table_row($text{'umass_new'},
		    &ui_textbox("new", undef, 30));

print &ui_table_end();
print &ui_form_end([ [ "update", $text{'umass_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});
