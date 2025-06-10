#!/usr/local/bin/perl
# Show a form for setting up automatic node group updates

require './bacula-backup-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ui_print_header(undef,  $text{'sync_title'}, "", "sync");

print &ui_form_start("save_sync.cgi", "post");
print &ui_table_start($text{'sync_header'}, undef, 2);

# Sync enabled?
$job = &find_cron_job();
print &ui_table_row($text{'sync_sched'},
		    &ui_radio("sched", $job ? 1 : 0,
			      [ [ 0, $text{'no'} ],
				[ 1, $text{'sync_schedyes'} ] ]));

# Cron times
$job ||= { 'special' => 'hourly' };
$cron = &capture_function_output(\&cron::show_times_input, $job);
print &ui_table_span("<table border>$cron</table>");

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

