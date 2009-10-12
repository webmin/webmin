
require 'cron-lib.pl';

sub module_install
{
# Create a cron job to delete old files in /tmp/.webmin
eval {
	$main::error_must_die = 1;
	local @jobs = &list_cron_jobs();
	local ($job) = grep { $_->{'user'} eq 'root' &&
			      $_->{'command'} eq $temp_delete_cmd } @jobs;
	if (!$job) {
		$job = { 'user' => 'root',
			 'active' => 1,
			 'command' => $temp_delete_cmd,
			 'mins' => int(rand()*60),
			 'hours' => int(rand()*24),
			 'days' => '*',
			 'months' => '*',
			 'weekdays' => '*',
			 'comment' => 'Delete Webmin temporary files' };
		&unconvert_comment($job);
		&create_cron_job($job);
		&create_wrapper($temp_delete_cmd, $module_name,"tempdelete.pl");
		}
	};
if ($@) {
	print STDERR "Failed to setup /tmp cleanup cron job : $@\n";
	}
}


