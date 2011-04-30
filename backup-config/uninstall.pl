# uninstall.pl
# Called when webmin is uninstalled

use strict;
use warnings;
require 'backup-config-lib.pl';

sub module_uninstall
{
foreach my $backup (&list_backups()) {
	my $job = &find_cron_job($backup);
	if ($job) {
		&cron::delete_cron_job($job);
		}
	}
}

1;

