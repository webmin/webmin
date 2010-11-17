#!/usr/local/bin/perl
# Show a page for just adding, editing or removing an autoreply message

require './filter-lib.pl';
&ReadParse();

&ui_print_header(undef, $text{'auto_title'}, "");

# Get the autoreply filter, if any
@filters = &list_filters();
($filter) = grep { $_->{'actionreply'} && $_->{'nocond'} } @filters;
$dis = !$filter;

print &ui_form_start("save_auto.cgi", "post");
print &ui_table_start($text{'auto_header'}, "width=100%", 2);

# Autoreply enabled?
@names = ( "reply" );
$dis1 = &js_disable_inputs(\@names, [ ]);
$dis2 = &js_disable_inputs([ ], \@names);
print &ui_table_row($text{'auto_enabled'},
	&ui_radio("enabled", $filter ? 1 : 0,
		  [ [ 1, $text{'yes'}, "onClick='$dis2'" ],
		    [ 0, $text{'no'}, "onClick='$dis1'" ] ]));

# Message
print &ui_table_row($text{'auto_reply'},
	&ui_textarea("reply", $filter->{'reply'}->{'autotext'}, 5, 80,
		     undef, $dis));

# Character set
print &ui_table_row($text{'auto_charset'},
	&ui_opt_textbox("charset", $filter->{'reply'}->{'charset'}, 20,
		       $text{'default'}." (iso-8859-1)"));

# Period
if (!$config{'reply_force'}) {
	$r = $filter->{'reply'};
	$period = $r->{'replies'} && $r->{'period'} ? int($r->{'period'}/60) :
		  $r->{'replies'} ? 60 : undef;
	if ($config{'reply_min'}) {
		# Forced on, with a minimum
		print &ui_table_row($text{'auto_period'},
			&ui_textbox("period", $period, 3).
			" ".$text{'index_mins'});
		}
	else {
		# Can turn off reply tracking
		print &ui_table_row($text{'auto_period'},
			&ui_opt_textbox("period", $period, 3,
					$text{'index_noperiod'}).
			" ".$text{'index_mins'});
		}
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
