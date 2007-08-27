
require 'cron-lib.pl';

sub module_uninstall
{
# Remove the cron job to delete old files in /tmp/.webmin
eval {
	$main::error_must_die = 1;
	local @jobs = &cron::list_cron_jobs();
	local ($job) = grep { $_->{'user'} eq 'root' &&
			      $_->{'command'} eq $temp_delete_cmd } @jobs;
	if ($job) {
		&delete_cron_job($job);
		}
	};
if ($@) {
	print STDERR "Failed to remove /tmp cleanup cron job : $@\n";
	}
}


