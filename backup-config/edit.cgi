#!/usr/local/bin/perl
# Show one scheduled backup

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './backup-config-lib.pl';
our (%in, %text, %gconfig);
&ReadParse();

my $backup;
my $wet = $gconfig{'webmin_email_to'};
if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	$backup = { 'emode' => 0,
		    'email' => $wet ? '*' : undef,
		    'sched' => 1,
		    'configfile' => 1,
		    'nofiles' => 0,
		    'mins' => 0,
		    'hours' => 0,
		    'days' => '*',
		    'months' => '*',
		    'weekdays' => '*' };
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "");
	$backup = &get_backup($in{'id'});
	}

print &ui_form_start("save.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("id", $in{'id'});

my @tds = ( "width=20% nowrap" );
print &ui_hidden_table_start($text{'edit_header'}, "width=100%", 2,
			     "main", 1, \@tds);

# Show modules to backup
my @mods = &list_backup_modules();
my @dmods = split(/\s+/, $backup->{'mods'});
print &ui_table_row($text{'edit_mods'},
		    &ui_select("mods", \@dmods,
		       [ map { [ $_->{'dir'}, $_->{'desc'} ] } @mods ],
		       10, 1));

# Show destination
print &ui_table_row($text{'edit_dest'},
		    &show_backup_destination("dest", $backup->{'dest'}, 0));

# Show files to include
print &ui_table_row($text{'edit_what'},
		    &show_backup_what("what", $backup->{'configfile'},
					      $backup->{'nofiles'},
					      $backup->{'others'}));

print &ui_hidden_table_end();

print &ui_hidden_table_start($text{'edit_header2'}, "width=100%", 2,
			     "prepost", 0, \@tds);

# Show pre-backup command
print &ui_table_row($text{'edit_pre'},
		    &ui_textbox("pre", $backup->{'pre'}, 60));

# Show post-backup command
print &ui_table_row($text{'edit_post'},
		    &ui_textbox("post", $backup->{'post'}, 60));

print &ui_hidden_table_end();

print &ui_hidden_table_start($text{'edit_header3'}, "width=100%", 2,
			     "sched", 0, \@tds);

# Show email address
print &ui_table_row($text{'edit_email'},
	$wet ? &ui_opt_textbox("email",
			$backup->{'email'} eq '*' ? undef : $backup->{'email'},
			40, &text('edit_email_def', "<tt>$wet</tt>"))
	     : &ui_textbox("email", $backup->{'email'}, 40));

# Show email mode
print &ui_table_row($text{'edit_emode'},
		    &ui_radio("emode", $backup->{'emode'},
			      [ [ 0, $text{'edit_emode0'} ],
				[ 1, $text{'edit_emode1'} ] ]));

# Show schedule
my $job;
if ($backup) {
	$job = &find_cron_job($backup);
	}
print &ui_table_row($text{'edit_sched'},
		    &ui_radio("sched", $job || $in{'new'} ? 1 : 0,
			      [ [ 0, $text{'no'} ],
				[ 1, $text{'edit_schedyes'} ] ]));
print &cron::get_times_input($backup);

print &ui_hidden_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ 'create', $text{'create'} ] ], "100%");
	}
else {
	print &ui_form_end([ [ 'save', $text{'save'} ],
			     [ 'run', $text{'edit_run'} ],
			     [ 'delete', $text{'delete'} ] ], "100%");
	}

&ui_print_footer("", $text{'index_return'});


