#!/usr/local/bin/perl
# Show a page for just adding, editing or removing forwarding addresses

require './filter-lib.pl';
&ReadParse();

&ui_print_header(undef, $text{'forward_title'}, "");

# Get the forwarding filter, if any
@filters = &list_filters();
($filter) = grep { $_->{'actiontype'} eq '!' && $_->{'nocond'} } @filters;
$dis = !$filter;

print &ui_form_start("save_forward.cgi", "post");
print &ui_table_start($text{'forward_header'}, "width=100%", 2);

# Forwarding enabled?
@names = ( "forward", "continue" );
$dis1 = &js_disable_inputs(\@names, [ ]);
$dis2 = &js_disable_inputs([ ], \@names);
print &ui_table_row($text{'forward_enabled'},
	&ui_radio("enabled", $filter ? 1 : 0,
		  [ [ 1, $text{'yes'}, "onClick='$dis2'" ],
		    [ 0, $text{'no'}, "onClick='$dis1'" ] ]));

# Destination address(s)
print &ui_table_row($text{'forward_to'},
	&ui_textarea("forward", join("\n", split(/,/, $filter->{'action'})),
		     5, 70, undef, $dis));

# Continue processing?
print &ui_table_row($text{'forward_cont'},
	&ui_yesno_radio("continue", $filter->{'continue'}, undef, undef,
			$dis));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
