#!/usr/local/bin/perl
# Show a field for running a console command

use strict;
use warnings;
require './minecraft-lib.pl';
our (%in, %text);
&ReadParse();

my @history = &get_command_history();
$in{'command'} ||= $in{'old'};
if ($in{'command'}) {
	# Run the given command
	&send_server_command($in{'command'});
	@history = &unique($in{'command'}, @history);
	while(@history > 10) {
		pop(@history);
		}
	&save_command_history(\@history);
	}

&PrintHeader();
print "<body onLoad='document.forms[0].command.focus()'>\n";
print &ui_form_start("command.cgi", "post");
my @grid = ( "<b>$text{'console_run'}</b>",
	     &ui_textbox("command", undef, 80)." ".
	     &ui_submit($text{'console_ok'}) );
if (@history) {
	push(@grid, "<b>$text{'console_old'}</b>",
		    &ui_select("old", undef, \@history));
	}
print &ui_grid_table(\@grid, 2);
print &ui_form_end();
print "</body>\n";

