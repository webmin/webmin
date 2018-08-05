=head1 cron-lib.pl

Functions for listing, creating and managing Unix users' cron jobs.

 foreign_require("cron", "cron-lib.pl");
 @jobs = cron::list_cron_jobs();
 $job = { 'user' => 'root',
          'active' => 1,
          'command' => 'ls -l >/dev/null',
          'special' => 'hourly' };
 cron::create_cron_job($job);

=cut

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
$env_support = $config{'vixie_cron'};
if ($module_info{'usermin'}) {
	$single_user = $remote_user;
	&switch_to_remote_user();
	&create_user_config_dirs();
	$range_cmd = "$user_module_config_directory/range.pl";
	$hourly_only = 0;
	}
else {
	$range_cmd = "$module_config_directory/range.pl";
	$hourly_only = $access{'hourly'} == 0 ? 0 :
		       $access{'hourly'} == 1 ? 1 :
			$config{'hourly_only'};
	}
$temp_delete_cmd = "$module_config_directory/tempdelete.pl";
$cron_temp_file = &transname();
use Time::Local;

=head2 list_cron_jobs

Returns a lists of structures of all cron jobs, each of which is a hash
reference with the following keys :

=item user - Unix user the job runs as.

=item command - The full command to be run.

=item active - Set to 0 if the job is commented out, 1 if active.

=item mins - Minute or comma-separated list of minutes the job will run, or * for all.

=item hours - Hour or comma-separated list of hours the job will run, or * for all.

=item days - Day or comma-separated list of days of the month the job will run, or * for all.

=item month - Month number or comma-separated list of months (started from 1) the job will run, or * for all.

=item weekday - Day of the week or comma-separated list of days (where 0 is sunday) the job will run, or * for all

