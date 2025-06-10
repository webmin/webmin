# macos-lib.pl
# Quota functions for OSX
# XXX checking if on/off

# quotas_init()
sub quotas_init
{
if (&has_command("quotaon") && &has_command("quotaoff")) {
	return undef;
	}
else {
	return "The quotas programs do not appear to be installed on ".
	       "your system\n";
	}
}

# quotas_supported()
# Returns 1 for user quotas, 2 for group quotas or 3 for both
sub quotas_supported
{
return 3;
}

# free_space(filesystem)
# Returns an array containing  btotal, bfree, ftotal, ffree
sub free_space
{
local(@out, @rv);
$ENV{'BLOCKSIZE'} = 1024;
`df -i $_[0]` =~ /Mounted on\n\S+\s+(\d+)\s+\d+\s+(\d+)\s+\S+\s+(\d+)\s+(\d+)/;
return ($1, $2, $3+$4, $4);
}

# quota_can(&mnttab, &fstab)
# Can this filesystem type support quotas?
#  0 = No quota support (or not turned on in /etc/fstab)
#  1 = User quotas only
#  2 = Group quotas only
#  3 = User and group quotas
sub quota_can
{
return 0 if ($_[0]->[2] ne 'ufs' && $_[0]->[2] ne 'hfs');
return &quota_now($_[0], $_[1]) || 3;	# use the current mode if active
}

# quota_now(&mnttab, &fstab)
# Are quotas currently active?
#  0 = Not active
#  1 = User quotas active
#  2 = Group quotas active
#  3 = Both active
sub quota_now
{
local $rv;
$rv += 1 if (-r "$_[0]->[0]/.quota.ops.user" &&
	     &big_enough("$_[0]->[0]/.quota.user"));
$rv += 2 if (-r "$_[0]->[0]/.quota.ops.group" &&
	     &big_enough("$_[0]->[0]/.quota.group"));
return $rv;
}

# quotaon(filesystem, mode)
# Activate quotas and create quota files for some filesystem. The mode can
# be 1 for user only, 2 for group only or 3 for user and group
sub quotaon
{
return if (&is_readonly_mode());
local($out, $qf, @qfile, $flags);
if ($_[1]%2 == 1) {
	# turn on user quotas
	$qf = "$_[0]/.quota.ops.user";
	&open_tempfile(QUOTAFILE, ">$qf", 0, 1);
	&close_tempfile(QUOTAFILE);
	$qf = "$_[0]/.quota.user";
	if (!&big_enough($qf)) {
		&unlink_file($qf);
		&system_logged("$config{'quotacheck_command'} $_[0]");
		}
	$out = &backquote_logged("$config{'user_quotaon_command'} $_[0] 2>&1");
	if ($?) { return $out; }
	}
if ($_[1] > 1) {
	# turn on group quotas
	$qf = "$_[0]/.quota.ops.group";
	&open_tempfile(QUOTAFILE, ">$qf", 0, 1);
	&close_tempfile(QUOTAFILE);
	$qf = "$_[0]/quota.group";
	if (!&big_enough($qf)) {
		&unlink_file($qf);
		&system_logged("$config{'quotacheck_command'} $_[0]");
		}
	$out = &backquote_logged("$config{'group_quotaon_command'} $_[0] 2>&1");
	if ($?) { return $out; }
	}
return undef;
}

sub big_enough
{
local @st = stat($_[0]);
return $st[7] >= 1024;
}


# quotaoff(filesystem, mode)
# Turn off quotas for some filesystem
sub quotaoff
{
return if (&is_readonly_mode());
local($out);
if ($_[1]%2 == 1) {
	$out = &backquote_logged("$config{'user_quotaoff_command'} $_[0] 2>&1");
	if ($?) { return $out; }
	&unlink_file("$_[0]/.quota.ops.user");
	}
if ($_[1] > 1) {
	$out = &backquote_logged("$config{'group_quotaoff_command'} $_[0] 2>&1");
	if ($?) { return $out; }
	&unlink_file("$_[0]/.quota.ops.group");
	}
return undef;
}

