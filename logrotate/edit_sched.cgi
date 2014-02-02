#!/usr/local/bin/perl
# edit_sched.cgi
# Find the logrotate cron job, or offer to create one

require './logrotate-lib.pl';
&ui_print_header(undef, $text{'sched_title'}, "");

print "<p>",&text('sched_desc', "<tt>$config{'logrotate'}</tt>"),"<p>\n";

# Find the job, looking in daily directories too
&foreign_require("cron", "cron-lib.pl");
@jobs = &cron::list_cron_jobs();
JOB: foreach $j (@jobs) {
	if ($j->{'command'} =~ /logrotate/i) {
		$job = $j;
		last JOB;
		}
	local $rpd = &cron::is_run_parts($j->{'command'});
	if ($rpd) {
		local @exp = &cron::expand_run_parts($rpd);
		foreach $e (@exp) {
			if ($e =~ /logrotate/i && -r $e) {
				$job = $j;
				$runparts = $e;
				last JOB;
				}
			}
		}
	}

if ($runparts) {
	# Run from run-parts command, cannot touch
	print &text('sched_runparts', "<tt>$runparts</tt>",
		    &cron::when_text($job)),"<p>\n";
	}
else {
	# Offer to enable/change/delete
	print &ui_form_start("save_sched.cgi", "post");
	print &ui_hidden("idx", $job ? $job->{'index'} : "");
	print &ui_table_start(undef, undef, 2);

	print &ui_table_row($text{'sched_sched'},
		&ui_radio("sched", $job ? 1 : 0,
			  [ [ 0, $text{'sched_disabled'} ],
			    [ 1, $text{'sched_enabled'} ] ]));

	$job ||= { 'special' => 'daily' };
	print &cron::get_times_input($job, 0, 2, $text{'sched_when'});

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'sched_save'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});
