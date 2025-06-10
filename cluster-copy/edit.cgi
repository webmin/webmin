#!/usr/local/bin/perl
# Edit or create a scheduled cluster copy

require './cluster-copy-lib.pl';
&ReadParse();
&foreign_require("servers", "servers-lib.pl");

if (!$in{'new'}) {
	$copy = &get_copy($in{'id'});
	$job = &find_cron_job($copy);
	&ui_print_header(undef, $text{'edit_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'create_title'}, "");
	$copy = { 'mins' => '0',
		  'hours' => '0',
		  'days' => '*',
		  'months' => '*',
		  'weekdays' => '*',
		  'sched' => 1,
		  'dest' => '/' };
	}

print &ui_form_start("save.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("id", $in{'id'});
print &ui_table_start($text{'edit_header'}, "width=100%", 2);

# Files to copy
print &ui_table_row($text{'edit_files'},
		    &ui_textarea("files",
			join("\n", split(/\t+/, $copy->{'files'})), 5, 60)." ".
		    &file_chooser_button("files", 0, undef, undef, 1));

# Destination directory
print &ui_table_row($text{'edit_dest'},
		    &ui_textbox("dest", $copy->{'dest'}, 50));
print &ui_table_row(" ",
		    &ui_radio("dmode", $copy->{'dmode'} || 0,
			      [ [ 0, $text{'edit_dmode0'} ],
				[ 1, $text{'edit_dmode1'} ] ]));

# Command to run before copy
print &ui_table_row($text{'edit_before'},
		    &ui_textbox("before", $copy->{'before'}, 60)." ".
		    &ui_checkbox("beforeremote", 1, $text{'edit_remote'},
				 !$copy->{'beforelocal'}));

# Command to run after copy
print &ui_table_row($text{'edit_cmd'},
		    &ui_textbox("cmd", $copy->{'cmd'}, 60)." ".
		    &ui_checkbox("cmdremote", 1, $text{'edit_remote'},
				 !$copy->{'cmdlocal'}));

# Target servers
@sel = split(/\s+/, $copy->{'servers'});
push(@opts, [ "ALL", $text{'edit_all'} ]);
push(@opts, [ "*", $text{'edit_this'} ]);
foreach $s (grep { $_->{'user'} } &servers::list_servers()) {
	push(@opts, [ $s->{'host'}, $s->{'desc'} || $s->{'host'} ]);
	}
foreach $g (&servers::list_all_groups()) {
	push(@opts, [ "group_".$g->{'name'},
		      &text('edit_group', $g->{'name'}) ]);
	}
print &ui_table_row($text{'edit_servers'},
		    &ui_select("servers", \@sel, \@opts, 8, 1));

# Cron enabled
print &ui_table_row($text{'edit_sched'},
		    &ui_radio("sched", $job || $in{'new'} ? 1 : 0,
			      [ [ 0, $text{'no'} ],
				[ 1, $text{'edit_schedyes'} ] ]));

# Send email to
print &ui_table_row($text{'edit_email'},
	    &ui_opt_textbox("email", $copy->{'email'}, 50, $text{'edit_none'}));

# Cron times
print &cron::get_times_input($copy);

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ 'create', $text{'create'} ] ], "100%");
	}
else {
	print &ui_form_end([ [ 'save', $text{'save'} ],
			     [ 'run', $text{'edit_run'} ],
			     [ 'delete', $text{'delete'} ] ], "100%");
	}

&ui_print_footer("", $text{'index_return'});

