=head1 quota-lib.pl

Functions for Unix user and group quota management. Some of the functionality
is implemented in OS-specific library files which get automatically included
into this one, like linux-lib.pl. Check the documentation on that file for
more functions.

Example code:

 foreign_require('quota', 'quota-lib.pl');
 quota::edit_user_quota('joe', '/home', 1000000, 1200000, 1000, 1200);
 $n = quota::user_filesystems('joe');
 for($i=0; $i<$n; $i++) {
   print "filesystem=",$filesys{$i,'filesys'}," ",
         "block quota=",$filesys{$i,'hblocks'}," ",
         "blocks used=",$filesys{$i,'ublocks'},"\n";
 }

=cut

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
if ($gconfig{'os_type'} =~ /^\S+\-linux$/) {
	do "linux-lib.pl";
	}
else {
	do "$gconfig{'os_type'}-lib.pl";
	}
if ($module_info{'usermin'}) {
	&switch_to_remote_user();
	}
else {
	%access = &get_module_acl();
	&foreign_require("mount", "mount-lib.pl");
	}

$email_cmd = "$module_config_directory/email.pl";

=head2 list_filesystems

Returns a list of details of local filesystems on which quotas are supported.
Each is an array ref whose values are :

=item directory - Mount point, like /home

=item device - Source device, like /dev/hda1

=item type - Filesystem type, like ext3

=item options - Mount options, like rw,usrquota,grpquota

=item quotacan - Can this filesystem support quotas?

=item quotanow - Are quotas enabled right now?

=item quotapossible - Can quotas potentially be enabled?

The values of quotacan and quotanow are :

=item 0 - No quotas

=item 1 - User quotas only

=item 2 - Group quotas only

=item 3 - User and group quotas

=cut
sub list_filesystems
{
local $f;
local @mtab = &mount::list_mounted();
foreach $f (&mount::list_mounts()) {
	$fmap{$f->[0],$f->[1]} = $f;
	}
map { $_->[4] = &quota_can($_, $fmap{$_->[0],$_->[1]}) } @mtab;
map { $_->[5] = &quota_now($_, $fmap{$_->[0],$_->[1]}) } @mtab;
if (defined(&quota_possible)) {
	map { $_->[6] = &quota_possible($fmap{$_->[0],$_->[1]}) } @mtab;
	}
return grep { $_->[4] || $_->[6] } @mtab;
}

=head2 parse_options(type, options)

Convert an options string for some filesystem into the global hash %options.

=cut
sub parse_options
{
local($_);
undef(%options);
if ($_[0] ne "-") {
	foreach (split(/,/, $_[0])) {
		if (/^([^=]+)=(.*)$/) { $options{$1} = $2; }
		else { $options{$_} = ""; }
		}
	}
}

=head2 user_quota(user, filesystem)

Returns an array of quotas and usage information for some user on some
filesystem, or an empty array if no quota has been assigned. The array
elements are :

=item Number of blocks used.

=item Soft block quota.

=item Hard block quota.

=item Number of files used.

=item Soft file quota.

=item Hard file quota.

=cut
sub user_quota
{
my ($user, $fs) = @_;
local %user;
my $n = &filesystem_users($fs);
for(my $i=0; $i<$n; $i++) {
	if ($user{$i,'user'} eq $user) {
		return ( $user{$i,'ublocks'}, $user{$i,'sblocks'},
			 $user{$i,'hblocks'}, $user{$i,'ufiles'},
			 $user{$i,'sfiles'},  $user{$i,'hfiles'} );
		}
	}
return ();
}

=head2 group_quota(group, filesystem)

Returns an array of  ublocks, sblocks, hblocks, ufiles, sfiles, hfiles
for some group on some filesystem, or an empty array if no quota has been
assigned.

