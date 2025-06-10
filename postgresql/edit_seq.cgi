#!/usr/local/bin/perl
# Show a form for creating or editing a sequence

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
$access{'seqs'} || &error($text{'seq_ecannot'});

if ($in{'seq'}) {
	# Editing a sequence
	$str = &sequence_structure($in{'db'}, $in{'seq'});
	}
else {
	$str = { 'increment_by' => 1,
		 'last_value' => 1 };
	}
$desc = "<tt>$in{'db'}</tt>";
&ui_print_header($desc, $in{'seq'} ? $text{'seq_title2'}
				   : $text{'seq_title1'}, "");

print &ui_form_start("save_seq.cgi", "post");
print &ui_hidden("db", $in{'db'}),"\n";
print &ui_hidden("old", $in{'seq'}),"\n";
print &ui_table_start($text{'seq_header1'}, undef, 2);

# Sequence name
print &ui_table_row($text{'seq_name'},
		    $in{'seq'} ? "<tt>$in{'seq'}</tt>"
			       : &ui_textbox("name", $str->{'name'}, 20));

# Current value
print &ui_table_row($text{'seq_last'},
	$in{'seq'} && &supports_sequences() == 1 ?
   &ui_opt_textbox("last", undef, 20, &text('seq_leave', $str->{'last_value'}))
   : &ui_textbox("last", $str->{'last_value'}, 20)); 

# Min and max
print &ui_table_row($text{'seq_min'},
	    &ui_opt_textbox("min", $str->{'min_value'}, 20, $text{'seq_none'}));
print &ui_table_row($text{'seq_max'},
	    &ui_opt_textbox("max", $str->{'max_value'}, 20, $text{'seq_none'}));

# Increment
print &ui_table_row($text{'seq_inc'},
	    &ui_textbox("inc", $str->{'increment_by'}, 5));

# Values to cache
print &ui_table_row($text{'seq_cache'},
	!$in{'seq'} ? &ui_opt_textbox("cache", undef, 5, $text{'default'})
		    : &ui_textbox("cache", $str->{'cache_value'}, 5));

# Wrap at end of cycle
print &ui_table_row($text{'seq_cycle'},
    &ui_yesno_radio("cycle",
	$str->{'is_cycled'} eq 't' || $str->{'is_cycled'} eq '1' ? 1 : 0));

print &ui_table_end();
if ($in{'seq'}) {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	&get_databases_return_link($in{'db'}), $text{'index_return'});
