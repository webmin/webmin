# uninstall.pl
# Called when webmin is uninstalled

require 'quota-lib.pl';

sub module_uninstall
{
&foreign_require("cron", "cron-lib.pl");
local $job = &find_email_job();
if ($job) {
	&cron::delete_cron_job($job);
	}
}

1;