=cut
sub group_quota
{
my ($group, $fs) = @_;
local %group;
my $n = &filesystem_groups($fs);
for(my $i=0; $i<$n; $i++) {
	if ($group{$i,'group'} eq $group) {
		return ( $group{$i,'ublocks'}, $group{$i,'sblocks'},
			 $group{$i,'hblocks'}, $group{$i,'ufiles'},
			 $group{$i,'sfiles'},  $group{$i,'hfiles'} );
		}
	}
return ();
}

=head2 edit_user_quota(user, filesys, sblocks, hblocks, sfiles, hfiles)

Sets the disk quota for some user. The parameters are :

=item user - Unix username.

=item filesys - Filesystem on which to change quotas.

=item sblocks - Soft block limit.

=item hblocks - Hard block limit.

=item sfiles - Sort files limit.

=item hfiles - Hard files limit.

=cut
sub edit_user_quota
{
my ($user, $fs, $sblocks, $hblocks, $sfiles, $hfiles) = @_;
if (defined(&set_user_quota) && defined(&can_set_user_quota) &&
    &can_set_user_quota($fs)) {
	# OS lib file defines a function to set quotas
	return &set_user_quota(@_);
	}
elsif ($config{'user_setquota_command'} &&
       &has_command((split(/\s+/, $config{'user_setquota_command'}))[0])) {
	# Use quota setting command
	if ($user =~ /^#(\d+)$/) {
		# Pass numeric UID
		$user = $1;
		}
	elsif ($user =~ /^\d+$/) {
		# Username is numeric .. convert to UID
		local $uid = getpwnam($user);
		$user = $uid if (defined($uid));
		}
	local $cmd = $config{'user_setquota_command'}." ".quotemeta($user)." ".
		     int($sblocks)." ".int($hblocks)." ".
		     int($sfiles)." ".int($hfiles)." ".quotemeta($fs);
	local $out = &backquote_logged("$cmd 2>&1 </dev/null");
	&error("<tt>".&html_escape($out)."</tt>") if ($?);
	}
else {
	# Call the quota editor
	$ENV{'EDITOR'} = $ENV{'VISUAL'} = "$module_root_directory/edquota.pl";
	$ENV{'QUOTA_USER'} = $user;
	$ENV{'QUOTA_FILESYS'} = $fs;
	$ENV{'QUOTA_SBLOCKS'} = $sblocks;
	$ENV{'QUOTA_HBLOCKS'} = $hblocks;
	$ENV{'QUOTA_SFILES'} = $sfiles;
	$ENV{'QUOTA_HFILES'} = $hfiles;
	if ($edquota_use_ids) {
		# Use UID instead of username
		if ($user =~ /^#(\d+)$/) {
			$user = $1;
			}
		else {
			local $uid = getpwnam($user);
			$user = $uid if (defined($uid));
			}
		}
	&system_logged("$config{'user_edquota_command'} ".
		       quotemeta($user)." >/dev/null 2>&1");
	}
}

=head2 edit_group_quota(group, filesys, sblocks, hblocks, sfiles, hfiles)

Sets the disk quota for some group The parameters are :

=item user - Unix group name.

=item filesys - Filesystem on which to change quotas.

=item sblocks - Soft block limit.

=item hblocks - Hard block limit.

=item sfiles - Sort files limit.

=item hfiles - Hard files limit.

