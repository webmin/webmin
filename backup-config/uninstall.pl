# uninstall.pl
# Called when webmin is uninstalled

require 'backup-config-lib.pl';

sub module_uninstall
{
foreach $backup (&list_backups()) {
	$job = &find_cron_job($backup);
	if ($job) {
		&cron::delete_cron_job($job);
		}
	}
}

1;

