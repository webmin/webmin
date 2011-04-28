# uninstall.pl
# Called when webmin is uninstalled

use strict;
use warnings;
require 'servers-lib.pl';

sub module_uninstall
{
my $job = &find_cron_job();
if ($job) {
	&cron::delete_cron_job($job);
	}
}

1;

