#!/usr/local/bin/perl
# Show currently connected MySQL users

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'procs_ecannot'});
&ui_print_header(undef, $text{'procs_title'}, "", "procs");

# Get the processes, except this one
$d = &execute_sql($master_db, "show full processlist");
@procs = grep { $_->[7] ne "show full processlist" ||
		$_->[3] ne $master_db ||
		$_->[1] ne $mysql_login } @{$d->{'data'}};

if (@procs) {
	print &ui_form_start("kill_procs.cgi", "post");
	@tds = ( "width=5" );
	@rowlinks = ( &select_all_link("d"),
		      &select_invert_link("d") );
	print &ui_links_row(\@rowlinks);
	print &ui_columns_start([ "",
				  $text{'procs_id'},
				  $text{'procs_user'},
				  $text{'procs_host'},
				  $text{'procs_db'},
				  $text{'procs_cmd'},
				  $text{'procs_time'},
				  $text{'procs_query'} ], 100, 0, \@tds);
	foreach $r (@procs) {
		print &ui_checked_columns_row([
			$r->[0],
			&ui_link("edit_user.cgi?user=$r->[1]",$r->[1]),
			$r->[2],
			&ui_link("edit_dbase.cgi?db=$r->[3]",$r->[3]),
			$r->[4],
			&nice_time($r->[5]),
			&html_escape($r->[7])
			], \@tds, "d", $r->[0]);
		}
	print &ui_columns_end();
	print &ui_links_row(\@rowlinks);
	print &ui_form_end([ [ "kill", $text{'procs_kill'} ] ]);
	}
else {
	print "<b>$text{'procs_none'}</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

sub nice_time
{
local ($s) = @_;
return sprintf "%2.2d:%2.2d:%2.2d",
	int($s / 3600), int($s / 60)%60, $s % 60;
}

