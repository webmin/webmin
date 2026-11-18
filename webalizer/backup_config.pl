
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, $module_config_directory, $cron_cmd, %config);
do 'webalizer-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
my @rv = ( $config{'webalizer_conf'} );
my $fh;
opendir($fh, $module_config_directory);
while(my $f = readdir($fh)) {
	if ($f =~ /\.conf$/ || $f =~ /\.log$/) {
		push(@rv, "$module_config_directory/$f");
		}
	}
closedir($fh);
return @rv;
}

# pre_backup(&files)
# Called before the files are actually read
sub pre_backup
{
return undef;
}

# post_backup(&files)
# Called after the files are actually read
sub post_backup
{
return undef;
}

# pre_restore(&files)
# Called before the files are restored from a backup
sub pre_restore
{
return undef;
}

# post_restore(&files)
# Restores scheduled jobs after a backup restore. The file list is unused.
sub post_restore
{
# Match both plain and quoted commands from earlier versions.
&foreign_require("cron", "cron-lib.pl");
my @jobs = &cron::list_cron_jobs();
foreach my $log (&get_all_logs()) {
	my $lconf = &get_log_config($log->{'file'});
	if ($lconf->{'sched'}) {
		# Restore only logs with scheduled reporting enabled.
		my $command = &cron_log_command($log->{'file'});
		my ($job) = grep {
			$_->{'command'} eq "$cron_cmd $log->{'file'}" ||
			$_->{'command'} eq
			  $cron_cmd." ".quotemeta($log->{'file'}) } @jobs;
		if (!$job) {
			# Create a missing job with the restored schedule.
			$job->{'user'} = 'root';
			$job->{'active'} = 1;
			$job->{'special'} = $lconf->{'special'};
			$job->{'mins'} = $lconf->{'mins'};
			$job->{'hours'} = $lconf->{'hours'};
			$job->{'days'} = $lconf->{'days'};
			$job->{'months'} = $lconf->{'months'};
			$job->{'weekdays'} = $lconf->{'weekdays'};
			$job->{'command'} = $command;
			&cron::create_cron_job($job);
			}
		elsif ($job->{'command'} ne $command) {
			# Update quoting while keeping the existing schedule.
			&lock_file(&cron::cron_file($job));
			$job->{'command'} = $command;
			&cron::change_cron_job($job);
			&unlock_file(&cron::cron_file($job));
			}
		}
	}
return undef;
}

1;

