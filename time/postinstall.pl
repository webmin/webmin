
use strict;
use warnings;
require 'time-lib.pl';
our ($module_name);

# Convert existing cron job to webmin cron
sub module_install
{
if (&foreign_check("cron")) {
	&foreign_require("cron");
	my $job = &find_cron_job();
	if ($job) {
		my $wcron = { 'module' => $module_name,
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
}

