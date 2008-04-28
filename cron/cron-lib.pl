# cron-lib.pl
# Common crontab functions
# XXX support for envs in /etc/crontab and /etc/cron.d (impossible!)

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
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

# list_cron_jobs()
# Returns a lists of structures of all cron jobs
sub list_cron_jobs
{
local (@rv, $lnum, $f);
if (defined(@cron_jobs_cache)) {
	return @cron_jobs_cache;
	}

# read the master crontab file
if ($config{'system_crontab'}) {
	$lnum = 0;
	&open_readfile(TAB, $config{'system_crontab'});
	while(<TAB>) {
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
return join(" ", @c);
}

# copy_cron_temp(&job)
# Copies a job's user's current cron configuration to the temp file
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

# create_cron_job(&job)
# Add a Cron job to a user's file
sub create_cron_job
{
&check_cron_config_or_error();
&list_cron_jobs();	# init cache
if ($config{'single_file'} && !$config{'cron_dir'}) {
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
	&flush_file_lines();
	system("chown $_[0]->{'user'} $cron_temp_file");
	&copy_crontab($_[0]->{'user'});
	$_[0]->{'file'} = "$config{'cron_dir'}/$_[0]->{'user'}";
	$_[0]->{'index'} = scalar(@cron_jobs_cache);
	push(@cron_jobs_cache, $_[0]);
	}
}

# insert_cron_job(&job)
# Add a Cron job at the top of the user's file
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

# renumber(file, line, offset)
# All jobs in this file whose line is at or after the given one will be
# incremented by the offset
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

# renumber_index(index, offset)
sub renumber_index
{
local $j;
foreach $j (@cron_jobs_cache) {
	if ($j->{'index'} >= $_[0]) {
		$j->{'index'} += $_[1];
		}
	}
}

# change_cron_job(&job)
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

# delete_cron_job(&job)
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

# read_crontab(user)
# Return an array containing the lines of the cron table for some user
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


# copy_crontab(user)
# Copy the cron temp file to that for this user
sub copy_crontab
{
if (&is_readonly_mode()) {
	# Do nothing
	return undef;
	}
local($pwd);
if (`cat $cron_temp_file` =~ /\S/) {
	local $temp = &transname();
	local $rv;
	if ($config{'cron_edit_command'}) {
		# fake being an editor
		# XXX does not work in translated command mode!
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
		}
	else {
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
	local $out = `cat $temp`;
	unlink($temp);
	if ($rv || $out =~ /error/i) {
		local $cronin = `cat $cron_temp_file`;
		&error(&text('ecopy', "<pre>$out</pre>", "<pre>$cronin</pre>"));
		}
	}
else {
	# No more cron jobs left, so just delete
	if ($single_user) {
		&execute_command($config{'cron_user_delete_command'});
		}
	else {
		&execute_command(&user_sub(
			$config{'cron_delete_command'}, $_[0]));
		}
	}
unlink($cron_temp_file);
}


# parse_job(job)
# Parse a crontab line into an array containing:
#  active, mins, hrs, days, mons, weekdays, command
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

# user_sub(command, user)
# Replace the string 'USER' in the command with the user name
sub user_sub
{
local($tmp);
$tmp = $_[0];
$tmp =~ s/USER/$_[1]/g;
return $tmp;
}


# list_allowed()
# Returns a list of all users in the cron allow file
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


# list_denied()
# Return a list of users from the cron deny file
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


# save_allowed(user, user, ...)
# Save the list of allowed users
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


# save_denied(user, user, ...)
# Save the list of denied users
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

# read_envs(user)
# Returns an array of name,value pairs containing the environment settings
# from the crontab for some user
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

# save_envs(user, [name, value]*)
# Updates the cron file for some user with the given list of environment
# variables. All others in the file are removed
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

# expand_run_parts(directory)
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

# is_run_parts(command)
sub is_run_parts
{
local $rp = $config{'run_parts'};
return $rp && $_[0] =~ /$rp(.*)\s+([a-z0-9\.\-\/_]+)(\s*\))?$/i ? $2 : undef;
}

# can_edit_user(&access, user)
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

# show_times_input(&job, [nospecial])
sub show_times_input
{
return &theme_show_times_input(@_) if (defined(&theme_show_times_input));
local $job = $_[0];
if ($config{'vixie_cron'} && (!$_[1] || $_[0]->{'special'})) {
	# Allow selection of special @ times
	print "<tr $cb> <td colspan=6>\n";
	printf "<input type=radio name=special_def value=1 %s> %s\n",
		$job->{'special'} ? "checked" : "", $text{'edit_special1'};
	print "<select name=special>\n";
	local $s;
	local $sp = $job->{'special'} eq 'midnight' ? 'daily' :
	    $job->{'special'} eq 'annually' ? 'yearly' : $job->{'special'};
	foreach $s ('hourly', 'daily', 'weekly', 'monthly', 'yearly', 'reboot'){
		printf "<option value=%s %s>%s\n",
		    $s, $sp eq $s ? "selected" : "", $text{'edit_special_'.$s};
		}
	print "</select>\n";
	printf "<input type=radio name=special_def value=0 %s> %s\n",
		$job->{'special'} ? "" : "checked", $text{'edit_special0'};
	print "</td></tr>\n";
	}

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
        printf "<input type=radio name=all_$arr value=1 %s %s> $text{'edit_all'}<br>\n",
                $arr eq "mins" && $hourly_only ? "disabled" : "",
		$job->{$arr} eq "*" ? "checked" : "";
	printf "<input type=radio name=all_$arr value=0 %s> $text{'edit_selected'}<br>\n",
		$job->{$arr} ne "*" ? "checked" : "";
	print "<table> <tr>\n";
        for($j=0; $j<@$arr; $j+=($arr eq "mins" && $hourly_only ? 60 : 12)) {
                $jj = $j+($arr eq "mins" && $hourly_only ? 59 : 11);
		if ($jj >= @$arr) { $jj = @$arr - 1; }
		@sec = @$arr[$j .. $jj];
                printf "<td valign=top><select %s size=%d name=$arr>\n",
                        $arr eq "mins" && $hourly_only ? "" : "multiple",
                        @sec > 12 ? ($arr eq "mins" && $hourly_only ? 1 : 12) : scalar(@sec);
		foreach $v (@sec) {
			if ($v =~ /^(.*)=(.*)$/) { $disp = $1; $code = $2; }
			else { $disp = $code = $v; }
			printf "<option value=\"$code\" %s>$disp\n",
				$inuse{$code} ? "selected" : "";
			}
		print "</select></td>\n";
		}
	print "</tr></table></td>\n";
	}
print "</tr> <tr $cb> <td colspan=5>$text{'edit_ctrl'}</td> </tr>\n";
}

# parse_times_input(&job, &in)
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

# show_range_input(&job)
# Given a cron job, prints fields for selecting it's run date range
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

# parse_range_input(&job, &in)
# Updates the job object with the specified date range. May call &error
# for invalid inputs
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

# fix_names(&cron)
# Convert day and month names to numbers
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

# create_wrapper(wrapper-path, module, script)
# Creates a wrapper script which calls a script in some module's directory
# with the proper webmin environment variables set. This should always be used
# when setting up a cron job, instead of attempting to run a command in the
# module directory directly.
sub create_wrapper
{
local $perl_path = &get_perl_path();
&open_tempfile(CMD, ">$_[0]");
&print_tempfile(CMD, <<EOF
#!$perl_path
open(CONF, "$config_directory/miniserv.conf");
while(<CONF>) {
        \$root = \$1 if (/^root=(.*)/);
        }
close(CONF);
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
	&print_tempfile(CMD, "chdir(\"\$root/$_[1]\");\n");
	&print_tempfile(CMD, "exec(\"\$root/$_[1]/$_[2]\", \@ARGV) || die \"Failed to run \$root/$_[1]/$_[2] : \$!\";\n");
	}
&close_tempfile(CMD);
chmod(0755, $_[0]);
}

# cron_file(&job)
# Returns the file that a cron job is in, or would be in
sub cron_file
{
return $_[0]->{'file'} || "$config{'cron_dir'}/$_[0]->{'user'}";
}

# when_text(&job, [upper-case-first])
# Returns a text string describing when a cron job is run
sub when_text
{
local $pfx = $_[1] ? "uc" : "";
if ($_[0]->{'special'}) {
	$pfx = $_[1] ? "" : "lc";
	return $text{$pfx.'edit_special_'.$_[0]->{'special'}};
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

# can_use_cron(user)
# Returns 1 if some user is allowed to use cron, based on cron.allow and
# cron.deny files
sub can_use_cron
{
local $err;
if (-r $config{cron_allow_file}) {
	local @allowed = &list_allowed();
	if (&indexof($_[0], @allowed) < 0 &&
	    &indexof("all", @allowed) < 0) { $err = 1; }
	}
elsif (-r $config{cron_deny_file}) {
	local @denied = &list_denied();
	if (&indexof($_[0], @denied) >= 0 ||
	    &indexof("all", @denied) >= 0) { $err = 1; }
	}
elsif ($config{cron_deny_all} == 0) { $err = 1; }
elsif ($config{cron_deny_all} == 1) {
	if ($in{user} ne "root") { $err = 1; }
	}
return !$err;
}

# swap_cron_jobs(&job1, &job2)
# Swaps two Cron jobs, which must be in the same file
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

# find_cron_process(&job, [&procs])
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

# extract_input(command)
# Given a command line cmd%input , returns the command and input parts
sub extract_input
{
local ($cmd) = @_;
$cmd =~ s/\\%/\0/g;
local ($cmd, $input) = split(/\%/, $cmd, 2);
$cmd =~ s/\0/%/g;
$input =~ s/\0/%/g;
return ($cmd, $input);
}

# convert_range(&job)
# Given a cron job that uses range.pl , work out the date range and update
# the job object command
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

# unconvert_range(&job)
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
	&create_wrapper($range_cmd, $module_name, "range.pl");
	&set_ownership_permissions(undef, undef, 0755, $range_cmd);
	return 1;
	}
return 0;
}

# convert_comment(&job)
# Given a cron job with a # command after the command, sets the comment field
sub convert_comment
{
local ($job) = @_;
if ($job->{'command'} =~ /^(.*)\s*#([^#]*)$/) {
	$job->{'command'} = $1;
	$job->{'comment'} = $2;
	return 1;
	}
return 0;
}

# unconvert_comment(&job)
# Adds an comment back to the command in a cron job
sub unconvert_comment
{
local ($job) = @_;
if ($job->{'comment'} =~ /\S/) {
	$job->{'command'} .= " #".$job->{'comment'};
	return 1;
	}
return 0;
}

# check_cron_config()
# Returns an error message if the cron config doesn't look valid
sub check_cron_config
{
# Check for single file and getter command
if ($config{'single_file'} && !-r $config{'single_file'}) {
	return &text('index_esingle', "<tt>$config{'single_file'}</tt>");
	}
if ($config{'cron_get_command'} =~ /^(\S+)/ && !&has_command("$1")) {
	return &text('index_ecmd', "<tt>$1</tt>");
	}
# Check for directory
local $fcron = ($config{'cron_dir'} =~ /\/fcron$/);
if (!$single_user && !$fcron && !-d $config{'cron_dir'}) {
	return &text('index_ecrondir', "<tt>$config{'cron_dir'}</tt>");
	}
return undef;
}

sub check_cron_config_or_error
{
local $err = &check_cron_config();
if ($err) {
	&error(&text('index_econfigcheck', $err));
	}
}

1;

