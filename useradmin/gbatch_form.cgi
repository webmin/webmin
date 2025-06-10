#!/usr/local/bin/perl
# Display a form for doing batch group creation, updates or deletion from
# a text file

require './user-lib.pl';
$access{'batch'} || &error($text{'gbatch_ecannot'});
&ui_print_header(undef, $text{'gbatch_title'}, "");

# Instructions
print &ui_hidden_start($text{'batch_instr'}, "instr", 0, "batch_form.cgi");
print "$text{'gbatch_desc'}<p>\n";
print "<tt>$text{'gbatch_desc2'}</tt><p>\n";
print "$text{'gbatch_descafter'}<br>\n";
print "$text{'gbatch_descafter2'}\n";
print &ui_hidden_end("instr");

print &ui_form_start("gbatch_exec.cgi", "form-data");
print &ui_table_start($text{'gbatch_header'}, undef, 2);

# Source file
print &ui_table_row($text{'batch_source'},
	&ui_radio_table("source", 0,
	  [ [ 0, $text{'batch_source0'}, &ui_upload("file") ],
	    [ 1, $text{'batch_source1'}, &ui_textbox("local", undef, 40)." ".
					 &file_chooser_button("local") ],
	    [ 2, $text{'batch_source2'}, &ui_textarea("text", undef, 5, 60) ]
	  ]));

if ($access{'cothers'} == 1 || $access{'mothers'} == 1 ||
    $access{'dothers'} == 1) {
	# Do other modules?
	print &ui_table_row($text{'gbatch_others'},
		&ui_yesno_radio("others", int($config{'default_other'})));
	}

# Only run post-command at end?
print &ui_table_row($text{'gbatch_batch'},
	&ui_yesno_radio("batch", 0));

if ($access{'chgid'}) {
	# Update GIDs on files
	print &ui_table_row($text{'gbatch_chgid'},
		&ui_radio("chgid", 0, [ [ 0, $text{'no'} ],
					[ 1, $text{'home'} ],
					[ 2, $text{'uedit_allfiles'} ] ]));
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'batch_upload'} ] ]);

&ui_print_footer("", $text{'index_return'});