# user_filesystems(user)
# Fills the array %filesys with details of all filesystem some user has
# quotas on
sub user_filesystems
{
local($n, $_, %mtab);
open(QUOTA, "$config{'user_quota_command'} ".quotemeta($_[0])." |");
$n=0; while(<QUOTA>) {
	chop;
	if (/^(Disk|\s+Filesystem)/) { next; }
	if (/^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+).(.{9})\s+(\S+)\s+(\S+)\s+(\S+)/) {
		$filesys{$n,'filesys'} = $1;
		$filesys{$n,'ublocks'} = int($2);
		$filesys{$n,'sblocks'} = int($3);
		$filesys{$n,'hblocks'} = int($4);
		$filesys{$n,'ufiles'} = int($6);
		$filesys{$n,'sfiles'} = int($7);
		$filesys{$n,'hfiles'} = int($8);
		$n++;
		}
	}
close(QUOTA);
return $n;
}

# group_filesystems(group)
# Fills the array %filesys with details of all filesystem some group has
# quotas on
sub group_filesystems
{
local($n, $_, %mtab);
open(QUOTA, "$config{'group_quota_command'} ".quotemeta($_[0])." |");
$n=0; while(<QUOTA>) {
	chop;
	if (/^(Disk|\s+Filesystem)/) { next; }
	if (/^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+).(.{9})\s+(\S+)\s+(\S+)\s+(\S+)/) {
		$filesys{$n,'filesys'} = $1;
		$filesys{$n,'ublocks'} = int($2);
		$filesys{$n,'sblocks'} = int($3);
		$filesys{$n,'hblocks'} = int($4);
		$filesys{$n,'ufiles'} = int($6);
		$filesys{$n,'sfiles'} = int($7);
		$filesys{$n,'hfiles'} = int($8);
		$n++;
		}
	}
close(QUOTA);
return $n;
}