=cut
sub edit_group_quota
{
my ($group, $fs, $sblocks, $hblocks, $sfiles, $hfiles) = @_;
if (defined(&set_group_quota) && defined(&can_set_group_quota) &&
    &can_set_group_quota($fs)) {
	# OS lib file defines a function to set quotas
	return &set_group_quota(@_);
	}
elsif ($config{'group_setquota_command'} &&
       &has_command((split(/\s+/, $config{'group_setquota_command'}))[0])) {
	# Use quota setting command
	if ($group =~ /^#(\d+)$/) {
		# Pass numeric UID
		$group = $1;
		}
	elsif ($group =~ /^\d+$/) {
		# Group name is numeric .. convert to GID
		local $gid = getgrnam($group);
		$group = $gid if (defined($gid));
		}
	local $cmd =$config{'group_setquota_command'}." ".quotemeta($group)." ".
		     int($sblocks)." ".int($hblocks)." ".
		     int($sfiles)." ".int($hfiles)." ".quotemeta($fs);
	local $out = &backquote_logged("$cmd 2>&1 </dev/null");
	&error("<tt>".&html_escape($out)."</tt>") if ($?);
	}
else {
	# Call the editor
	$ENV{'EDITOR'} = $ENV{'VISUAL'} = "$module_root_directory/edquota.pl";
	$ENV{'QUOTA_USER'} = $group;
	$ENV{'QUOTA_FILESYS'} = $fs;
	$ENV{'QUOTA_SBLOCKS'} = $sblocks;
	$ENV{'QUOTA_HBLOCKS'} = $hblocks;
	$ENV{'QUOTA_SFILES'} = $sfiles;
	$ENV{'QUOTA_HFILES'} = $hfiles;
	if ($edquota_use_ids) {
		# Use GID instead of group name
		if ($group =~ /^#(\d+)$/) {
			$group = $1;
			}
		else {
			local $gid = getgrnam($group);
			$group = $gid if (defined($gid));
			}
		}
	&system_logged("$config{'group_edquota_command'} ".
		       quotemeta($group)." >/dev/null 2>&1");
	}
}

=head2 edit_user_grace(filesystem, btime, bunits, ftime, funits)

Change the grace times for blocks and files on some filesystem. Parameters are:

=item filesystem - Filesystem to change the grace time on.

=item btime - Number of units after which a user over his soft block limit is turned into a hard limit.

=item bunits - Units for the block grace time, such as 'seconds', 'minutes', 'hours' or 'days'.

=item ftime - Number of units after which a user over his soft file limit is turned into a hard limit.

=item funits - Units for the file grace time, such as 'seconds', 'minutes', 'hours' or 'days'.

=cut
sub edit_user_grace
{
my ($fs, $btime, $bunits, $ftime, $funits) = @_;
if (defined(&set_user_grace) && defined(&can_set_user_grace) &&
    &can_set_user_grace($fs)) {
	return &set_user_grace(@_);
	}
else {
	$ENV{'EDITOR'} = $ENV{'VISUAL'} = "$module_root_directory/edgrace.pl";
	$ENV{'QUOTA_FILESYS'} = $fs;
	$ENV{'QUOTA_BTIME'} = $btime;
	$ENV{'QUOTA_BUNITS'} = $bunits;
	$ENV{'QUOTA_FTIME'} = $ftime;
	$ENV{'QUOTA_FUNITS'} = $funits;
	&system_logged($config{'user_grace_command'});
	}
}

=head2 edit_group_grace(filesystem, btime, bunits, ftime, funits)

Change the grace times for groups for blocks and files on some filesystem.
The parameters are the same as edit_user_grace.

=cut
sub edit_group_grace
{
my ($fs, $btime, $bunits, $ftime, $funits) = @_;
if (defined(&set_group_grace) && defined(&can_set_group_grace) &&
    &can_set_group_grace($fs)) {
	return &set_group_grace(@_);
	}
else {
	$ENV{'EDITOR'} = $ENV{'VISUAL'} = "$module_root_directory/edgrace.pl";
	$ENV{'QUOTA_FILESYS'} = $fs;
	$ENV{'QUOTA_BTIME'} = $btime;
	$ENV{'QUOTA_BUNITS'} = $bunits;
	$ENV{'QUOTA_FTIME'} = $ftime;
	$ENV{'QUOTA_FUNITS'} = $funits;
	&system_logged($config{'group_grace_command'});
	}
}

=head2 quota_input(name, value, [blocksize])

Returns an input for selecting a quota or unlimited, in a table. For internal
use mainly.

=cut
sub quota_input
{
return &ui_radio($_[0]."_def", $_[1] == 0 ? 1 : 0,
		 [ [ 1, $text{'quota_unlimited'} ], [ 0, " " ] ])." ".
       &quota_inputbox(@_);
}

