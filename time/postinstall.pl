
require 'time-lib.pl';

# Change time sync jobs running at midnight to a random time, to stop
# overloading public NTP servers
sub module_install
{
&foreign_require("cron", "cron-lib.pl");
local $job = &find_cron_job();
if ($job && $job->{'mins'} eq '0' && $job->{'hours'} eq '0') {
	# Midnight .. fix it
	&seed_random();
	$job->{'mins'} = int(rand()*60);
	$job->{'hours'} = int(rand()*24);
	&cron::change_cron_job($job);
	}
}

