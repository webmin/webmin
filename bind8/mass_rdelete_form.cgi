#!/usr/local/bin/perl
# Show a form for deleting a record in multiple zones
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %config);

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'rdmass_err'});
my @d = split(/\0/, $in{'d'});
@d || &error($text{'rdmass_enone'});

&ui_print_header(undef, $text{'rdmass_title'}, "");

print &ui_form_start("mass_rdelete.cgi", "post");
my $dc;
foreach my $d (@d) {
	print &ui_hidden("d", $d),"\n";
	$dc++;
	}
print &ui_table_start($text{'rdmass_header'}, undef, 2);

# Number of domains selected
print &ui_table_row($text{'umass_sel'}, $dc);

# Type to delete
my @rtypes = ( 'A', 'CNAME', 'NS', 'MX', 'PTR', 'TXT', 'SPF',
	    $config{'support_aaaa'} ? ( "AAAA" ) : ( ) );
print &ui_table_row($text{'rdmass_type'},
	&ui_select("type", "A",
		   [ map { [ $_, $text{'recs_'.$_} ] } @rtypes ]));

# Name to delete
print &ui_table_row($text{'rdmass_name'},
	    &ui_opt_textbox("name", undef, 30, $text{'rdmass_all'}."<br>",
			    $text{'rdmass_sel'}));

# Value to delete
print &ui_table_row($text{'rdmass_value'},
	    &ui_opt_textbox("value", undef, 30, $text{'rdmass_vall'}."<br>",
			    $text{'rdmass_vsel'}));

print &ui_table_end();
print &ui_form_end([ [ "rdelete", $text{'rdmass_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});
