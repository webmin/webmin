
do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
&foreign_require("servers", "servers-lib.pl");
%access = &get_module_acl();

$cron_cmd = "$module_config_directory/check.pl";

sub find_cron_job
{
&foreign_require("cron", "cron-lib.pl");
local ($job) = grep { $_->{'command'} eq $cron_cmd } &cron::list_cron_jobs();
return $job;
}

# get_all_statuses(&servers)
# Returns a hash mapping servers to their statuses. The possible values are:
# 0 = down
# 1 = up
# 2 = up but login is not possible
# 3 = up but login failed
sub get_all_statuses
{
# Check which ones are up, in parallel
my ($servers) = @_;
my %pid;
foreach my $s (@$servers) {
	my $pid;
	if (!($pid = fork())) {
		my $out = `ping -c 1 -w 1 $s->{'host'} 2>&1`;
		if ($config{'login'} && !$?) {
			# Attempt a Webmin login too
			if (!$s->{'user'}) {
				exit(101);
				}
			local $err = &servers::test_server($s->{'host'});
			exit($err ? 102 : 0);
			}
		exit($? ? 1 : 0);
		}
	$pid{$s} = $pid;
	}
my %up;
foreach my $s (@$servers) {
	my $pid = waitpid($pid{$s}, 0);
	$up{$s} = $? == 0 ? 1 :
		  $?/256 == 101 ? 2 :
		  $?/256 == 102 ? 3 : 0;
	}
return %up;
}

1;

