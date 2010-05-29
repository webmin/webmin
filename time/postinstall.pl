
require 'time-lib.pl';

# Convert existing cron job to webmin cron
sub module_install
{
&foreign_require("cron", "cron-lib.pl");
local $job = &find_cron_job();
if ($job) {
	&foreign_require("webmincron");
	$wcron = { 'module' => $module_name,
		   'func' => 'sync_time_cron',
		   'special' => $job->{'special'},
		   'mins' => $job->{'mins'},
		   'hours' => $job->{'hours'},
		   'days' => $job->{'days'},
		   'months' => $job->{'months'},
		   'weekdays' => $job->{'weekdays'},
		};
	&webmincron::create_webmin_cron($wcron, $job->{'command'});
	}
}

