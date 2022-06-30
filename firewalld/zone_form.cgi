#!/usr/local/bin/perl
# Show a form for creating a new zone, with some default rules

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './firewalld-lib.pl';
our (%text, %in);
&ReadParse();
&ui_print_header(undef, $text{'zone_title'}, "");

print &ui_form_start("create_zone.cgi", "post");
print &ui_table_start($text{'zone_header'}, undef, 2);

# New zone name
print &ui_table_row($text{'zone_name'},
	&ui_textbox("name", undef, 20));

# Initial ruleset
print &ui_table_row($text{'zone_mode'},
	&ui_radio_table("mode", 0,
	      [ [ 0, $text{'zone_mode0'} ],
		[ 1, $text{'zone_mode1'},
		  &ui_select("source", $in{'zone'},
			[ map { $_->{'name'} } &list_firewalld_zones() ]) ],
		[ 2, $text{'zone_mode2'} ],
		[ 3, $text{'zone_mode3'} ],
		[ 4, $text{'zone_mode4'} ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("index.cgi?zone=".&urlize($in{'zone'}),
		 $text{'index_return'});
