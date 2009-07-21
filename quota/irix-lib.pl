# openbsd-lib.pl
# Quota functions for openbsd

# quotas_init()
sub quotas_init
{
if (-x "/usr/etc/repquota") {
	return undef;
	}
else {
	return "The quotas product does not appear to be installed on ".
	       "your system\n";
	}
}

# quotas_supported()
# Returns 1 for user quotas, 2 for group quotas or 3 for both
sub quotas_supported
{
return 1;
}

# free_space(filesystem)
# Returns an array containing  btotal, bfree, ftotal, ffree
sub free_space
{
local(@out, @rv);
`df -i '$_[0]'` =~ /Mounted\n\S+\s+\S+\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/;
return ($1, $3, $5+$6, $6);
}

# quota_can(&mnttab, &fstab)
# Can this filesystem type support quotas?
#  0 = No quota support (or not turned on in /etc/fstab)
#  1 = User quotas only
#  2 = Group quotas only
#  3 = User and group quotas
sub quota_can
{
return $_[1]->[2] eq 'xfs' && $_[1]->[3] =~ /quota|qnoenforce/ ? 1 : 0;
}

# quota_now(&mnttab, &fstab)
# Are quotas currently active?
#  0 = Not active
#  1 = User quotas active
#  2 = Group quotas active
#  3 = Both active
# Adding 4 means they cannot be turned off (such as for XFS)
sub quota_now
{
return $_[0]->[3] =~ /quota|qnoenforce/ ? 5 : 0;
}

# quotaon(filesystem, mode)
# Activate quotas and create quota files for some filesystem. The mode can
# be 1 for user only, 2 for group only or 3 for user and group
sub quotaon
{
# Does nothing, because XFS quotas are only enabled at mount/boot
return undef;
}

# quotaoff(filesystem, mode)
# Turn off quotas for some filesystem
sub quotaoff
{
# Does nothing, because XFS quotas are never turned off
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
	if (/^\s*(Disk|Filesystem)/) { next; }
	if (/^(\S+)$/) {
		# Bogus wrapped line
		$filesys{$n,'filesys'} = $1;
		<QUOTA> =~ /^\s+(\d+)\s+(\d+)\s+(\d+)\s.{0,17}\s(\d+)\s+(\d+)\s+(\d+)/;
		$filesys{$n,'ublocks'} = int($1);
		$filesys{$n,'sblocks'} = int($2);
		$filesys{$n,'hblocks'} = int($3);
		$filesys{$n,'ufiles'} = int($4);
		$filesys{$n,'sfiles'} = int($5);
		$filesys{$n,'hfiles'} = int($6);
		$n++;
		}
	elsif (/^(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s.{0,17}\s(\d+)\s+(\d+)\s+(\d+)/) {
		$filesys{$n,'ublocks'} = int($2);
		$filesys{$n,'sblocks'} = int($3);
		$filesys{$n,'hblocks'} = int($4);
		$filesys{$n,'ufiles'} = int($5);
		$filesys{$n,'sfiles'} = int($6);
		$filesys{$n,'hfiles'} = int($7);
		$filesys{$n,'filesys'} = $1;
		$filesys{$n,'filesys'} =~ s/^\s+//g;
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
local($rep, @rep, $n = 0, $r);
$rep = `$config{'user_repquota_command'} $_[0] 2>&1`;
if ($?) { return -1; }
@rep = split(/\n/, $rep);
foreach $r (@rep) {
	if ($r =~ /(\S+)\s*[\-\+]{2}\s+(\d+)\s+(\d+)\s+(\d+)\s.{0,16}\s(\d+)\s+(\d+)\s+(\d+)/) {
		$user{$n,'user'} = $1;
		$user{$n,'ublocks'} = int($2);
		$user{$n,'sblocks'} = int($3);
		$user{$n,'hblocks'} = int($4);
		$user{$n,'ufiles'} = int($5);
		$user{$n,'sfiles'} = int($6);
		$user{$n,'hfiles'} = int($7);
		$n++;
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
	if ($line[$i] =~ /^fs\s+(\S+)\s+kbytes\s+\(soft = (\d+), hard = (\d+)\)\s+inodes\s+\(soft = (\d+), hard = (\d+)\)/ && $1 eq $_[1]) {
		# found line to change
		$rv .= "fs $1 kbytes (soft = $_[2], hard = $_[3]) inodes (soft = $_[4], hard = $_[5])\n";
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

# default_grace()
# Returns 0 if grace time can be 0, 1 if zero grace means default
sub default_grace
{
return 1;
}

# get_user_grace(filesystem)
# Returns an array containing  btime, bunits, ftime, funits
# The units can be 0=sec, 1=min, 2=hour, 3=day
sub get_user_grace
{
local(@rv, %mtab, @m);
$ENV{'EDITOR'} = $ENV{'VISUAL'} = "cat";
open(GRACE, "$config{'user_grace_command'} $_[0] 2>/dev/null |");
while(<GRACE>) {
	if (/^fs\s+(\S+)\s+kbytes\s+time\s+limit\s+=\s+(\S+)\s+(\S+),\s+files\s+time\s+limit\s+=\s+(\S+)\s+(\S+)/) {
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
	if ($line =~ /^fs\s+(\S+)\s+kbytes\s+time\s+limit\s+=\s+(\S+)\s+(\S+),\s+files\s+time\s+limit\s+=\s+(\S+)\s+(\S+)/ && $1 eq $_[1]) {
		# replace this line
		$line = "fs $1 kbytes time limit = $_[2] $unit_to_name{$_[3]}, files time limit = $_[4] $unit_to_name{$_[5]}";
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
	$text{'grace_days'}, $text{'grace_weeks'}, $text{'grace_months'});
}

%name_to_unit = ( "second", 0, "seconds", 0,
		  "minute", 1, "minutes", 1,
		  "hour", 2, "hours", 2,
		  "day", 3, "days", 3,
		  "week", 4, "weeks", 4,
		  "month", 5, "months", 5,
		);
foreach $k (keys %name_to_unit) {
	$unit_to_name{$name_to_unit{$k}} = $k;
	}

1;

