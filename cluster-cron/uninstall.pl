# uninstall.pl
# Called when webmin is uninstalled

require 'cluster-cron-lib.pl';

sub module_uninstall
{
@jobs = &list_cluster_jobs();
foreach $j (sort { $b->{'line'} <=> $a->{'line'} } @jobs) {
	&delete_cluster_job($j);
	}
}

1;

