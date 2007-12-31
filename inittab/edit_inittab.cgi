#!/usr/local/bin/perl

require "./inittab-lib.pl";
&ReadParse();

if ($in{'new'}) {
	# Creating a new one
	$init = { };
	}
else {
	# Find existing config
	@inittab = &parse_inittab();
	($init) = grep { $_->{'id'} eq $in{'id'} } @inittab;
	}

&ui_print_header(undef,  &text('edit_inittab_title', $in{'id'}), "");

print &ui_form_start("save_inittab.cgi");
print &ui_hidden("oldid", $init->{'id'});
print &ui_hidden("new", $in{'new'});
print &ui_table_start($text{'edit_inittab_details'}, "width=100%", 2);

# ID number
print &ui_table_row(&hlink($text{'inittab_id'}, "id" ),
	&ui_textbox("id", $init->{'id'}, $config{'inittab_size'}));

# Active or not?
print &ui_table_row(&hlink($text{ 'inittab_active' },"active"),
	&ui_radio("comment", $init->{'comment'} ? 1 : 0,
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

# Levels to run in 
print &ui_table_row(&hlink($text{'inittab_runlevels'}, "runlevels"),
	join(" ", map { &ui_checkbox($_, 1, $_, &indexof($_, @{$init->{'levels'}}) >= 0) } &list_runlevels()));

# Action
$init->{'action'} = "kbdrequest" if ($init->{'action'} eq "kbrequest");
print &ui_table_row(&hlink($text{'inittab_action'}, "action"),
	&ui_select("action", $init->{'action'}, [ &list_actions() ],
		   1, 0, 1));

# Command to run
print &ui_table_row(&hlink($text{'inittab_process'}, "process"),
	&ui_textbox("process", $init->{'process'}, 60));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "button", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "button", $text{'save'} ],
			     [ "button", $text{'edit_inittab_del'} ] ]);
	}

&ui_print_footer( "", $text{ 'inittab_return' } );

