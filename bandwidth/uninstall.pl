# uninstall.pl
# Called when webmin is uninstalled

require 'bandwidth-lib.pl';

sub module_uninstall
{
local $job = &find_cron_job();
if ($job) {
	&lock_file(&cron::cron_file($job));
	&cron::delete_cron_job($job);
	&unlock_file(&cron::cron_file($job));
	}
}

1;

