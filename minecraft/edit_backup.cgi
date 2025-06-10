#!/usr/local/bin/perl
# Show a form for setting up scheduled backups

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
&foreign_require("webmincron");
our (%in, %text, %config);

&ui_print_header(undef, $text{'backup_title'}, "");

print $text{'backup_desc'},"<p>\n";

print &ui_form_start("save_backup.cgi", "post");
print &ui_table_start($text{'backup_header'}, undef, 2);

# Backup enabled
my $job = &get_backup_job();
print &ui_table_row($text{'backup_enabled'},
	&ui_yesno_radio("enabled", $job ? 1 : 0));

# Schedule
print &ui_table_row($text{'backup_sched'},
	&webmincron::show_times_input(
		$job || { 'mins' => 0,
			  'hours' => 0,
			  'days' => '*',
			  'months' => '*',
			  'weekdays' => '*' }, 0));

# Destination directory
print &ui_table_row($text{'backup_dir'},
	&ui_textbox("dir", $config{'backup_dir'}, 50));

# Worlds to include
my @worlds = &list_worlds();
print &ui_table_row($text{'backup_worlds'},
	&ui_radio("worlds_def", $config{'backup_worlds'} ? 0 : 1,
		  [ [ 1, $text{'backup_worlds1'} ],
		    [ 0, $text{'backup_worlds0'} ] ])."<br>\n".
	&ui_select("worlds", [ split(/\s+/, $config{'backup_worlds'}) ],
		   [ map { $_->{'name'} } @worlds ], 5, 1, 1));

# Send backup report to
print &ui_table_row($text{'backup_email'},
	&ui_opt_textbox("email", $config{'backup_email'}, 40,
		$text{'backup_noemail'}, $text{'backup_emailto'})."<br>\n".
	&ui_checkbox("email_err", 1, $text{'backup_email_err'},
		     $config{'backup_email_err'} ? 1 : 0));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ],
		     [ 'now', $text{'backup_now'} ] ]);

&ui_print_footer("", $text{'index_return'});
