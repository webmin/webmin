#!/usr/local/bin/perl
# edit_receipe.cgi
# Display a form for editing or creating a procmail receipe

require './procmail-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	$block++ if ($in{'block'});
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "");
	@conf = &get_procmailrc();
	$rec = $conf[$in{'idx'}];
	$block++ if (defined($rec->{'block'}));
	}

print &ui_form_start("save_recipe.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("before", $in{'before'});
print &ui_hidden("after", $in{'after'});
print &ui_hidden("block", $block);
print &ui_table_start($text{'edit_header1'}, "width=100%", 2);

if ($block) {
	# Start of a conditional block
	local @lines = split(/\n/, $rec->{'block'});
	local $r = @lines > 5 ? 10 : 5;
	print &ui_table_row($text{'edit_block'},
		&ui_textarea("bdata", $rec->{'block'}, $r, 80));
	}
else {
	# Simple action
	($t, $a) = &parse_action($rec);
	print &ui_table_row($text{'edit_action'},
		&ui_select("amode", $t,
		   [ map { [ $_, $text{"edit_amode_".$_} ] }
			 (0, 2, 1, 3, 4, 6) ])." ".
		&ui_textbox("action", $t == 6 ? $rec->{'action'} : $a, 40));
	}

# Action options
@grid = ( );
foreach $f (@known_flags) {
	push(@grid, &ui_checkbox("flag", $f, $text{"edit_flag_$f"},
				 &indexof($f, @{$rec->{'flags'}}) >= 0));
	}
print &ui_table_row(undef, &ui_grid_table(\@grid, 2, 100), 2);

# Lock file
$ldef = $rec->{'lockfile'} ? 0 :
	defined($rec->{'lockfile'}) ? 2 : 1;
print &ui_table_row($text{'edit_lockfile'},
	&ui_radio("lockfile_def", $ldef,
		  [ [ 1, $text{'edit_none'} ],
		    [ 2, $text{'default'} ],
		    [ 0, $text{'edit_lock'}." ".
			 &ui_textbox("lockfile", $rec->{'lockfile'}, 40) ] ]));

print &ui_table_end();

# Show conditions section
print &ui_table_start($text{'edit_header2'}, "width=100%", 2);
print &ui_table_row(undef, $text{'edit_conddesc'}, 2);

$ctable = &ui_columns_start([ $text{'edit_ctype'}, $text{'edit_cvalue'} ], 100);
$i = 0;
foreach $c (@{$rec->{'conds'}}, [ '-' ], [ '-' ] ) {
	$ctable .= &ui_columns_row([
		&ui_select("cmode_$i", $c->[0],
		   [ [ '-', '&nbsp;' ],
		     [ '', $text{'edit_cmode_re'} ],
		     [ '!', $text{'edit_cmode_nre'} ],
		     [ '$', $text{'edit_cmode_shell'} ],
		     [ '?', $text{'edit_cmode_exit'} ],
		     [ '<', $text{'edit_cmode_lt'} ],
		     [ '>', $text{'edit_cmode_gt'} ] ]),
		&ui_textbox("cond_$i", $c->[1], 60, 0, undef,
			    "style='width:100%'"),
		]);
	$i++;
	}
$ctable .= &ui_columns_end();
print &ui_table_row(undef, $ctable, 2);
print &ui_table_end();

# Show save buttons
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

