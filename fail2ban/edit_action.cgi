#!/usr/local/bin/perl
# Show a form for editing or creating an action

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%in, %text);
&ReadParse();

my ($action, $def);

# Show header and get the action object
if ($in{'new'}) {
	&ui_print_header(undef, $text{'action_title1'}, "");
	$action = [ ];
	$def = { 'members' => [ ] };
	}
else {
	&ui_print_header(undef, $text{'action_title2'}, "");
	($action) = grep { $_->[0]->{'file'} eq $in{'file'} } &list_actions();
	$action || &error($text{'action_egone'});
	($def) = grep { $_->{'name'} eq 'Definition' } @$action;
	$def || &error($text{'action_edefgone'});
	}

print &ui_form_start("save_action.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("file", $in{'file'});
print &ui_table_start($text{'action_header'}, undef, 2);

# Service name
if ($in{'new'}) {
	print &ui_table_row($text{'action_name'},
		&ui_textbox("name", undef, 30));
	}
else {
	my $fname = &filename_to_name($def->{'file'});
	print &ui_table_row($text{'action_name'},
		"<tt>".&html_escape($fname)."</tt>");
	}

# Start command
my $start = &find_value("actionstart", $def);
print &ui_table_row($text{'action_start'},
	&ui_textarea("start", $start, 5, 80, "hard"));

# Stop command
my $stop = &find_value("actionstop", $def);
print &ui_table_row($text{'action_stop'},
	&ui_textarea("stop", $stop, 5, 80, "hard"));

# Command to ban a host
my $ban = &find_value("actionban", $def);
print &ui_table_row($text{'action_ban'},
	&ui_textarea("ban", $ban, 5, 80, "hard")."<br>\n".
	$text{'action_desc'});

# Command to un-ban a host
my $unban = &find_value("actionunban", $def);
print &ui_table_row($text{'action_unban'},
	&ui_textarea("unban", $unban, 5, 80, "hard"));

# Check command
my $check = &find_value("actioncheck", $def);
print &ui_table_row($text{'action_check'},
	&ui_textarea("check", $check, 5, 80, "hard"));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_actions.cgi", $text{'actions_return'});