# filesystem_users(filesystem)
# Fills the array %user with information about all users with quotas
# on this filesystem. This may not be all users on the system..
sub filesystem_users
{
local($rep, @rep, $n, $what);
$rep = `$config{'user_repquota_command'} $_[0] 2>&1`;
if ($?) { return -1; }
@rep = split(/\n/, $rep);
@rep = grep { !/^root\s/ } @rep[3..$#rep];
for($n=0; $n<@rep; $n++) {
	if ($rep[$n] =~ /(\S+)\s*[\-\+]{2}\s+(\d+)\s+(\d+)\s+(\d+)\s.{0,15}\s(\d+)\s+(\d+)\s+(\d+)/ || $rep[$n] =~ /(\S+)\s+..(.{8})(.{8})(.{8}).{7}(.{8})(.{8})(.{8})/) {
		$user{$n,'user'} = $1;
		$user{$n,'ublocks'} = int($2);
		$user{$n,'sblocks'} = int($3);
		$user{$n,'hblocks'} = int($4);
		$user{$n,'ufiles'} = int($5);
		$user{$n,'sfiles'} = int($6);
		$user{$n,'hfiles'} = int($7);
		}
	}
return $n;
}

# filesystem_groups(filesystem)
# Fills the array %group with information about all groups with quotas
# on this filesystem. This may not be all groups on the system..
sub filesystem_groups
{
local($rep, @rep, $n, $what);
$rep = `$config{'group_repquota_command'} $_[0] 2>&1`;
if ($?) { return -1; }
@rep = split(/\n/, $rep);
@rep = @rep[3..$#rep];
for($n=0; $n<@rep; $n++) {
	if ($rep[$n] =~ /(\S+)\s*[\-\+]{2}\s+(\d+)\s+(\d+)\s+(\d+)\s.{0,15}\s(\d+)\s+(\d+)\s+(\d+)/ || $rep[$n] =~ /(\S+)\s+..(.{8})(.{8})(.{8}).{7}(.{8})(.{8})(.{8})/) {
		$group{$n,'group'} = $1;
		$group{$n,'ublocks'} = int($2);
		$group{$n,'sblocks'} = int($3);
		$group{$n,'hblocks'} = int($4);
		$group{$n,'ufiles'} = int($5);
		$group{$n,'sfiles'} = int($6);
		$group{$n,'hfiles'} = int($7);
		}
	}
return $n;
}

# edit_quota_file(data, filesys, sblocks, hblocks, sfiles, hfiles)
sub edit_quota_file
{
local($rv, $line, %mtab, @m);
@line = split(/\n/, $_[0]);
for($i=0; $i<@line; $i++) {
	if ($line[$i] =~ /^(\S+): (.*) in use: (\d+), limits \(soft = (\d+), hard = (\d+)\)$/ && $1 eq $_[1]) {
		# found lines to change
		$rv .= "$1: $2 in use: $3, limits (soft = $_[2], hard = $_[3])\n";
		$line[++$i] =~ /^\s*inodes in use: (\d+), limits \(soft = (\d+), hard = (\d+)\)$/;
		$rv .= "\tinodes in use: $1, limits (soft = $_[4], hard = $_[5])\n";
		}
	else { $rv .= "$line[$i]\n"; }
	}
return $rv;
}

# quotacheck(filesystem, mode)
# Runs quotacheck on some filesystem
sub quotacheck
{
$out = &backquote_logged("$config{'quotacheck_command'} $_[0] 2>&1");
if ($?) { return $out; }
return undef;
}

# copy_user_quota(user, [user]+)
# Copy the quotas for some user to many others
sub copy_user_quota
{
for($i=1; $i<@_; $i++) {
	$out = &backquote_logged("$config{'user_copy_command'} ".
				quotemeta($_[0])." ".quotemeta($_[$i])." 2>&1");
	if ($?) { return $out; }
	}
return undef;
}

# copy_group_quota(group, [group]+)
# Copy the quotas for some group to many others
sub copy_group_quota
{
for($i=1; $i<@_; $i++) {
	$out = &backquote_logged("$config{'group_copy_command'} ".
				quotemeta($_[0])." ".quotemeta($_[$i])." 2>&1");
	if ($?) { return $out; }
	}
return undef;
}

# default_grace()
# Returns 0 if grace time can be 0, 1 if zero grace means default
sub default_grace
{
return 0;
}

# get_user_grace(filesystem)
# Returns an array containing  btime, bunits, ftime, funits
# The units can be 0=sec, 1=min, 2=hour, 3=day
sub get_user_grace
{
local(@rv, %mtab, @m);
$ENV{'EDITOR'} = $ENV{'VISUAL'} = "cat";
open(GRACE, "$config{'user_grace_command'} $_[0] |");
while(<GRACE>) {
	if (/^(\S+): block grace period: (\d+) (\S+), file grace period: (\d+) (\S+)/ && $1 eq $_[0]) {
		@rv = ($2, $name_to_unit{$3}, $4, $name_to_unit{$5});
		}
	}
close(GRACE);
return @rv;
}

# get_group_grace(filesystem)
# Returns an array containing  btime, bunits, ftime, funits
# The units can be 0=sec, 1=min, 2=hour, 3=day
sub get_group_grace
{
local(@rv, %mtab, @m);
$ENV{'EDITOR'} = $ENV{'VISUAL'} = "cat";
open(GRACE, "$config{'group_grace_command'} $_[0] |");
while(<GRACE>) {
	if (/^(\S+): block grace period: (\d+) (\S+), file grace period: (\d+) (\S+)/ && $1 eq $_[0]) {
		@rv = ($2, $name_to_unit{$3}, $4, $name_to_unit{$5});
		}
	}
close(GRACE);
return @rv;
}

# edit_grace_file(data, filesystem, btime, bunits, ftime, funits)
sub edit_grace_file
{
local($rv, $line, @m, %mtab);
foreach $line (split(/\n/, $_[0])) {
	if ($line =~ /^(\S+): block grace period: (\d+) (\S+), file grace period: (\d+) (\S+)/ && $1 eq $_[1]) {
		# replace this line
		$line = "$1: block grace period: $_[2] $unit_to_name{$_[3]}, file grace period: $_[4] $unit_to_name{$_[5]}";
		}
	$rv .= "$line\n";
	}
return $rv;
}

# grace_units()
# Returns an array of possible units for grace periods
sub grace_units
{
return ($text{'grace_seconds'}, $text{'grace_minutes'}, $text{'grace_hours'},
	$text{'grace_days'});
}

# Always returns 1024 on MacOS
sub fs_block_size
{
return 1024;
}

%name_to_unit = ( "second", 0, "seconds", 0,
		  "minute", 1, "minutes", 1,
		  "hour", 2, "hours", 2,
		  "day", 3, "days", 3,
		);
foreach $k (keys %name_to_unit) {
	$unit_to_name{$name_to_unit{$k}} = $k;
	}

1;

