# uninstall.pl
# Called when webmin is uninstalled

require 'time-lib.pl';

sub module_uninstall
{
# Remove the cron job for scheduled checking
&foreign_require("cron", "cron-lib.pl");
$job = &find_cron_job();
if ($job) {
	&cron::delete_cron_job($job);
	}
}

1;

