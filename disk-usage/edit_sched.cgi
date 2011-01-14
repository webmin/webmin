#!/usr/local/bin/perl
# Show a form for setting up scheduled collection

require './disk-usage-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ui_print_header(undef, $text{'sched_title'}, "");
$job = &find_cron_job();

print &ui_form_start("save_sched.cgi");
print &ui_table_start($text{'sched_header'}, "width=100%", 2);

print &ui_table_row($text{'sched_enabled'},
		    &ui_radio("enabled", $job ? 1 : 0,
			      [ [ 0, $text{'no'} ],
				[ 1, $text{'sched_at'} ] ]));

print "<tr> <td colspan=2><table border width=100%>\n";
$job ||= { 'mins' => 0,
	   'hours' => 0,
	   'days' => '*',
	   'months' => '*',
	   'weekdays' => '*' };
&cron::show_times_input($job);
print "</table></td> </tr>\n";

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
