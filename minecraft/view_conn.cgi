#!/usr/local/bin/perl
# Show details of a player, with buttons to perform actions

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text);
&ReadParse();

&ui_print_header(undef, $text{'conn_title'}, "");

$in{'name'} =~ /^\S+$/ || &error($text{'conn_ename'});

# Show message from action
if ($in{'msg'}) {
	print "<b><font color=green>$in{'msg'}</font></b><p>\n";
	}

print &ui_form_start("save_conn.cgi", "post");
print &ui_hidden("name", $in{'name'});
print &ui_table_start($text{'conn_header'}, undef, 2);

# Player name
print &ui_table_row($text{'conn_name'},
	&html_escape($in{'name'}));

# Player UUID
my $uuid = &uuid_to_username($in{'name'});
if ($uuid) {
	print &ui_table_row($text{'conn_uuid'},
		&html_escape($uuid));
	}

# Current state
my @conns = &list_connected_players();
my ($c) = grep { $_ eq $in{'name'} } @conns;
print &ui_table_row($text{'conn_state'},
	$c ? $text{'conn_yes'} : "<font color=red>$text{'conn_no'}</font>");

# Last login IP and time
my ($ip, $intime, $x, $y, $z, $outtime, $events) =
	&get_login_logout_times($in{'name'});
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

	# Kill player (not possible?)
	#print &ui_table_row($text{'conn_kill'},
	#	&ui_submit($text{'conn_killb'}, 'kill'));

	# Disconnect player
	print &ui_table_row($text{'conn_kick'},
		&ui_submit($text{'conn_kickb'}, 'kick'));

	# Grant item
	print &ui_table_row($text{'conn_give'},
		&ui_textbox("id", undef, 20).
		&item_chooser_button("id")." ".
		$text{'conn_count'}." ".
		&ui_textbox("count", 1, 5)." ".
		&ui_submit($text{'conn_giveb'}, 'give'));

	# Grant XP
	print &ui_table_row($text{'conn_xp'},
		&ui_textbox("xpadd", undef, 5)." ".
		&ui_select("xpmode", 0,
			   [ [ 0, $text{'conn_xp0'} ],
			     [ 1, $text{'conn_xp1'} ] ])." ".
		&ui_submit($text{'conn_xpb'}, 'xp'));

	# Change spawn point
	print &ui_table_row($text{'conn_spawn'},
		"X:".&ui_textbox("spawnx", int($x), 10)." ".
		"Y:".&ui_textbox("spawny", int($y), 10)." ".
		"Z:".&ui_textbox("spawnz", int($z), 10)." ".
		&ui_submit($text{'conn_spawnb'}, 'spawn'));

	# Teleport to location
	print &ui_table_row($text{'conn_tp'},
		"X:".&ui_textbox("tpx", int($x), 10)." ".
		"Y:".&ui_textbox("tpy", int($y), 10)." ".
		"Z:".&ui_textbox("tpz", int($z), 10)." ".
		&ui_submit($text{'conn_tpb'}, 'tp'));

	# Teleport to player
	if (@conns) {
		print &ui_table_row($text{'conn_tpp'},
			&ui_select("player", undef, \@conns)." ".
			&ui_submit($text{'conn_tpb'}, 'tpp'));
		}

	# Ban or un-ban player
	my @banlist = &list_banned_players();
	my ($b) = grep { lc($_) eq lc($in{'name'}) } @banlist;
	if ($b) {
		print &ui_table_row($text{'conn_banlist'},
			"<font color=red>$text{'conn_banned'}</font> ".
			&ui_submit($text{'conn_pardonb'}, 'pardon'));
		}
	else {
		print &ui_table_row($text{'conn_banlist'},
			$text{'conn_pardoned'}." ".
			&ui_submit($text{'conn_banb'}, 'ban')." ".
			$text{'conn_reason'}." ".
			&ui_textbox("reason", undef, 30));
		}

	# Op or de-op player
	print &ui_table_row($text{'conn_oplist'},
		&ui_submit($text{'conn_opb'}, 'op')." ".
		&ui_submit($text{'conn_deopb'}, 'deop'));
	}


# Show recent events, if any
if (@$events) {
	my $etable = &ui_columns_start([
			$text{'conn_edate'},
			$text{'conn_emsg'},
			], undef, 0, [ "nowrap", "nowrap" ]);
	foreach my $e (reverse(@$events)) {
		$etable .= &ui_columns_row([
			&make_date($e->{'time'})."&nbsp;&nbsp;",
			&html_escape($e->{'msg'}),
			]);
		}
	$etable .= &ui_columns_end();
	print &ui_table_row($text{'conn_events'}, $etable);
	}

# Show player stats
my $stats = &get_player_stats($in{'name'});
my $stable;
if (ref($stats)) {
	my @rows;
	foreach my $k (keys %$stats) {
		if ($k =~ /^stat\.(\S+)/ && !ref($stats->{$k})) {
			push(@rows, "<tt>$1</tt>", $stats->{$k});
			}
		}
	if (@rows) {
		unshift(@rows, "<b>$text{'conn_stat'}</b>",
			       "<b>$text{'conn_statv'}</b>",
			       "<b>$text{'conn_stat'}</b>",
			       "<b>$text{'conn_statv'}</b>");
		$stable = &ui_grid_table(\@rows, 4, 100);
		}
	else {
		$stable = $text{'conn_nostats'};
		}
	}
else {
	$stable = $stats;
	}
print &ui_table_row($text{'conn_stats'}, $stable);

print &ui_table_end();
print &ui_form_end();

if (!$c && !$ip && !$outtime) {
	print "<b>$text{'conn_never'}</b><p>\n";
	}

&ui_print_footer("list_conns.cgi", $text{'conns_return'});

