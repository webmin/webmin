#!/usr/local/bin/perl
# Show details of a player, with buttons to perform actions

use strict;
use warnings;
require './minecraft-lib.pl';
our (%in, %text);
&ReadParse();

&ui_print_header(undef, $text{'conn_title'}, "");

$in{'name'} =~ /^\S+$/ || &error($text{'conn_ename'});

print &ui_form_start("save_conn.cgi", "post");
print &ui_hidden("name", $in{'name'});
print &ui_table_start($text{'conn_header'}, undef, 2);

# Player name
print &ui_table_row($text{'conn_name'},
	&html_escape($in{'name'}));

# Current state
my @conns = &list_connected_players();
my ($c) = grep { $_ eq $in{'name'} } @conns;
print &ui_table_row($text{'conn_state'},
	$c ? $text{'conn_yes'} : "<font color=red>$text{'conn_no'}</font>");

# Last login IP and time
my ($ip, $intime, $x, $y, $z, $outtime) = &get_login_logout_times($in{'name'});
if ($ip) {
	print &ui_table_row($c ? $text{'conn_lastin'} : $text{'conn_lastin2'},
		&text('conn_at', $ip, &make_date($intime)));
	print &ui_table_row($text{'conn_pos'},
		"X:$x Y:$y Z:$z");
	}

if (!$c && $outtime) {
	# Logged out at
	print &ui_table_row($text{'conn_lastout'},
		&make_date($outtime));
	}

if ($c || 1) {
	print &ui_table_hr();

	# Send message
	print &ui_table_row($text{'conn_msg'},
		&ui_textbox("text", undef, 40)." ".
		&ui_submit($text{'conn_msgb'}, 'msg'));

	# Kill player
	print &ui_table_row($text{'conn_kill'},
		&ui_submit($text{'conn_killb'}, 'kill'));

	# Grant item
	print &ui_table_row($text{'conn_give'},
		&ui_textbox("id", undef, 5).
		&item_chooser_button("id")." ".
		$text{'conn_count'}." ".
		&ui_textbox("count", 1, 5)." ".
		&ui_submit($text{'conn_giveb'}, 'give'));
	}

print &ui_table_end();
print &ui_form_end();

if (!$c && !$ip && !$outtime) {
	print "<b>$text{'conn_never'}</b><p>\n";
	}

&ui_print_footer("list_conns.cgi", $text{'conns_return'});

