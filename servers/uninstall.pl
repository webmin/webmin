# uninstall.pl
# Called when webmin is uninstalled

require 'servers-lib.pl';

sub module_uninstall
{
local $job = &find_cron_job();
if ($job) {
	&cron::delete_cron_job($job);
	}
}

1;

