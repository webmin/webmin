#!/usr/local/bin/perl
# index.cgi
# Shows a form for running a command, allowing the selection of a server or
# group of servers to run it on.

require './cluster-shell-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 0, 1);

print &ui_form_start("run.cgi", "post");
print &ui_table_start(undef, undef, 2);

print &ui_table_row($text{'index_cmd'},
	&ui_textbox("cmd", undef, 60));

open(COMMANDS, $commands_file);
chop(@commands = <COMMANDS>);
close(COMMANDS);
if (@commands) {
	print &ui_table_row($text{'index_old'},
		&ui_select("old", undef, [ &unique(@commands) ])." ".
		&ui_button($text{'index_edit'}, "clear", undef,
			   "onClick='form.cmd.value = form.old.value'").
		" ".
		&ui_button($text{'index_clear'}, "clear", undef,
			   "onClick='window.location = \"run.cgi?clear=1\"'"));
	}

@opts = ( [ "ALL", $text{'index_all'} ],
	  [ "*", $text{'index_this'} ] );
foreach $s (grep { $_->{'user'} }
		 sort { $a->{'host'} cmp $b->{'host'} }
		      &servers::list_servers()) {
	push(@opts, [ $s->{'host'},
	      $s->{'host'}.($s->{'desc'} ? " (".$s->{'desc'}.")" : "") ]);
	}
foreach $g (&servers::list_all_groups()) {
	$gn = "group_".$g->{'name'};
	push(@opts, [ $gn, &text('index_group', $g->{'name'}) ]);
	}
print &ui_table_row($text{'index_server'},
	&ui_select("server", [ split(/ /, $config{'server'}) ],
		   \@opts, 10, 1));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'index_run'} ] ]);

&ui_print_footer("/", $text{'index'});

