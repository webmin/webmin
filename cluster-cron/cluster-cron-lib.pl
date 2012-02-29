# cluster-cron-lib.pl
# XXX environment variables??
#	XXX create script to run, which sets vars and includes input as << ?

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("cron", "cron-lib.pl");
&foreign_require("servers", "servers-lib.pl");

$cluster_cron_cmd = "$module_config_directory/cron.pl";
$jobs_directory = "$module_config_directory/jobs";

# list_cluster_jobs()
# Returns an array of cron jobs that are run on multiple servers
sub list_cluster_jobs
{
local @rv;
foreach $j (&cron::list_cron_jobs()) {
	if ($j->{'user'} eq 'root' &&
	    $j->{'command'} =~ /^$cluster_cron_cmd\s+(\S+)$/) {
		$j->{'cluster_id'} = $1;
		&read_file("$jobs_directory/$1", $j) || next;
		push(@rv, $j);
		}
	}
return @rv;
}

# create_cluster_job(&job)
# Create a new cluster cron job
sub create_cluster_job
{
mkdir($jobs_directory, 0700);
&lock_file("$jobs_directory/$_[0]->{'cluster_id'}");
&write_file("$jobs_directory/$_[0]->{'cluster_id'}", &cluster_params($_[0]));
&unlock_file("$jobs_directory/$_[0]->{'cluster_id'}");
&lock_file("$cron::config{'cron_dir'}/$_[0]->{'user'}");
&cron::create_cron_job($_[0]);
&unlock_file("$cron::config{'cron_dir'}/$_[0]->{'user'}");
}

# modify_cluster_job(&job)
# Update an existing cluster cron job
sub modify_cluster_job
{
&lock_file("$jobs_directory/$_[0]->{'cluster_id'}");
&write_file("$jobs_directory/$_[0]->{'cluster_id'}", &cluster_params($_[0]));
&unlock_file("$jobs_directory/$_[0]->{'cluster_id'}");
&lock_file($_[0]->{'file'});
&cron::change_cron_job($_[0]);
&unlock_file($_[0]->{'file'});
}

# delete_cluster_job(&job)
sub delete_cluster_job
{
&lock_file("$jobs_directory/$_[0]->{'cluster_id'}");
unlink("$jobs_directory/$_[0]->{'cluster_id'}");
&unlock_file("$jobs_directory/$_[0]->{'cluster_id'}");
&lock_file($_[0]->{'file'});
&cron::delete_cron_job($_[0]);
&unlock_file($_[0]->{'file'});
}

sub cluster_params
{
local %rv;
foreach $k (keys %{$_[0]}) {
	$rv{$k} = $_[0]->{$k} if ($k =~ /^cluster_/);
	}
return \%rv;
}

# run_cluster_job(&job, &callback)
# Runs a cluster cron job on all configured servers, and for each result calls
# the callback function with parameters 0/1, a server object, and the output
# or error message
sub run_cluster_job
{
local @rv;
local $func = $_[1];

# Work out which servers to run on
local @servers = &servers::list_servers_sorted();
local @groups = &servers::list_all_groups(\@servers);
local @run;
foreach $s (split(/\s+/, $_[0]->{'cluster_server'})) {
	if ($s =~ /^group_(.*)$/) {
		# All members of a group
		($group) = grep { $_->{'name'} eq $1 } @groups;
		foreach $m (@{$group->{'members'}}) {
			push(@run, grep { $_->{'host'} eq $m && $_->{'user'} }
					@servers);
			}
		}
	elsif ($s eq '*') {
		# This server
		push(@run, ( { 'desc' => $text{'edit_this'} } ));
		}
	elsif ($s eq 'ALL') {
		# All servers with users
		push(@run, grep { $_->{'user'} } @servers);
		}
	else {
		# A single remote server
		push(@run, grep { $_->{'host'} eq $s } @servers);
		}
	}
@run = &unique(@run);

# Setup error handler for down hosts
sub inst_error
{
$inst_error_msg = join("", @_);
}
&remote_error_setup(\&inst_error);

# Create a local temp file containing input
local $ltemp = &transname();
open(TEMP, ">$ltemp");
local $inp = $_[0]->{'cluster_input'};
$inp =~ s/\\%/\0/g;
@lines = split(/%/, $inp);
foreach $l (@lines) {
	$l =~ s/\0/%/g;
	print TEMP $l,"\n";
	}
close(TEMP);

# Run one each one in parallel and display the output
$p = 0;
foreach $s (@run) {
	local ($rh = "READ$p", $wh = "WRITE$p");
	pipe($rh, $wh);
	select($wh); $| = 1; select(STDOUT);
	if (!fork()) {
		# Run the command in a subprocess
		close($rh);

		&remote_foreign_require($s->{'host'}, "webmin",
					"webmin-lib.pl");
		if ($inst_error_msg) {
			# Failed to contact host ..
			print $wh &serialise_variable([ 0, $inst_error_msg ]);
			exit;
			}

		# Send any input to a temp file
		local $rtemp = &remote_write($s->{'host'}, $ltemp);

		# Run the command and capture output
		local $q = quotemeta($_[0]->{'cluster_command'});
		local $rv;
		if ($_[0]->{'cluster_user'} eq 'root') {
			$rv = &remote_eval($s->{'host'}, "webmin",
			    "\$x=&backquote_command('($_[0]->{'cluster_command'}) <$rtemp 2>&1')");
			}
		else {
			$q = quotemeta($q);
			$rv = &remote_eval($s->{'host'}, "webmin",
			    "\$x=&backquote_command(&command_as_user('$_[0]->{'cluster_user'}', 0, '$_[0]->{'cluster_command'}').' <$rtemp 2>&1')");
			}
		&remote_eval($s->{'host'}, "webmin", "unlink('$rtemp')");

		print $wh &serialise_variable([ 1, $rv ]);
		close($wh);
		exit;
		}
	close($wh);
	$p++;
	}

# Get back all the results
$p = 0;
foreach $s (@run) {
	local $rh = "READ$p";
	local $line = <$rh>;
	close($rh);
	local $rv = &unserialise_variable($line);

	if (!$line) {
		&$func(0, $s, "Unknown reason");
		}
	else {
		&$func($rv->[0], $s, $rv->[1]);
		}
	$p++;
	}
unlink($ltemp);
return @run;
}

1;

