#!/usr/local/bin/perl
# Show per-player time over the last day

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text, %config);
&ReadParse();

&ui_print_header(undef, $text{'playtime_title'}, "");

my ($playtime, $limit_playtime) = &get_current_day_usage();
my @conns = &list_connected_players();

# Get all past play history
my @players = &list_playtime_users();
my %playtime_past;
my %limittime_past;
foreach my $u (@players) {
	foreach my $p (&get_past_day_usage($u)) {
		$playtime_past{$p->[0]}->{$u} = $p->[1];
		$limittime_past{$p->[0]}->{$u} = $p->[2];
		}
	}
my @days = sort { $b cmp $a } (keys %playtime_past);

if (keys %$playtime || @players) {
	# Show day selector
	print &ui_form_start("list_playtime.cgi");
	print "<b>$text{'playtime_date'}</b>\n";
	my @opts = ( [ "", $text{'playtime_today'} ],
		     [ "all", $text{'playtime_alldays'} ] );
	push(@opts, @days);
	print &ui_select("date", $in{'date'}, \@opts, 1, 0, 0, 0,
			 "onChange='form.submit()'"),"\n";
	print &ui_submit($text{'playtime_ok'});
	print &ui_form_end();

	# Get the playtime to show
	if ($in{'date'} eq "all") {
		# Sum up all days
		$playtime = { };
		$limit_playtime = { };
		foreach my $d (@days) {
			foreach my $u (keys %{$playtime_past{$d}}) {
				$playtime->{$u} += $playtime_past{$d}->{$u};
				$limit_playtime->{$u} += $limittime_past{$d}->{$u};
				}
			}
		}
	elsif ($in{'date'} ne "") {
		$playtime = $playtime_past{$in{'date'}};
		$limit_playtime = $limittime_past{$in{'date'}};
		}

	# Show users with playtime, possibly from another day
	print &ui_columns_start([ $text{'playtime_user'},
				  $text{'playtime_time'},
				  $text{'playtime_ltime'},
				  $text{'playtime_now'} ], 100);
	my $total = 0;
	my $ltotal = 0;
	foreach my $u (sort { $playtime->{$b} <=> $playtime->{$a} }
			    keys %$playtime) {
		$total += $playtime->{$u};
		$ltotal += $limit_playtime->{$u};
		print &ui_columns_row([
			&ui_link("view_conn.cgi?name=".&urlize($u),
				 &html_escape($u)),
			&nice_seconds($playtime->{$u}),
			&nice_seconds($limit_playtime->{$u} || 0),
			&indexof($u, @conns) >= 0 ?
			    "<font color=green><b>$text{'playtime_on'}</b></font>" :
			    "<font color=red>$text{'playtime_off'}</a>",
			]);
		}
	print &ui_columns_row([
		"<b>$text{'playtime_total'}</b>",
		&nice_seconds($total),
		&nice_seconds($ltotal),
		undef,
		]);
	print &ui_columns_end();
	}
else {
	print "<b>$text{'playtime_none'}</b><p>\n";
	}

print &ui_hr();

# Show form for setting up play time limits
print &ui_form_start("save_playtime.cgi");
print &ui_table_start($text{'playtime_header'}, undef, 2);

# Cron job enabled?
print &ui_table_row($text{'playtime_enabled'},
	&ui_yesno_radio("enabled", $config{'playtime_enabled'}));

# Max time per day
print &ui_table_row($text{'playtime_max'},
	&ui_opt_textbox("max", $config{'playtime_max'}, 6,
	    $text{'playtime_unlimited'})." ".$text{'playtime_mins'});

# Apply to users
print &ui_table_row($text{'playtime_users'},
	&ui_opt_textbox("users", $config{'playtime_users'}, 40,
		        $text{'playtime_all'}, $text{'playtime_sel'}));

# Days of the week
my @wdays = split(/\s+/, $config{'playtime_days'});
@wdays = (0 .. 6) if (!@wdays);
print &ui_table_row($text{'playtime_days'},
	join(" ", map { &ui_checkbox("days", $_, $text{'day_'.$_},
				     &indexof($_, @wdays) >= 0) } (0 .. 6))); 

# For connections from IPs
print &ui_table_row($text{'playtime_ips'},
	&ui_opt_textbox("ips", $config{'playtime_ips'}, 40,
		        $text{'playtime_all2'}, $text{'playtime_sel2'}));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