=head2 quota_inputbox(name, value, [blocksize])

Returns an input for selecting a quota. Mainly for internal use.

=cut
sub quota_inputbox
{
if ($_[2]) {
	# We know the real size, so can offer units
	local $sz = $_[1]*$_[2];
	local $units = 1;
	if ($sz >= 10*1024*1024*1024) {
		$units = 1024*1024*1024;
		}
	elsif ($sz >= 10*1024*1024) {
		$units = 1024*1024;
		}
	elsif ($sz >= 10*1024) {
		$units = 1024;
		}
	else {
		$units = 1;
		}
	$sz = $sz == 0 ? "" : sprintf("%.2f", ($sz*1.0)/$units);
	return &ui_textbox($_[0], $sz, 8).
	       &ui_select($_[0]."_units", $units,
			 [ [ 1, "bytes" ], [ 1024, "kB" ], [ 1024*1024, "MB" ],
			   [ 1024*1024*1024, "GB" ] ]);
	}
else {
	# Just show blocks
	return &ui_textbox($_[0], $_[1] == 0 ? "" : $_[1], 8);
	}
}

=head2 quota_parse(name, [bsize], [nodef])

Parses inputs from the form generated by quota_input.

=cut
sub quota_parse
{
if ($in{$_[0]."_def"} && !$_[2]) {
	return 0;
	}
elsif ($_[1]) {
	# Include units, and covert to blocks
	return int($in{$_[0]}*$in{$_[0]."_units"}/$_[1]);
	}
else {
	# Just use blocks
	return int($in{$_[0]});
	}
}

=head2 can_edit_filesys(filesys)

Returns 1 if the current Webmin user can manage quotas on some filesystem.

=cut
sub can_edit_filesys
{
local $fs;
foreach $fs (split(/\s+/, $access{'filesys'})) {
	return 1 if ($fs eq "*" || $fs eq $_[0]);
	}
return 0;
}

=head2 can_edit_user(user)

Returns 1 if the current Webmin user can manage quotas for some Unix user.

=cut
sub can_edit_user
{
if ($access{'umode'} == 0) {
	return 1;
	}
elsif ($access{'umode'} == 3) {
	local @u = getpwnam($_[0]);
	return $access{'users'} == $u[3];
	}
elsif ($access{'umode'} == 4) {
	local @u = getpwnam($_[0]);
	return (!$access{'umin'} || $u[2] >= $access{'umin'}) &&
	       (!$access{'umax'} || $u[2] <= $access{'umax'});
	}
else {
	local %ucan = map { $_, 1 } split(/\s+/, $access{'users'});
	return $access{'umode'} == 1 && $ucan{$_[0]} ||
	       $access{'umode'} == 2 && !$ucan{$_[0]};
	}
}

=head2 can_edit_group(group)

Returns 1 if the current Webmin user can manage quotas for some Unix group.

=cut
sub can_edit_group
{
if ($access{'gmode'} == 0) {
	return 1;
	}
elsif ($access{'gmode'} == 3) {
	return 0;
	}
elsif ($access{'gmode'} == 4) {
	local @g = getgrnam($_[0]);
	return (!$access{'gmin'} || $g[2] >= $access{'gmin'}) &&
	       (!$access{'gmax'} || $g[2] <= $access{'gmax'});
	}
else {
	local %gcan = map { $_, 1 } split(/\s+/, $access{'groups'});
	return $access{'gmode'} == 1 && $gcan{$_[0]} ||
	       $access{'gmode'} == 2 && !$gcan{$_[0]};
	}
}

=head2 filesystem_info(filesystem, &hash, count, [blocksize])

Returns two strings containing information about the amount of disk space
granted and used on some filesystem. For internal use.

