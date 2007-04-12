# uninstall.pl
# Called when webmin is uninstalled

require 'cluster-copy-lib.pl';

sub module_uninstall
{
foreach $copy (&list_copies()) {
	$job = &find_cron_job($copy);
	if ($job) {
		&cron::delete_cron_job($job);
		}
	}
}

1;

