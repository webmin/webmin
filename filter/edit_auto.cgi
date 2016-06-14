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
	&ui_textarea("reply",
		     $filter ? $filter->{'reply'}->{'autotext'} : "", 5, 80,
		     undef, $dis));

# Subject line
print &ui_table_row($text{'auto_subject'},
	&ui_opt_textbox("subject",
		$filter ? $filter->{'reply'}->{'subject'} : "", 60,
		$text{'default'}." (Autoreply to \$SUBJECT)"));

# Character set
$cs = $filter ? $filter->{'reply'}->{'charset'} :
      &get_charset() eq $default_charset ? undef : &get_charset();
$csmode = $cs eq &get_charset() ? 2 :
	  $cs ? 0 : 1;
print &ui_table_row($text{'auto_charset'},
	&ui_radio("charset_def", $csmode,
		  [ [ 1, $text{'default'}." ($default_charset)" ],
		    &get_charset() eq $default_charset ? ( ) :
			( [ 2, $text{'auto_charsetdef'}.
			       " (".&get_charset().")" ] ),
	 	    [ 0, $text{'auto_charsetother'} ] ])." ".
	&ui_textbox("charset", $csmode == 0 ? $cs : "", 20));

# Period
$r = $filter ? $filter->{'reply'} : undef;
if (!$config{'reply_force'}) {
	$period = !$filter ? 60 :
		  $r->{'replies'} && $r->{'period'} ? int($r->{'period'}/60) :
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

# Start and end dates
if ($r && $r->{'autoreply_start'}) {
	@stm = localtime($r->{'autoreply_start'});
	$stm[4]++; $stm[5] += 1900;
	}
if ($r && $r->{'autoreply_end'}) {
	@etm = localtime($r->{'autoreply_end'});
	$etm[4]++; $etm[5] += 1900;
	}
print &ui_table_row($text{'index_astart'},
	&ui_radio("start_def", @stm ? 0 : 1,
		  [ [ 1, $text{'index_forever'} ],
		    [ 0, $text{'index_ondate'} ] ])." ".
	&ui_date_input($stm[3], $stm[4], $stm[5],
		       "dstart", "mstart", "ystart")." ".
        &date_chooser_button("dstart", "mstart", "ystart"));
print &ui_table_row($text{'index_aend'},
	&ui_radio("end_def", @etm ? 0 : 1,
		  [ [ 1, $text{'index_forever'} ],
		    [ 0, $text{'index_ondate'} ] ])." ".
	&ui_date_input($etm[3], $etm[4], $etm[5],
		       "dend", "mend", "yend")." ".
        &date_chooser_button("dend", "mend", "yend"));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
