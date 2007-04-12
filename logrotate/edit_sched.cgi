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
	print "<form action=save_sched.cgi>\n";
	print "<input type=hidden name=idx value='",
		$job ? $job->{'index'} : "","'>\n";
	print "<b>$text{'sched_sched'}</b>\n";
	printf "<input type=radio name=sched value=0 %s> %s\n",
		$job ? "" : "checked", $text{'sched_disabled'};
	printf "<input type=radio name=sched value=1 %s> %s<br>\n",
		$job ? "checked" : "", $text{'sched_enabled'};

	$job ||= { 'special' => 'daily' };
	print "<table border>\n";
	&cron::show_times_input($job);
	print "</table>\n";
	print "<input type=submit value='$text{'sched_save'}'></form>\n";
	}

&ui_print_footer("", $text{'index_return'});
