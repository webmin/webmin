
use strict;
use warnings;
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
# Called after the files are restored from a backup
sub post_restore
{
# Re-setup all needed cron jobs
&foreign_require("cron", "cron-lib.pl");
my @jobs = &cron::list_cron_jobs();
foreach my $log (&get_all_logs()) {
	my $lconf = &get_log_config($log->{'file'});
	if ($lconf->{'sched'}) {
		my ($job) = grep { $_->{'command'} eq
				   "$cron_cmd $log->{'file'}" } @jobs;
		if (!$job) {
			# Need to create!
			$job->{'user'} = 'root';
			$job->{'active'} = 1;
			$job->{'special'} = $lconf->{'special'};
			$job->{'mins'} = $lconf->{'mins'};
			$job->{'hours'} = $lconf->{'hours'};
			$job->{'days'} = $lconf->{'days'};
			$job->{'months'} = $lconf->{'months'};
			$job->{'weekdays'} = $lconf->{'weekdays'};
			$job->{'command'} = "$cron_cmd $log->{'file'}";
			&cron::create_cron_job($job);
			}
		}
	}
return undef;
}

1;