=cut
sub filesystem_info
{
local @fs = &free_space($_[0], $_[3]);
if ($_[3]) {
	local $i;
	foreach $i (0 .. 3) {
		$fs[$i] = $i < 2 ? &nice_size($fs[$i]*$_[3])
				 : int($fs[$i]);
		}
	}
if ($_[1]) {
	local $bt = 0;
	local $ft = 0;
	local $i;
	for($i=0; $i<$_[2]; $i++) {
		$bt += $_[1]->{$i,'hblocks'};
		$ft += $_[1]->{$i,'hfiles'};
		}
	if ($_[3]) {
		$bt = &nice_size($bt*$_[3]);
		}
	return ( "$fs[0] total / $fs[1] free / $bt granted",
		 "$fs[2] total / $fs[3] free / $ft granted" );
	}
else {
	return ( "$fs[0] total / $fs[1] free",
		 "$fs[2] total / $fs[3] free" );
	}
}

=head2 block_size(dir, [for-filesys])

Returns the size (in bytes) of blocks on some filesystem, if known. All
quota functions deal with blocks, so they must be multiplied by the value
returned by this function before display to users.

=cut
sub block_size
{
return undef if (!$config{'block_mode'});
return undef if (!defined(&quota_block_size) &&
		 !defined(&fs_block_size));
local @mounts = &mount::list_mounted();
local ($mount) = grep { $_->[0] eq $_[0] } @mounts;
if ($mount) {
	if ($_[1]) {
		return &fs_block_size(@$mount);
		}
	else {
		if (defined(&quota_block_size)) {
			return &quota_block_size(@$mount);
			}
		else {
			return &fs_block_size(@$mount);
			}
		}
	}
return undef;
}

=head2 nice_limit(amount, bsize, no-blocks)

Internal function to show a quota limit nicely formatted.

=cut
sub nice_limit
{
local ($amount, $bsize, $noblocks) = @_;
return $amount == 0 ? $text{'quota_unlimited'} :
       $bsize && !$noblocks ? &nice_size($amount*$bsize) : $amount;
}

=head2 find_email_job

Returns the cron job hash ref for the quota limit monitoring email job.

=cut
sub find_email_job
{
&foreign_require("cron", "cron-lib.pl");
local @jobs = &cron::list_cron_jobs();
local ($job) = grep { $_->{'command'} eq $email_cmd } @jobs;
return $job;
}

=head2 create_email_job

Creates the cron job for scheduled emailing, which runs every 10 minutes.

=cut
sub create_email_job
{
&foreign_require("cron", "cron-lib.pl");
local $job = &find_email_job();
if (!$job) {
	$job = { 'user' => 'root',
		 'command' => $email_cmd,
		 'active' => 1,
		 'mins' => '0,10,20,30,40,50',
		 'hours' => '*',
		 'days' => '*',
		 'months' => '*',
		 'weekdays' => '*' };
	&lock_file(&cron::cron_file($job));
	&cron::create_cron_job($job);
	&cron::create_wrapper($email_cmd, $module_name, "email.pl");
	&unlock_file(&cron::cron_file($job));
	}
}

=head2 trunc_space(string)

Removes spaces from the start and end of a string.

=cut
sub trunc_space
{
local $rv = $_[0];
$rv =~ s/^\s+//;
$rv =~ s/\s+$//;
return $rv;
}

=head2 to_percent(used, total)

Converts an amount used and a total into a percentage.

=cut
sub to_percent
{
if ($_[1]) {
	return $_[0]*100/$_[1];
	}
else {
	return 0;
	}
}

=head2 select_grace_units(name, value)

Returns a menu for selecting grace time units.

=cut
sub select_grace_units
{
local @uarr = &grace_units();
return &ui_select($_[0], $_[1],
	[ map { [ $_, $uarr[$_] ] } (0..$#uarr) ]);
}

# resolve_and_simplify(path)
# Resolve symlinks from a path, and simplify the result to remove dots
sub resolve_and_simplify
{
my ($path) = @_;
return &simplify_path(&resolve_links($path));
}

1;

