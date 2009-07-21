# uninstall.pl
# Called when webmin is uninstalled

require 'status-lib.pl';

sub module_uninstall
{
if ($config{'sched_mode'}) {
	# Scheduled checking is enabled .. remove the cron job
	&foreign_require("cron");
	$cron_cmd = "$module_config_directory/monitor.pl";
	foreach $j (&cron::list_cron_jobs()) {
		if ($j->{'user'} eq 'root' &&
		    $j->{'command'} eq $cron_cmd) {
			&cron::delete_cron_job($j);
			last;
			}
		}
	}
}

1;

