#!/usr/local/bin/perl
# Show per-player time over the last day

use strict;
use warnings;
require './minecraft-lib.pl';
our (%in, %text, %config);

&ui_print_header(undef, $text{'playtime_title'}, "");

my ($playtime, $limit_playtime) = &get_current_day_usage();
my @conns = &list_connected_players();

if (keys %$playtime) {
	print &ui_columns_start([ $text{'playtime_user'},
				  $text{'playtime_time'},
				  $text{'playtime_ltime'},
				  $text{'playtime_now'} ], 100);
	foreach my $u (sort { $playtime->{$b} <=> $playtime->{$a} }
			    keys %$playtime) {
		print &ui_columns_row([
			"<a href='view_conn.cgi?name=".&urlize($u)."'>".
			  &html_escape($u)."</a>",
			&nice_seconds($playtime->{$u}),
			&nice_seconds($limit_playtime->{$u} || 0),
			&indexof($u, @conns) >= 0 ?
			    "<font color=green><b>$text{'playtime_on'}</b></font>" :
			    "<font color=red>$text{'playtime_off'}</a>",
			]);
		}
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
my @days = split(/\s+/, $config{'playtime_days'});
@days = (0 .. 6) if (!@days);
print &ui_table_row($text{'playtime_days'},
	join(" ", map { &ui_checkbox("days", $_, $text{'day_'.$_},
				     &indexof($_, @days) >= 0) } (0 .. 6))); 

# For connections from IPs
print &ui_table_row($text{'playtime_ips'},
	&ui_opt_textbox("ips", $config{'playtime_ips'}, 40,
		        $text{'playtime_all2'}, $text{'playtime_sel2'}));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
