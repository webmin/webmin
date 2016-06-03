#!/usr/local/bin/perl
# Show a form for adding a record to multiple domains at once
use strict;
use warnings;
our (%text, %in, %config);

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'rmass_err'});
my @d = split(/\0/, $in{'d'});
@d || &error($text{'rmass_enone'});

&ui_print_header(undef, $text{'rmass_title'}, "");

print &ui_form_start("mass_rcreate.cgi", "post");
my $dc;
foreach my $d (@d) {
	print &ui_hidden("d", $d),"\n";
	$dc++;
	}
print &ui_table_start($text{'rmass_header'}, undef, 2);

# Number of domains selected
print &ui_table_row($text{'umass_sel'}, $dc);

# Type to add
my @rtypes = ( 'A', 'CNAME', 'NS', 'MX', 'PTR', 'TXT', 'SPF',
	    $config{'support_aaaa'} ? ( "AAAA" ) : ( ) );
print &ui_table_row($text{'rmass_type'},
	&ui_select("type", "A",
		   [ map { [ $_, $text{'recs_'.$_} ] } @rtypes ]));

# Record name
print &ui_table_row($text{'rmass_name'},
		    &ui_textbox("name", undef, 30)." ".
		    $text{'rmass_name2'});

# Record value
print &ui_table_row($text{'rmass_value'},
		    &ui_textbox("value", undef, 30));

# Record TTL (optional)
print &ui_table_row($text{'rmass_ttl'},
		    &ui_opt_textbox("ttl", undef, 10, $text{'default'}).
		    " ".$text{'seconds'});

# Prevent clash
print &ui_table_row($text{'rmass_clash'},
		    &ui_radio("clash", 1, [ [ 0, $text{'yes'} ],
					    [ 1, $text{'no'} ] ]));

print &ui_table_end();
print &ui_form_end([ [ "create", $text{'rmass_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});