=cut
sub list_cron_jobs
{
local (@rv, $lnum, $f);
if (scalar(@cron_jobs_cache)) {
	return @cron_jobs_cache;
	}

# read the master crontab file
if ($config{'system_crontab'}) {
	$lnum = 0;
	&open_readfile(TAB, $config{'system_crontab'});
	while(<TAB>) {
		# Comment line in Fedora 13
		next if (/^#+\s+\*\s+\*\s+\*\s+\*\s+\*\s+(user-name\s+)?command\s+to\s+be\s+executed/);

		if (/^(#+)?[\s\&]*(-)?\s*([0-9\-\*\/,]+)\s+([0-9\-\*\/,]+)\s+([0-9\-\*\/,]+)\s+(([0-9\-\*\/]+|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|,)+)\s+(([0-9\-\*\/]+|sun|mon|tue|wed|thu|fri|sat|,)+)\s+(\S+)\s+(.*)/i) {
			# A normal h m s d w time
			push(@rv, { 'file' => $config{'system_crontab'},
				    'line' => $lnum,
				    'type' => 1,
				    'nolog' => $2,
				    'active' => !$1,
				    'mins' => $3, 'hours' => $4,
				    'days' => $5, 'months' => $6,
				    'weekdays' => $8, 'user' => $10,
				    'command' => $11,
				    'index' => scalar(@rv) });
			if ($rv[$#rv]->{'user'} =~ /^\//) {
				# missing the user, as in redhat 7 !
				$rv[$#rv]->{'command'} = $rv[$#rv]->{'user'}.
					' '.$rv[$#rv]->{'command'};
				$rv[$#rv]->{'user'} = 'root';
				}
			&fix_names($rv[$#rv]);
			}
		elsif (/^(#+)?\s*@([a-z]+)\s+(\S+)\s+(.*)/i) {
			# An @ time
			push(@rv, { 'file' => $config{'system_crontab'},
				    'line' => $lnum,
				    'type' => 1,
				    'active' => !$1,
				    'special' => $2,
				    'user' => $3,
				    'command' => $4,
				    'index' => scalar(@rv) });
			}
		$lnum++;
		}
	close(TAB);
	}

# read package-specific cron files
opendir(DIR, &translate_filename($config{'cronfiles_dir'}));
while($f = readdir(DIR)) {
	next if ($f =~ /^\./);
	$lnum = 0;
	&open_readfile(TAB, "$config{'cronfiles_dir'}/$f");
	while(<TAB>) {
		if (/^(#+)?[\s\&]*(-)?\s*([0-9\-\*\/,]+)\s+([0-9\-\*\/,]+)\s+([0-9\-\*\/,]+)\s+(([0-9\-\*\/]+|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|,)+)\s+(([0-9\-\*\/]+|sun|mon|tue|wed|thu|fri|sat|,)+)\s+(\S+)\s+(.*)/i) {
			push(@rv, { 'file' => "$config{'cronfiles_dir'}/$f",
				    'line' => $lnum,
				    'type' => 2,
				    'active' => !$1,
				    'nolog' => $2,
				    'mins' => $3, 'hours' => $4,
				    'days' => $5, 'months' => $6,
				    'weekdays' => $8, 'user' => $10,
				    'command' => $11,
				    'index' => scalar(@rv) });
			&fix_names($rv[$#rv]);
			}
		elsif (/^(#+)?\s*@([a-z]+)\s+(\S+)\s+(.*)/i) {
			push(@rv, { 'file' => "$config{'cronfiles_dir'}/$f",
				    'line' => $lnum,
				    'type' => 2,
				    'active' => !$1,
				    'special' => $2,
				    'user' => $3,
				    'command' => $4,
				    'index' => scalar(@rv) });
			}
		$lnum++;
		}
	close(TAB);
	}
closedir(DIR);

# Read a single user's crontab file
if ($config{'single_file'}) {
	&open_readfile(TAB, $config{'single_file'});
	$lnum = 0;
	while(<TAB>) {
		if (/^(#+)?[\s\&]*(-)?\s*([0-9\-\*\/,]+)\s+([0-9\-\*\/,]+)\s+([0-9\-\*\/,]+)\s+(([0-9\-\*\/]+|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|,)+)\s+(([0-9\-\*\/]+|sun|mon|tue|wed|thu|fri|sat|,)+)\s+(.*)/i) {
			# A normal m h d m wd time
			push(@rv, { 'file' => $config{'single_file'},
				    'line' => $lnum,
				    'type' => 3,
				    'active' => !$1, 'nolog' => $2,
				    'mins' => $3, 'hours' => $4,
				    'days' => $5, 'months' => $6,
				    'weekdays' => $8, 'user' => "NONE",
				    'command' => $10,
				    'index' => scalar(@rv) });
			&fix_names($rv[$#rv]);
			}
		elsif (/^(#+)?\s*([a-zA-Z0-9\_]+)\s*=\s*'([^']*)'/ ||
		       /^(#+)?\s*([a-zA-Z0-9\_]+)\s*=\s*"([^']*)"/ ||
		       /^(#+)?\s*([a-zA-Z0-9\_]+)\s*=\s*(\S+)/) {
			# An environment variable
			push(@rv, { 'file' => $config{'single_file'},
				    'line' => $lnum,
				    'active' => !$1,
				    'name' => $2,
				    'value' => $3,
				    'user' => "NONE",
				    'command' => '',
				    'index' => scalar(@rv) });
			}
		$lnum++;
		}
	close(TAB);
	}


# read per-user cron files
local $fcron = ($config{'cron_dir'} =~ /\/fcron$/);
local @users;
if ($single_user) {
	@users = ( $single_user );
	}
else {
	opendir(DIR, &translate_filename($config{'cron_dir'}));
	@users = grep { !/^\./ } readdir(DIR);
	closedir(DIR);
	}
foreach $f (@users) {
	next if (!(@uinfo = getpwnam($f)));
	$lnum = 0;
	if ($single_user) {
		&open_execute_command(TAB, $config{'cron_user_get_command'}, 1);
		}
	elsif ($fcron) {
		&open_execute_command(TAB,
			&user_sub($config{'cron_get_command'}, $f), 1);
		}
	else {
		&open_readfile(TAB, "$config{'cron_dir'}/$f");
		}
	while(<TAB>) {
		if (/^(#+)?[\s\&]*(-)?\s*([0-9\-\*\/,]+)\s+([0-9\-\*\/,]+)\s+([0-9\-\*\/,]+)\s+(([0-9\-\*\/]+|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|,)+)\s+(([0-9\-\*\/]+|sun|mon|tue|wed|thu|fri|sat|,)+)\s+(.*)/i) {
			# A normal m h d m wd time
			push(@rv, { 'file' => "$config{'cron_dir'}/$f",
				    'line' => $lnum,
				    'type' => 0,
				    'active' => !$1, 'nolog' => $2,
				    'mins' => $3, 'hours' => $4,
				    'days' => $5, 'months' => $6,
				    'weekdays' => $8, 'user' => $f,
				    'command' => $10,
				    'index' => scalar(@rv) });
			$rv[$#rv]->{'file'} =~ s/\s+\|$//;
			&fix_names($rv[$#rv]);
			}
		elsif (/^(#+)?\s*@([a-z]+)\s+(.*)/i) {
			# An @ time
			push(@rv, { 'file' => "$config{'cron_dir'}/$f",
				    'line' => $lnum,
				    'type' => 0,
				    'active' => !$1,
				    'special' => $2,
				    'user' => $f,
				    'command' => $3,
				    'index' => scalar(@rv) });
			}
		elsif (/^(#+)?\s*([a-zA-Z0-9\_]+)\s*=\s*'([^']*)'/ ||
		       /^(#+)?\s*([a-zA-Z0-9\_]+)\s*=\s*"([^']*)"/ ||
		       /^(#+)?\s*([a-zA-Z0-9\_]+)\s*=\s*(\S+)/) {
			# An environment variable
			push(@rv, { 'file' => "$config{'cron_dir'}/$f",
				    'line' => $lnum,
				    'active' => !$1,
				    'name' => $2,
				    'value' => $3,
				    'user' => $f,
				    'index' => scalar(@rv) });
			}
		$lnum++;
		}
	close(TAB);
	}
closedir(DIR);
@cron_jobs_cache = @rv;
return @cron_jobs_cache;
}

=head2 cron_job_line(&job)

Internal function to generate a crontab format line for a cron job.

=cut
sub cron_job_line
{
local @c;
push(@c, "#") if (!$_[0]->{'active'});
if ($_[0]->{'name'}) {
	push(@c, $_[0]->{'name'});
	push(@c, "=");
	push(@c, $_[0]->{'value'} =~ /'/ ? "\"$_[0]->{'value'}\"" :
		 $_[0]->{'value'} =~ /"/ ? "'$_[0]->{'value'}'" :
		 $_[0]->{'value'} !~ /^\S+$/ ? "\"$_[0]->{'value'}\""
					  : $_[0]->{'value'});
	}
else {
	if ($_[0]->{'special'}) {
		push(@c, ($_[0]->{'nolog'} ? '-' : '').'@'.$_[0]->{'special'});
		}
	else {
		push(@c, ($_[0]->{'nolog'} ? '-' : '').$_[0]->{'mins'},
			 $_[0]->{'hours'}, $_[0]->{'days'},
			 $_[0]->{'months'}, $_[0]->{'weekdays'});
		}
	push(@c, $_[0]->{'user'}) if ($_[0]->{'type'} != 0 &&
				      $_[0]->{'type'} != 3);
	push(@c, $_[0]->{'command'});
	}
if ($gconfig{'os_type'} eq 'syno-linux') {
	return join("\t", @c);
	}
else {
	return join(" ", @c);
	}
}

=head2 copy_cron_temp(&job)

Copies a job's user's current cron configuration to the temp file. For internal
use only.

=cut
sub copy_cron_temp
{
local $fcron = ($config{'cron_dir'} =~ /\/fcron$/);
unlink($cron_temp_file);
if ($single_user) {
	&execute_command($config{'cron_user_get_command'},
			 undef, $cron_temp_file, undef);
	}
elsif ($fcron) {
	&execute_command(&user_sub($config{'cron_get_command'},$_[0]->{'user'}),
			 undef, $cron_temp_file, undef);
	}
else {
	system("cp ".&translate_filename("$config{'cron_dir'}/$_[0]->{'user'}").
	       " $cron_temp_file 2>/dev/null");
	}
}

=head2 create_cron_job(&job)

Add a Cron job to a user's file. The job parameter must be a hash reference
in the same format as returned by list_cron_jobs.

=cut
sub create_cron_job
{
&check_cron_config_or_error();
&list_cron_jobs();	# init cache
if ($config{'add_file'}) {
	# Add to a specific file, typically something like /etc/cron.d/webmin
	$_[0]->{'type'} = 1;
	local $lref = &read_file_lines($config{'add_file'});
	push(@$lref, &cron_job_line($_[0]));
	&flush_file_lines($config{'add_file'});
	}
elsif ($config{'single_file'} && !$config{'cron_dir'}) {
	# Add to the single file
	$_[0]->{'type'} = 3;
	local $lref = &read_file_lines($config{'single_file'});
	push(@$lref, &cron_job_line($_[0]));
	&flush_file_lines($config{'single_file'});
	}
else {
	# Add to the specified user's crontab
	&copy_cron_temp($_[0]);
	local $lref = &read_file_lines($cron_temp_file);
	$_[0]->{'line'} = scalar(@$lref);
	push(@$lref, &cron_job_line($_[0]));
	&flush_file_lines($cron_temp_file);
	&set_ownership_permissions($_[0]->{'user'}, undef, undef,
				   $cron_temp_file);
	&copy_crontab($_[0]->{'user'});
	$_[0]->{'file'} = "$config{'cron_dir'}/$_[0]->{'user'}";
	$_[0]->{'index'} = scalar(@cron_jobs_cache);
	push(@cron_jobs_cache, $_[0]);
	}
}

=head2 insert_cron_job(&job)

Add a Cron job at the top of the user's file. The job parameter must be a hash
reference in the same format as returned by list_cron_jobs.

=cut
sub insert_cron_job
{
&check_cron_config_or_error();
&list_cron_jobs();	# init cache
if ($config{'single_file'} && !$config{'cron_dir'}) {
	# Insert into single file
	$_[0]->{'type'} = 3;
	local $lref = &read_file_lines($config{'single_file'});
	splice(@$lref, 0, 0, &cron_job_line($_[0]));
	&flush_file_lines($config{'single_file'});
	}
else {
	# Insert into the user's crontab
	&copy_cron_temp($_[0]);
	local $lref = &read_file_lines($cron_temp_file);
	$_[0]->{'line'} = 0;
	splice(@$lref, 0, 0, &cron_job_line($_[0]));
	&flush_file_lines();
	system("chown $_[0]->{'user'} $cron_temp_file");
	&copy_crontab($_[0]->{'user'});
	$_[0]->{'file'} = "$config{'cron_dir'}/$_[0]->{'user'}";
	$_[0]->{'index'} = scalar(@cron_jobs_cache);
	&renumber($_[0]->{'file'}, $_[0]->{'line'}, 1);
	push(@cron_jobs_cache, $_[0]);
	}
}

=head2 renumber(file, line, offset)

All jobs in this file whose line is at or after the given one will be
incremented by the offset. For internal use.

=cut
sub renumber
{
local $j;
foreach $j (@cron_jobs_cache) {
	if ($j->{'line'} >= $_[1] &&
	    $j->{'file'} eq $_[0]) {
		$j->{'line'} += $_[2];
		}
	}
}

=head2 renumber_index(index, offset)

Internal function to change the index of all cron jobs in the cache after
some index by a given offset. For internal use.

=cut
sub renumber_index
{
local $j;
foreach $j (@cron_jobs_cache) {
	if ($j->{'index'} >= $_[0]) {
		$j->{'index'} += $_[1];
		}
	}
}

=head2 change_cron_job(&job)

Updates the given cron job, which must be a hash ref returned by list_cron_jobs
and modified with a new active flag, command or schedule.

=cut
sub change_cron_job
{
if ($_[0]->{'type'} == 0) {
	&copy_cron_temp($_[0]);
	&replace_file_line($cron_temp_file, $_[0]->{'line'},
			   &cron_job_line($_[0])."\n");
	&copy_crontab($_[0]->{'user'});
	}
else {
	&replace_file_line($_[0]->{'file'}, $_[0]->{'line'},
			   &cron_job_line($_[0])."\n");
	}
}

=head2 delete_cron_job(&job)

Removes the cron job defined by the given hash ref, as returned by
list_cron_jobs.

=cut
sub delete_cron_job
{
if ($_[0]->{'type'} == 0) {
	&copy_cron_temp($_[0]);
	&replace_file_line($cron_temp_file, $_[0]->{'line'});
	&copy_crontab($_[0]->{'user'});
	}
else {
	&replace_file_line($_[0]->{'file'}, $_[0]->{'line'});
	}
@cron_jobs_cache = grep { $_ ne $_[0] } @cron_jobs_cache;
&renumber($_[0]->{'file'}, $_[0]->{'line'}, -1);
&renumber_index($_[0]->{'index'}, -1);
}

=head2 read_crontab(user)

Return an array containing the lines of the cron table for some user. For
internal use mainly.

=cut
sub read_crontab
{
local(@tab);
&open_readfile(TAB, "$config{cron_dir}/$_[0]");
@tab = <TAB>;
close(TAB);
if (@tab >= 3 && $tab[0] =~ /DO NOT EDIT/ &&
    $tab[1] =~ /^\s*#/ && $tab[2] =~ /^\s*#/) {
	@tab = @tab[3..$#tab];
	}
return @tab;
}

=head2 copy_crontab(user)

Copy the cron temp file to that for this user. For internal use only.

=cut
sub copy_crontab
{
if (&is_readonly_mode()) {
	# Do nothing
	return undef;
	}
local($pwd);
if (&read_file_contents($cron_temp_file) =~ /\S/) {
	local $temp = &transname();
	local $rv;
	if (!&has_crontab_cmd()) {
		# We have no crontab command .. emulate by copying to user file
		$rv = system("cat $cron_temp_file".
			" >$config{'cron_dir'}/$_[0] 2>/dev/null");
		&set_ownership_permissions($_[0], undef, 0600,
			"$config{'cron_dir'}/$_[0]");
		}
	elsif ($config{'cron_edit_command'}) {
		# fake being an editor
		local $notemp = &transname();
		&open_tempfile(NO, ">$notemp");
		&print_tempfile(NO, "No\n");
		&print_tempfile(NO, "N\n");
		&print_tempfile(NO, "no\n");
		&close_tempfile(NO);
		$ENV{"VISUAL"} = $ENV{"EDITOR"} =
			"$module_root_directory/cron_editor.pl";
		$ENV{"CRON_EDITOR_COPY"} = $cron_temp_file;
		system("chown $_[0] $cron_temp_file");
		local $oldpwd = &get_current_dir();
		chdir("/");
		if ($single_user) {
			$rv = system($config{'cron_user_edit_command'}.
				     " >$temp 2>&1 <$notemp");
			}
		else {
			$rv = system(
				&user_sub($config{'cron_edit_command'},$_[0]).
				" >$temp 2>&1 <$notemp");
			}
		unlink($notemp);
		chdir($oldpwd);

	} else {
		# use the cron copy command
		if ($single_user) {
			$rv = &execute_command(
				$config{'cron_user_copy_command'},
				$cron_temp_file, $temp, $temp);
			}
		else {
			$rv = &execute_command(
				&user_sub($config{'cron_copy_command'}, $_[0]),
				$cron_temp_file, $temp, $temp);
			}
	}
	local $out = &read_file_contents($temp);
	unlink($temp);
	if ($rv || $out =~ /error/i) {
		local $cronin = &read_file_contents($cron_temp_file);
		&error(&text('ecopy', "<pre>$out</pre>", "<pre>$cronin</pre>"));
		}
	}
else {
	# No more cron jobs left, so just delete
	if (!&has_crontab_cmd()) {
		# We have no crontab command .. emulate by deleting user crontab
		$_[0] || &error("No user given!");
		&unlink_logged("$config{'cron_dir'}/$_[0]");
		}
	else{
		if ($single_user) {
			&execute_command($config{'cron_user_delete_command'});
			}
		else {
			&execute_command(&user_sub(
				$config{'cron_delete_command'}, $_[0]));
			}
		}
	}
if (!&has_crontab_cmd()) {
	# to reload config
	&kill_byname("crond", "SIGHUP");
	}
unlink($cron_temp_file);
}


=head2 parse_job(job-line)

Parse a crontab line into an array containing:
active, mins, hrs, days, mons, weekdays, command

=cut
sub parse_job
{
local($job, $active) = ($_[0], 1);
if ($job =~ /^#+\s*(.*)$/) {
	$active = 0;
	$job = $1;
	}
$job =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)$/;
return ($active, $1, $2, $3, $4, $5, $6);
}

=head2 user_sub(command, user)

Replace the string 'USER' in the command with the user name. For internal
use only.

=cut
sub user_sub
{
local($tmp);
$tmp = $_[0];
$tmp =~ s/USER/$_[1]/g;
return $tmp;
}


=head2 list_allowed

Returns a list of all Unix usernames who are allowed to use Cron.

=cut
sub list_allowed
{
local(@rv, $_);
&open_readfile(ALLOW, $config{cron_allow_file});
while(<ALLOW>) {
	next if (/^\s*#/);
	chop; push(@rv, $_) if (/\S/);
	}
close(ALLOW);
return @rv;
}


=head2 list_denied

Return a list of all Unix usernames who are not allowed to use Cron.

=cut
sub list_denied
{
local(@rv, $_);
&open_readfile(DENY, $config{cron_deny_file});
while(<DENY>) {
	next if (/^\s*#/);
	chop; push(@rv, $_) if (/\S/);
	}
close(DENY);
return @rv;
}


=head2 save_allowed(user, user, ...)

Save the list of allowed Unix usernames.

=cut
sub save_allowed
{
local($_);
&open_tempfile(ALLOW, ">$config{cron_allow_file}");
foreach (@_) {
	&print_tempfile(ALLOW, $_,"\n");
	}
&close_tempfile(ALLOW);
chmod(0444, $config{cron_allow_file});
}


=head2 save_denied(user, user, ...)

Save the list of denied Unix usernames.

=cut
sub save_denied
{
local($_);
&open_tempfile(DENY, "> $config{cron_deny_file}");
foreach (@_) {
	&print_tempfile(DENY, $_,"\n");
	}
&close_tempfile(DENY);
chmod(0444, $config{cron_deny_file});
}

=head2 read_envs(user)

Returns an array of "name value" strings containing the environment settings
from the crontab for some user

=cut
sub read_envs
{
local(@tab, @rv, $_);
@tab = &read_crontab($_[0]);
foreach (@tab) {
	chop; s/#.*$//g;
	if (/^\s*(\S+)\s*=\s*(.*)$/) { push(@rv, "$1 $2"); }
	}
return @rv;
}

=head2 save_envs(user, [name, value]*)

Updates the cron file for some user with the given list of environment
variables. All others in the file are removed.

=cut
sub save_envs
{
local($i, @tab, $line);
@tab = &read_crontab($_[0]);
open(TAB, ">$cron_temp_file");
for($i=1; $i<@_; $i+=2) {
	print TAB "$_[$i]=$_[$i+1]\n";
	}
foreach (@tab) {
	chop($line = $_); $line =~ s/#.*$//g;
	if ($line !~ /^\s*(\S+)\s*=\s*(.*)$/) { print TAB $_; }
	}
close(TAB);
&copy_crontab($_[0]);
}

=head2 expand_run_parts(directory)

Internal function to convert a directory like /etc/cron.hourly into a list
of scripts in that directory.

=cut
sub expand_run_parts
{
local $dir = $_[0];
$dir = "$config{'run_parts_dir'}/$dir"
	if ($config{'run_parts_dir'} && $dir !~ /^\//);
opendir(DIR, &translate_filename($dir));
local @rv = readdir(DIR);
closedir(DIR);
@rv = grep { !/^\./ } @rv;
@rv = map { $dir."/".$_ } @rv;
return @rv;
}

=head2 is_run_parts(command)

Returns the dir if some cron job runs a list of commands in some directory, 
like /etc/cron.hourly. Returns undef otherwise.

=cut
sub is_run_parts
{
local ($cmd) = @_;
local $rp = $config{'run_parts'};
$cmd =~ s/\s*#.*$//;
return $rp && $cmd =~ /$rp(.*)\s+(\-\-\S+\s+)*([a-z0-9\.\-\/_]+)(\s*\))?$/i ? $3 : undef;
}

=head2 can_edit_user(&access, user)

Returns 1 if the Webmin user whose permissions are defined by the access hash
ref can manage cron jobs for a given Unix user.

=cut
sub can_edit_user
{
local %umap;
map { $umap{$_}++; } split(/\s+/, $_[0]->{'users'})
	if ($_[0]->{'mode'} == 1 || $_[0]->{'mode'} == 2);
if ($_[0]->{'mode'} == 1 && !$umap{$_[1]} ||
    $_[0]->{'mode'} == 2 && $umap{$_[1]}) { return 0; }
elsif ($_[0]->{'mode'} == 3) {
	return $remote_user eq $_[1];
	}
elsif ($_[0]->{'mode'} == 4) {
	local @u = getpwnam($_[1]);
	return (!$_[0]->{'uidmin'} || $u[2] >= $_[0]->{'uidmin'}) &&
	       (!$_[0]->{'uidmax'} || $u[2] <= $_[0]->{'uidmax'});
	}
elsif ($_[0]->{'mode'} == 5) {
	local @u = getpwnam($_[1]);
	return $u[3] == $_[0]->{'users'};
	}
else {
	return 1;
	}
}

=head2 list_cron_specials()

Returns a list of the names of special cron times, prefixed by an @ in crontab

=cut
sub list_cron_specials
{
return ('hourly', 'daily', 'weekly', 'monthly', 'yearly', 'reboot');
}

=head2 get_times_input(&job, [nospecial], [width-in-cols], [message])

Returns HTML for selecting the schedule for a cron job, defined by the first
parameter which must be a hash ref returned by list_cron_jobs. Suitable for
use inside a ui_table_start/end

=cut
sub get_times_input
{
return &theme_get_times_input(@_) if (defined(&theme_get_times_input));
my ($job, $nospecial, $width, $msg) = @_;
$width ||= 2;

# Javascript to disable and enable fields
my $rv = <<EOF;
<script>
function enable_cron_fields(name, form, ena)
{
var els = form.elements[name];
els.disabled = !ena;
for(i=0; i<els.length; i++) {
  els[i].disabled = !ena;
  }
change_special_mode(form, 0);
}

function change_special_mode(form, special)
{
form.special_def[0].checked = special;
form.special_def[1].checked = !special;
}
</script>
EOF

if ($config{'vixie_cron'} && (!$nospecial || $job->{'special'})) {
	# Allow selection of special @ times
	my $sp = $job->{'special'} eq 'midnight' ? 'daily' :
		 $job->{'special'} eq 'annually' ? 'yearly' : $job->{'special'};
	my $specialsel = &ui_select("special", $sp,
			[ map { [ $_, $text{'edit_special_'.$_} ] }
			      &list_cron_specials() ],
			1, 0, 0, 0, "onChange='change_special_mode(form, 1)'");
	$rv .= &ui_table_row($msg,
		&ui_radio("special_def", $job->{'special'} ? 1 : 0,
			  [ [ 1, $text{'edit_special1'}." ".$specialsel ],
			    [ 0, $text{'edit_special0'} ] ]),
			  $msg ? $width-1 : $width);
	}

# Section for time selections
my $table = &ui_columns_start([ $text{'edit_mins'}, $text{'edit_hours'},
				$text{'edit_days'}, $text{'edit_months'},
				$text{'edit_weekdays'} ], 100);
my @mins = (0..59);
my @hours = (0..23);
my @days = (1..31);
my @months = map { $text{"month_$_"}."=".$_ } (1 .. 12);
my @weekdays = map { $text{"day_$_"}."=".$_ } (0 .. 6);
my %arrmap = ( 'mins' => \@mins,
	       'hours' => \@hours,
	       'days' => \@days,
	       'months' => \@months,
	       'weekdays' => \@weekdays );
my @cols;
foreach my $arr ("mins", "hours", "days", "months", "weekdays") {
	# Find out which ones are being used
	my %inuse;
	my $min = ($arr =~ /days|months/ ? 1 : 0);
	my @arrlist = @{$arrmap{$arr}};
	my $max = $min+scalar(@arrlist)-1;
	foreach my $w (split(/,/ , $job->{$arr})) {
		if ($w eq "*") {
			# all values
			for($j=$min; $j<=$max; $j++) { $inuse{$j}++; }
			}
		elsif ($w =~ /^\*\/(\d+)$/) {
			# only every Nth
			for($j=$min; $j<=$max; $j+=$1) { $inuse{$j}++; }
			}
		elsif ($w =~ /^(\d+)-(\d+)\/(\d+)$/) {
			# only every Nth of some range
			for($j=$1; $j<=$2; $j+=$3) { $inuse{int($j)}++; }
			}
		elsif ($w =~ /^(\d+)-(\d+)$/) {
			# all of some range
			for($j=$1; $j<=$2; $j++) { $inuse{int($j)}++; }
			}
		else {
			# One value
			$inuse{int($w)}++;
			}
		}
	if ($job->{$arr} eq "*") {
		%inuse = ( );
		}

	# Output selection list
	my $dis = $arr eq "mins" && $hourly_only;
	my $col = &ui_radio(
		    "all_$arr", $job->{$arr} eq "*" ||
				$job->{$arr} eq "" ? 1 : 0,
		    [ [ 1, $text{'edit_all'}."<br>",
			"onClick='enable_cron_fields(\"$arr\", form, 0)'" ],
		      [ 0, $text{'edit_selected'}."<br>",
			"onClick='enable_cron_fields(\"$arr\", form, 1)'" ] ],
		    $dis);
	$col .= "<table> <tr>\n";
        for(my $j=0; $j<@arrlist; $j+=($arr eq "mins" && $hourly_only ? 60 : 12)) {
                my $jj = $j+($arr eq "mins" && $hourly_only ? 59 : 11);
		if ($jj >= @arrlist) { $jj = @arrlist - 1; }
		my @sec = @arrlist[$j .. $jj];
		my @opts;
		foreach my $v (@sec) {
			if ($v =~ /^(.*)=(.*)$/) {
				push(@opts, [ $2, $1 ]);
				}
			else {
				push(@opts, [ $v, $v ]);
				}
			}
		my $dis = $job->{$arr} eq "*" || $job->{$arr} eq "";
		$col .= "<td valign=top>".
			&ui_select($arr, [ keys %inuse ], \@opts,
			  @sec > 12 ? ($arr eq "mins" && $hourly_only ? 1 : 12)
                                  : scalar(@sec),
			  $arr eq "mins" && $hourly_only ? 0 : 1,
			  0, $dis).
			"</td>\n";
		}
	$col .= "</tr></table>\n";
	push(@cols, $col);
	}
$table .= &ui_columns_row(\@cols, [ "valign=top", "valign=top", "valign=top",
				    "valign=top", "valign=top" ]);
$table .= &ui_columns_end();
$table .= $text{'edit_ctrl'};
$rv .= &ui_table_row(undef, $table, $width);
return $rv;
}

=head2 show_times_input(&job, [nospecial])

Print HTML for inputs for selecting the schedule for a cron job, defined
by the first parameter which must be a hash ref returned by list_cron_jobs.
This must be used inside a <table>, as the HTML starts and ends with <tr>
tags.

=cut
sub show_times_input
{
return &theme_show_times_input(@_) if (defined(&theme_show_times_input));
local $job = $_[0];
if ($config{'vixie_cron'} && (!$_[1] || $_[0]->{'special'})) {
	# Allow selection of special @ times
	print "<tr $cb> <td colspan=6>\n";
	printf "<input type=radio name=special_def value=1 %s> %s\n",
		$job->{'special'} ? "checked" : "", $text{'edit_special1'};
	print "<select name=special onChange='change_special_mode(form, 1)'>\n";
	local $s;
	local $sp = $job->{'special'} eq 'midnight' ? 'daily' :
	    $job->{'special'} eq 'annually' ? 'yearly' : $job->{'special'};
	foreach $s ('hourly', 'daily', 'weekly', 'monthly', 'yearly', 'reboot'){
		printf "<option value=%s %s>%s</option>\n",
		    $s, $sp eq $s ? "selected" : "", $text{'edit_special_'.$s};
		}
	print "</select>\n";
	printf "<input type=radio name=special_def value=0 %s> %s\n",
		$job->{'special'} ? "" : "checked", $text{'edit_special0'};
	print "</td></tr>\n";
	}

# Javascript to disable and enable fields
print <<EOF;
<script>
function enable_cron_fields(name, form, ena)
{
var els = form.elements[name];
els.disabled = !ena;
for(i=0; i<els.length; i++) {
  els[i].disabled = !ena;
  }
change_special_mode(form, 0);
}

function change_special_mode(form, special)
{
form.special_def[0].checked = special;
form.special_def[1].checked = !special;
}
</script>
EOF

print "<tr $tb>\n";
print "<td><b>$text{'edit_mins'}</b></td> <td><b>$text{'edit_hours'}</b></td> ",
      "<td><b>$text{'edit_days'}</b></td> <td><b>$text{'edit_months'}</b></td>",
      "<td><b>$text{'edit_weekdays'}</b></td> </tr> <tr $cb>\n";

local @mins = (0..59);
local @hours = (0..23);
local @days = (1..31);
local @months = map { $text{"month_$_"}."=".$_ } (1 .. 12);
local @weekdays = map { $text{"day_$_"}."=".$_ } (0 .. 6);

foreach $arr ("mins", "hours", "days", "months", "weekdays") {
	# Find out which ones are being used
	local %inuse;
	local $min = ($arr =~ /days|months/ ? 1 : 0);
	local $max = $min+scalar(@$arr)-1;
	foreach $w (split(/,/ , $job->{$arr})) {
		if ($w eq "*") {
			# all values
			for($j=$min; $j<=$max; $j++) { $inuse{$j}++; }
			}
		elsif ($w =~ /^\*\/(\d+)$/) {
			# only every Nth
			for($j=$min; $j<=$max; $j+=$1) { $inuse{$j}++; }
			}
		elsif ($w =~ /^(\d+)-(\d+)\/(\d+)$/) {
			# only every Nth of some range
			for($j=$1; $j<=$2; $j+=$3) { $inuse{int($j)}++; }
			}
		elsif ($w =~ /^(\d+)-(\d+)$/) {
			# all of some range
			for($j=$1; $j<=$2; $j++) { $inuse{int($j)}++; }
			}
		else {
			# One value
			$inuse{int($w)}++;
			}
		}
	if ($job->{$arr} eq "*") { undef(%inuse); }

	# Output selection list
	print "<td valign=top>\n";
        printf "<input type=radio name=all_$arr value=1 %s %s %s> %s<br>\n",
                $arr eq "mins" && $hourly_only ? "disabled" : "",
		$job->{$arr} eq "*" ||  $job->{$arr} eq "" ? "checked" : "",
		"onClick='enable_cron_fields(\"$arr\", form, 0)'",
		$text{'edit_all'};
	printf "<input type=radio name=all_$arr value=0 %s %s> %s<br>\n",
		$job->{$arr} eq "*" || $job->{$arr} eq "" ? "" : "checked",
		"onClick='enable_cron_fields(\"$arr\", form, 1)'",
		$text{'edit_selected'};
	print "<table> <tr>\n";
        for($j=0; $j<@$arr; $j+=($arr eq "mins" && $hourly_only ? 60 : 12)) {
                $jj = $j+($arr eq "mins" && $hourly_only ? 59 : 11);
		if ($jj >= @$arr) { $jj = @$arr - 1; }
		@sec = @$arr[$j .. $jj];
                printf "<td valign=top><select %s size=%d name=$arr %s %s>\n",
                        $arr eq "mins" && $hourly_only ? "" : "multiple",
                        @sec > 12 ? ($arr eq "mins" && $hourly_only ? 1 : 12)
				  : scalar(@sec),
			$job->{$arr} eq "*" ||  $job->{$arr} eq "" ?
				"disabled" : "",
			"onChange='change_special_mode(form, 0)'";
		foreach $v (@sec) {
			if ($v =~ /^(.*)=(.*)$/) { $disp = $1; $code = $2; }
			else { $disp = $code = $v; }
			printf "<option value=\"$code\" %s>$disp</option>\n",
				$inuse{$code} ? "selected" : "";
			}
		print "</select></td>\n";
		}
	print "</tr></table></td>\n";
	}
print "</tr> <tr $cb> <td colspan=5>$text{'edit_ctrl'}</td> </tr>\n";
}

=head2 parse_times_input(&job, &in)

Parses inputs from the form generated by show_times_input, and updates a cron
job hash ref. The in parameter must be a hash ref as generated by the 
ReadParse function.

=cut
sub parse_times_input
{
local $job = $_[0];
local %in = %{$_[1]};
local @pers = ("mins", "hours", "days", "months", "weekdays");
local $arr;
if ($in{'special_def'}) {
	# Job time is a special period
	foreach $arr (@pers) {
		delete($job->{$arr});
		}
	$job->{'special'} = $in{'special'};
	}
else {
	# User selection of times
	foreach $arr (@pers) {
		if ($in{"all_$arr"}) {
			# All mins/hrs/etc.. chosen
			$job->{$arr} = "*";
			}
		elsif (defined($in{$arr})) {
			# Need to work out and simplify ranges selected
			local (@range, @newrange, $i);
			@range = split(/\0/, $in{$arr});
			@range = sort { $a <=> $b } @range;
			local $start = -1;
			for($i=0; $i<@range; $i++) {
				if ($i && $range[$i]-1 == $range[$i-1]) {
					# ok.. looks like a range
					if ($start < 0) { $start = $i-1; }
					}
				elsif ($start < 0) {
					# Not in a range at all
					push(@newrange, $range[$i]);
					}
				else {
					# End of the range.. add it
					$newrange[@newrange - 1] =
						"$range[$start]-".$range[$i-1];
					push(@newrange, $range[$i]);
					$start = -1;
					}
				}
			if ($start >= 0) {
				# Reached the end while in a range
				$newrange[@newrange - 1] =
					"$range[$start]-".$range[$i-1];
				}
			$job->{$arr} = join(',' , @newrange);
			}
		else {
			&error(&text('save_enone', $text{"edit_$arr"}));
			}
		}
	delete($job->{'special'});
	}
}

=head2 show_range_input(&job)

Given a cron job, prints fields for selecting it's run date range.

=cut
sub show_range_input
{
local ($job) = @_;
local $has_start = $job->{'start'};
local $rng;
$rng = &text('range_start', &ui_date_input(
	$job->{'start'}->[0], $job->{'start'}->[1], $job->{'start'}->[2],
	"range_start_day", "range_start_month", "range_start_year"))."\n".
      &date_chooser_button(
	"range_start_day", "range_start_month", "range_start_year")."\n".
      &text('range_end', &ui_date_input(
	$job->{'end'}->[0], $job->{'end'}->[1], $job->{'end'}->[2],
	"range_end_day", "range_end_month", "range_end_year"))."\n".
      &date_chooser_button(
	"range_end_day", "range_end_month", "range_end_year")."\n";
print &ui_oneradio("range_def", 1, $text{'range_all'}, !$has_start),
      "<br>\n";
print &ui_oneradio("range_def", 0, $rng, $has_start),"\n";
}

=head2 parse_range_input(&job, &in)

Updates the job object with the specified date range. May call &error
for invalid inputs.

=cut
sub parse_range_input
{
local ($job, $in) = @_;
if ($in->{'range_def'}) {
	# No range used
	delete($job->{'start'});
	delete($job->{'end'});
	}
else {
	# Validate and store range
	foreach my $r ("start", "end") {
		eval { timelocal(0, 0, 0, $in->{'range_'.$r.'_day'},
					  $in->{'range_'.$r.'_month'}-1,
					  $in->{'range_'.$r.'_year'}-1900) };
		if ($@) {
			&error($text{'range_e'.$r}." ".$@);
			}
		$job->{$r} = [ $in->{'range_'.$r.'_day'},
			       $in->{'range_'.$r.'_month'},
			       $in->{'range_'.$r.'_year'} ];
		}
	}
}

@cron_month = ( 'jan', 'feb', 'mar', 'apr', 'may', 'jun',
		'jul', 'aug', 'sep', 'oct', 'nov', 'dec' );
@cron_weekday = ( 'sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat' );

=head2 fix_names(&cron)

Convert day and month names to numbers. For internal use when parsing
the crontab file.

=cut
sub fix_names
{
local ($m, $w);

local @mts = split(/,/, $_[0]->{'months'});
foreach $m (@mts) {
	local $mi = &indexof(lc($m), @cron_month);
	$m = $mi+1 if ($mi >= 0);
	}
$_[0]->{'months'} = join(",", @mts);

local @wds = split(/,/, $_[0]->{'weekdays'});
foreach $w (@wds) {
	local $di = &indexof(lc($w), @cron_weekday);
	$w = $di if ($di >= 0);
	$w = 0 if ($w == 7);
	}
$_[0]->{'weekdays'} = join(",", @wds);
}

=head2 create_wrapper(wrapper-path, module, script)

Creates a wrapper script which calls a script in some module's directory
with the proper webmin environment variables set. This should always be used
when setting up a cron job, instead of attempting to run a command in the
module directory directly.

The parameters are :

=item wrapper-path - Full path to the wrapper to create, like /etc/webmin/yourmodule/foo.pl

=item module - Module containing the real script to call.

=item script - Program within that module for the wrapper to run.

=cut
sub create_wrapper
{
local $perl_path = &get_perl_path();
&open_tempfile(CMD, ">$_[0]");
&print_tempfile(CMD, <<EOF
#!$perl_path
open(CONF, "$config_directory/miniserv.conf") || die "Failed to open $config_directory/miniserv.conf : \$!";
while(<CONF>) {
        \$root = \$1 if (/^root=(.*)/);
        }
close(CONF);
\$root || die "No root= line found in $config_directory/miniserv.conf";
\$ENV{'PERLLIB'} = "\$root";
\$ENV{'WEBMIN_CONFIG'} = "$ENV{'WEBMIN_CONFIG'}";
\$ENV{'WEBMIN_VAR'} = "$ENV{'WEBMIN_VAR'}";
EOF
	);
if ($gconfig{'os_type'} eq 'windows') {
	# On windows, we need to chdir to the drive first, and use system
	&print_tempfile(CMD, "if (\$root =~ /^([a-z]:)/i) {\n");
	&print_tempfile(CMD, "       chdir(\"\$1\");\n");
	&print_tempfile(CMD, "       }\n");
	&print_tempfile(CMD, "chdir(\"\$root/$_[1]\");\n");
	&print_tempfile(CMD, "exit(system(\"\$root/$_[1]/$_[2]\", \@ARGV));\n");
	}
else {
	# Can use exec on Unix systems
	if ($_[1]) {
		&print_tempfile(CMD, "chdir(\"\$root/$_[1]\");\n");
		&print_tempfile(CMD, "exec(\"\$root/$_[1]/$_[2]\", \@ARGV) || die \"Failed to run \$root/$_[1]/$_[2] : \$!\";\n");
		}
	else {
		&print_tempfile(CMD, "chdir(\"\$root\");\n");
		&print_tempfile(CMD, "exec(\"\$root/$_[2]\", \@ARGV) || die \"Failed to run \$root/$_[2] : \$!\";\n");
		}
	}
&close_tempfile(CMD);
chmod(0755, $_[0]);
}

=head2 cron_file(&job)

Returns the file that a cron job is in, or will be in when it is created
based on the username.

=cut
sub cron_file
{
return $_[0]->{'file'} || $config{'add_file'} ||
       "$config{'cron_dir'}/$_[0]->{'user'}";
}

=head2 when_text(&job, [upper-case-first])

Returns a human-readable text string describing when a cron job is run.

=cut
sub when_text
{
local $pfx = $_[1] ? "uc" : "";
if ($_[0]->{'interval'}) {
	return &text($pfx.'when_interval', $_[0]->{'interval'});
	}
elsif ($_[0]->{'special'}) {
	$pfx = $_[1] ? "" : "lc";
	return $text{$pfx.'edit_special_'.$_[0]->{'special'}};
	}
elsif ($_[0]->{'boot'}) {
	return &text($pfx.'when_boot');
	}
elsif ($_[0]->{'mins'} eq '*' && $_[0]->{'hours'} eq '*' && $_[0]->{'days'} eq '*' && $_[0]->{'months'} eq '*' && $_[0]->{'weekdays'} eq '*') {
	return $text{$pfx.'when_min'};
	}
elsif ($_[0]->{'mins'} =~ /^\d+$/ && $_[0]->{'hours'} eq '*' && $_[0]->{'days'} eq '*' && $_[0]->{'months'} eq '*' && $_[0]->{'weekdays'} eq '*') {
	return &text($pfx.'when_hour', $_[0]->{'mins'});
	}
elsif ($_[0]->{'mins'} =~ /^\d+$/ && $_[0]->{'hours'} =~ /^\d+$/ && $_[0]->{'days'} eq '*' && $_[0]->{'months'} eq '*' && $_[0]->{'weekdays'} eq '*') {
	return &text($pfx.'when_day', sprintf("%2.2d", $_[0]->{'mins'}), $_[0]->{'hours'});
	}
elsif ($_[0]->{'mins'} =~ /^\d+$/ && $_[0]->{'hours'} =~ /^\d+$/ && $_[0]->{'days'} =~ /^\d+$/ && $_[0]->{'months'} eq '*' && $_[0]->{'weekdays'} eq '*') {
	return &text($pfx.'when_month', sprintf("%2.2d", $_[0]->{'mins'}), $_[0]->{'hours'}, $_[0]->{'days'});
	}
elsif ($_[0]->{'mins'} =~ /^\d+$/ && $_[0]->{'hours'} =~ /^\d+$/ && $_[0]->{'days'} eq '*' && $_[0]->{'months'} eq '*' && $_[0]->{'weekdays'} =~ /^\d+$/) {
	return &text($pfx.'when_weekday', sprintf("%2.2d", $_[0]->{'mins'}), $_[0]->{'hours'}, $text{"day_".$_[0]->{'weekdays'}});
	}
else {
	return &text($pfx.'when_cron', join(" ", $_[0]->{'mins'}, $_[0]->{'hours'}, $_[0]->{'days'}, $_[0]->{'months'}, $_[0]->{'weekdays'}));
	}
}

=head2 can_use_cron(user)

Returns 1 if some user is allowed to use cron, based on cron.allow and
cron.deny files.

=cut
sub can_use_cron
{
local ($user) = @_;
defined(getpwnam($user)) || return 0;	# User does not exist
local $err;
if (-r $config{cron_allow_file}) {
	local @allowed = &list_allowed();
	if (&indexof($user, @allowed) < 0 &&
	    &indexof("all", @allowed) < 0) { $err = 1; }
	}
elsif (-r $config{cron_deny_file}) {
	local @denied = &list_denied();
	if (&indexof($user, @denied) >= 0 ||
	    &indexof("all", @denied) >= 0) { $err = 1; }
	}
elsif ($config{cron_deny_all} == 0) { $err = 1; }
elsif ($config{cron_deny_all} == 1) {
	if ($in{user} ne "root") { $err = 1; }
	}
return !$err;
}

=head2 swap_cron_jobs(&job1, &job2)

Swaps two Cron jobs, which must be in the same file, identified by their
hash references as returned by list_cron_jobs.

=cut
sub swap_cron_jobs
{
if ($_[0]->{'type'} == 0) {
	&copy_cron_temp($_[0]);
	local $lref = &read_file_lines($cron_temp_file);
	($lref->[$_[0]->{'line'}], $lref->[$_[1]->{'line'}]) =
		($lref->[$_[1]->{'line'}], $lref->[$_[0]->{'line'}]);
	&flush_file_lines();
	&copy_crontab($_[0]->{'user'});
	}
else {
	local $lref = &read_file_lines($_[0]->{'file'});
	($lref->[$_[0]->{'line'}], $lref->[$_[1]->{'line'}]) =
		($lref->[$_[1]->{'line'}], $lref->[$_[0]->{'line'}]);
	&flush_file_lines();
	}
}

=head2 find_cron_process(&job, [&procs])

Finds the running process that was launched from a cron job. The parameters are:

=item job - A cron job hash reference

=item procs - An optional array reference of running process hash refs

=cut
sub find_cron_process
{
local @procs;
if ($_[1]) {
	@procs = @{$_[1]};
	}
else {
	&foreign_require("proc", "proc-lib.pl");
	@procs = &proc::list_processes();
	}
local $rpd = &is_run_parts($_[0]->{'command'});
local @exp = $rpd ? &expand_run_parts($rpd) : ();
local $cmd = $exp[0] || $_[0]->{'command'};
$cmd =~ s/^\s*\[.*\]\s+\&\&\s+//;
$cmd =~ s/^\s*\[.*\]\s+\|\|\s+//;
while($cmd =~ s/(\d*)(<|>)((\/\S+)|&\d+)\s*$//) { }
$cmd =~ s/^\((.*)\)\s*$/$1/;
$cmd =~ s/\s+$//;
if ($config{'match_mode'} == 1) {
	$cmd =~ s/\s.*$//;
	}
($proc) = grep { $_->{'args'} =~ /\Q$cmd\E/ &&
		 (!$config{'match_user'} || $_->{'user'} eq $_[0]->{'user'}) }
		@procs;
if (!$proc && $cmd =~ /^$config_directory\/(.*\.pl)(.*)$/) {
	# Must be a Webmin wrapper
	$cmd = "$root_directory/$1$2";
	($proc) = grep { $_->{'args'} =~ /\Q$cmd\E/ &&
			 (!$config{'match_user'} ||
			  $_->{'user'} eq $_[0]->{'user'}) }
			@procs;
	}
return $proc;
}

=head2 find_cron_job(command, [&jobs], [user])

Returns the cron job object that runs some command (perhaps with redirection)

=cut
sub find_cron_job
{
my ($cmd, $jobs, $user) = @_;
if (!$jobs) {
	$jobs = [ &list_cron_jobs() ];
	}
$user ||= "root";
my @rv = grep { $_->{'user'} eq $user &&
	     $_->{'command'} =~ /(^|[ \|\&;\/])\Q$cmd\E($|[ \|\&><;])/ } @$jobs;
return wantarray ? @rv : $rv[0];
}

=head2 extract_input(command)

Given a line formatted like I<command%input>, returns the command and input
parts, taking any escaping into account.

=cut
sub extract_input
{
local ($cmd) = @_;
$cmd =~ s/\\%/\0/g;
local ($cmd, $input) = split(/\%/, $cmd, 2);
$cmd =~ s/\0/\\%/g;
$input =~ s/\0/\\%/g;
return ($cmd, $input);
}

=head2 convert_range(&job)

Given a cron job that uses range.pl, work out the date range and update
the job object command. Mainly for internal use.

=cut
sub convert_range
{
local ($job) = @_;
local ($cmd, $input) = &extract_input($job->{'command'});
if ($cmd =~ /^\Q$range_cmd\E\s+(\d+)\-(\d+)\-(\d+)\s+(\d+)\-(\d+)\-(\d+)\s+(.*)$/) {
	# Looks like a range command
	$job->{'start'} = [ $1, $2, $3 ];
	$job->{'end'} = [ $4, $5, $6 ];
	$job->{'command'} = $7;
	$job->{'command'} =~ s/\\(.)/$1/g;
	if ($input) {
		$job->{'command'} .= '%'.$input;
		}
	return 1;
	}
return 0;
}

=head2 unconvert_range(&job)

Give a cron job with start and end fields, updates the command to wrap it in
range.pl with those dates as parameters.

=cut
sub unconvert_range
{
local ($job) = @_;
if ($job->{'start'}) {
	# Need to add range command
	local ($cmd, $input) = &extract_input($job->{'command'});
	$job->{'command'} = $range_cmd." ".join("-", @{$job->{'start'}})." ".
					   join("-", @{$job->{'end'}})." ".
					   quotemeta($cmd);
	if ($input) {
		$job->{'command'} .= '%'.$input;
		}
	delete($job->{'start'});
	delete($job->{'end'});
	&copy_source_dest("$module_root_directory/range.pl", $range_cmd);
	&set_ownership_permissions(undef, undef, 0755, $range_cmd);
	return 1;
	}
return 0;
}

=head2 convert_comment(&job)

Given a cron job with a # comment after the command, sets the comment field

=cut
sub convert_comment
{
local ($job) = @_;
if ($job->{'command'} =~ /^(.*\S)\s*#([^#]*)$/) {
	$job->{'command'} = $1;
	$job->{'comment'} = $2;
	return 1;
	}
return 0;
}

=head2 unconvert_comment(&job)

Adds an comment back to the command in a cron job, based on the comment field
of the given hash reference.

=cut
sub unconvert_comment
{
local ($job) = @_;
if ($job->{'comment'} =~ /\S/) {
	$job->{'command'} .= " #".$job->{'comment'};
	return 1;
	}
return 0;
}

=head2 check_cron_config

Returns an error message if the cron config doesn't look valid, or some needed
command is missing.

=cut
sub check_cron_config
{
# Check for single file and getter command
if ($config{'single_file'} && !-r $config{'single_file'}) {
	return &text('index_esingle', "<tt>$config{'single_file'}</tt>");
	}
if (!&has_crontab_cmd() && $config{'cron_get_command'} =~ /^(\S+)/ &&
    !&has_command("$1")) {
	return &text('index_ecmd', "<tt>$1</tt>");
	}
# Check for directory
local $fcron = ($config{'cron_dir'} =~ /\/fcron$/);
if (!$single_user && !$config{'single_file'} &&
    !$fcron && !-d $config{'cron_dir'}) {
	if (!$in{'create_dir'}) {
		return &text('index_ecrondir', "<tt>$config{'cron_dir'}</tt>").
		"<p><a href=\"index.cgi?create_dir=yes\">".&text('index_ecrondir_create' ,"<tt>$config{'cron_dir'}</tt>")."</a></p>";
	} else {
		&make_dir($config{'cron_dir'}, 0755);
		}
	}
return undef;
}

=head2 check_cron_config_or_error

Calls check_cron_config, and then error if any problems were detected.

=cut
sub check_cron_config_or_error
{
local $err = &check_cron_config();
if ($err) {
	&error(&text('index_econfigcheck', $err));
	}
}

=head2 cleanup_temp_files

Called from cron to delete old files in the Webmin /tmp directory

=cut
sub cleanup_temp_files
{
# Don't run if disabled
if (!$gconfig{'tempdelete_days'}) {
	print STDERR "Temp file clearing is disabled\n";
	return;
	}
if ($gconfig{'tempdir'} && !$gconfig{'tempdirdelete'}) {
	print STDERR "Temp file clearing is not done for the custom directory $gconfig{'tempdir'}\n";
	return;
	}

local $tempdir = &transname();
$tempdir =~ s/\/([^\/]+)$//;
if (!$tempdir || $tempdir eq "/") {
	$tempdir = "/tmp/.webmin";
	}

local $cutoff = time() - $gconfig{'tempdelete_days'}*24*60*60;
opendir(DIR, $tempdir);
foreach my $f (readdir(DIR)) {
	next if ($f eq "." || $f eq "..");
	local @st = lstat("$tempdir/$f");
	if ($st[9] < $cutoff) {
		&unlink_file("$tempdir/$f");
		}
	}
closedir(DIR);
}

=head2 list_cron_files()

Returns a list of all files containing cron jobs

=cut
sub list_cron_files
{
my @jobs = &list_cron_jobs();
my @files = map { $_->{'file'} } grep { $_->{'file'} } @jobs;
if ($config{'system_crontab'}) {
	push(@files, $config{'system_crontab'});
	}
if ($config{'cronfiles_dir'}) {
	push(@files, glob(&translate_filename($config{'cronfiles_dir'})."/*"));
	}
return &unique(@files);
}

=head2 has_crontab_cmd()

Returns 1 if the crontab command exists on this system

=cut
sub has_crontab_cmd
{
my $cmd = $config{'cron_edit_command'};
if ($cmd) {
	$cmd =~ s/^su.*-c\s+//;
	($cmd) = &split_quoted_string($cmd);
	my $rv = &has_command($cmd);
	return $rv if ($rv);
	}
return &has_command("crontab");
}

1;

