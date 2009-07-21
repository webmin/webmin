# uninstall.pl
# Called when webmin is uninstalled

require 'fsdump-lib.pl';

sub module_uninstall
{
&foreign_require("cron", "cron-lib.pl");
@jobs = &cron::list_cron_jobs();
foreach $j (sort { $b->{'line'} <=> $a->{'line'} } @jobs) {
	if ($j->{'command'} =~ /^$cron_cmd\s+/) {
		# Cancel this cron job
		&cron::delete_cron_job($j);
		}
	}
}

1;

