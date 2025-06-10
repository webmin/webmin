# solaris-lib.pl
# Quota functions for solaris 2.5+

# quotas_init()
sub quotas_init
{
return undef;
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
local($out);
$out = `df -t $_[0]`;
$out =~ /(\d+) blocks\s+(\d+) files\n.*\s+(\d+) blocks\s+(\d+) files/;
return ($3, $1, $4, $2);
}

# quota_can(&mnttab, &fstab)
# Can this filesystem type support quotas?
#  0 = No quota support (or not turned on in /etc/fstab)
#  1 = User quotas only
#  2 = Group quotas only
#  3 = User and group quotas
sub quota_can
{
return $_[0]->[2] eq "ufs" && $_[0]->[1] ne $_[0]->[0] ? 1 : 0;
}

# quota_now(&mnttab, &fstab)
# Are quotas currently active?
#  0 = Not active
#  1 = User quotas active
#  2 = Group quotas active
#  3 = Both active
sub quota_now
{
return $_[0]->[3] =~ /,quota/ || $_[0]->[3] =~ /^quota/ ? 1 : 0;
}

# filesystem_users(filesystem)
# Fills the array %user with information about all users with quotas
# on this filesystem. This may not be all users on the system..
sub filesystem_users
{
local($rep, @rep, $n, %hasu, @hasu, $u);
$rep = `$config{'user_repquota_command'} $_[0] 2>&1`;
if ($?) { return -1; }
setpwent();
while(@uinfo = getpwent()) {
	$hasu{$uinfo[0]} = $uinfo[2];
	push(@hasu, $uinfo[0]);
	}
endpwent();
@hasu = sort { $hasu{$a} <=> $hasu{$b} } @hasu;
@rep = split(/\n/, $rep); @rep = @rep[3..$#rep];
for($n=0; $n<@rep; $n++) {
	if ($rep[$n] =~ /(\S+)\s+[\-\+]{2}\s+(\d+)\s+(\d+)\s+(\d+)\s+(.{0,15})\s+(\d+)\s+(\d+)\s+(\d+)(.*)/ || $rep[$n] =~ /(\S+)\s+[\-\+]{2}(.{7})(.{7})(.{7})(.{13})(.{7})(.{7})(.{7})(.*)/) {
		$user{$n,'user'} = $1;
		$user{$n,'ublocks'} = int($2);
		$user{$n,'sblocks'} = int($3);
		$user{$n,'hblocks'} = int($4);
		$user{$n,'gblocks'} = $5;
		$user{$n,'ufiles'} = int($6);
		$user{$n,'sfiles'} = int($7);
		$user{$n,'hfiles'} = int($8);
		$user{$n,'gfiles'} = $9;
		$user{$n,'user'} =~ s/^#//g;
		if ($user{$n,'user'} !~ /^\d+$/ &&
		    !defined($hasu{$user{$n,'user'}})) {
			# Username was truncated! Try to find him..
			foreach $u (@hasu) {
				if (substr($u, 0, length($user{$n,'user'})) eq
				    $user{$n,'user'}) {
					# found him..
					$user{$n,'user'} = $u;
					@hasu = grep { $_ ne $u } @hasu;
					last;
					}
				}
			}
		$user{$nn,'gblocks'} = &trunc_space($user{$nn,'gblocks'});
		$user{$nn,'gfiles'} = &trunc_space($user{$nn,'gfiles'});
		}
	}
return $n;
}

# edit_quota_file(data, filesys, sblocks, hblocks, sfiles, hfiles)
sub edit_quota_file
{
local($rv, $line);
foreach $line (split(/\n/, $_[0])) {
	if ($line =~ /^fs (\S+) blocks \(soft = (\d+), hard = (\d+)\) inodes \(soft = (\d+), hard = (\d+)\)$/ && $1 eq $_[1]) {
		# found line to change
		$line = "fs $_[1] blocks (soft = $_[2], hard = $_[3]) inodes (soft = $_[4], hard = $_[5])";
		}
	$rv .= "$line\n";
	}
return $rv;
}

# quotaon(filesystem, mode)
# Activate quotas and create quota file for some filesystem. The mode can
# be 1 for user only, 2 for group only or 3 for user and group
sub quotaon
{
return if (&is_readonly_mode());
local($qf, $out);
$qf = "$_[0]/quotas";
if (!(-r $qf)) {
	&open_tempfile(QUOTAFILE, ">$qf", 0, 1);
	&close_tempfile(QUOTAFILE);
	&set_ownership_permissions(undef, undef, 0600, $qf);
	}
$out = &backquote_logged("$config{'user_quotaon_command'} $_[0] 2>&1");
if ($?) { return $out; }
return undef;
}

# quotaoff(filesystem, mode)
# Turn off quotas for some filesystem
sub quotaoff
{
return if (&is_readonly_mode());
local($out);
$out = &backquote_logged("$config{'user_quotaoff_command'} $_[0] 2>&1");
if ($?) { return $out; }
return undef;
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

# user_filesystems(user)
# Fills the array %filesys with details of all filesystems some user has
# quotas on
sub user_filesystems
{
local($n, $_);
open(QUOTA, "$config{'user_quota_command'} ".quotemeta($_[0])." |");
$n=0; while(<QUOTA>) {
	chop;
	if (/^(Disk|Filesystem)/i) { next; }
	if (/^(\S+)$/) {
		# Bogus wrapped line!
		$filesys{$n,'filesys'} = $1;
		local $nl = <QUOTA>;
		if ($nl =~ /^\s+(\d+)\s+(\d+)\s+(\d+)\s(.{0,15})\s+(\d+)\s+(\d+)\s+(\d+)(.*)/ || $nl =~ /^.{13}(.{7})(.{7})(.{7})(.{12})(.{7})(.{7})(.{7})(.*)/) {
			$filesys{$n,'ublocks'} = int($1);
			$filesys{$n,'sblocks'} = int($2);
			$filesys{$n,'hblocks'} = int($3);
			$filesys{$n,'gblocks'} = $4;
			$filesys{$n,'ufiles'} = int($5);
			$filesys{$n,'sfiles'} = int($6);
			$filesys{$n,'hfiles'} = int($7);
			$filesys{$n,'gfiles'} = $8;
			$filesys{$n,'gblocks'} = &trunc_space($filesys{$n,'gblocks'});
			$filesys{$n,'gfiles'} = &trunc_space($filesys{$n,'gfiles'});
			$n++;
			}
		}
	elsif (/^(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s(.{0,15})\s+(\d+)\s+(\d+)\s+(\d+)(.*)/ || /^(.{13})(.{7})(.{7})(.{7})(.{12})(.{7})(.{7})(.{7})(.*)/) {
		$filesys{$n,'filesys'} = $1;
		$filesys{$n,'ublocks'} = int($2);
		$filesys{$n,'sblocks'} = int($3);
		$filesys{$n,'hblocks'} = int($4);
		$filesys{$n,'gblocks'} = $5;
		$filesys{$n,'ufiles'} = int($6);
		$filesys{$n,'sfiles'} = int($7);
		$filesys{$n,'hfiles'} = int($8);
		$filesys{$n,'gfiles'} = $9;
		$filesys{$n,'filesys'} =~ s/\s+$//g;
		$filesys{$n,'gblocks'} = &trunc_space($filesys{$n,'gblocks'});
		$filesys{$n,'gfiles'} = &trunc_space($filesys{$n,'gfiles'});
		$n++;
		}
	}
close(QUOTA);
return $n;
}

# get_user_grace(filesystem)
# Returns an array containing  btime, bunits, ftime, funits
# The units can be 0=sec, 1=min, 2=hour, 3=day, 4=week, 5=month
sub get_user_grace
{
local(@rv);
$ENV{'EDITOR'} = $ENV{'VISUAL'} = "cat";
open(GRACE, "$config{'user_grace_command'} |");
while(<GRACE>) {
	if (/^fs (\S+) blocks time limit = ([0-9\.]+) (\S+), files time limit = ([0-9\.]+) (\S+)/ && $1 eq $_[0]) {
		if ($2 == 0) { push(@rv, 0, 0); }
		else { push(@rv, $2, $name_to_unit{$3}); }
		if ($4 == 0) { push(@rv, 0, 0); }
		else { push(@rv, $4, $name_to_unit{$5}); }
		}
	}
close(GRACE);
return @rv;
}

# default_grace()
# Returns 0 if grace time can be 0, 1 if zero grace means default
sub default_grace
{
return 1;
}

# edit_grace_file(data, filesystem, btime, bunits, ftime, funits)
sub edit_grace_file
{
local($rv, $line);
foreach $line (split(/\n/, $_[0])) {
	if ($line =~ /^fs (\S+) blocks time limit = ([0-9\.]+) (\S+), files time limit = ([0-9\.]+) (\S+)/ && $1 eq $_[1]) {
		# replace this line
		$line = "fs $_[1] blocks time limit = $_[2] $unit_to_name{$_[3]}, files time limit = $_[4] $unit_to_name{$_[5]}";
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

# quota_block_size(dir, device, filesystem)
# Returns the size of quota blocks on some filesystem, or undef if unknown.
# Always 1024, even though *filesystem* blocks are not!
sub quota_block_size
{
return 1024;
}

# fs_block_size(dir, device, filesystem)
# Returns the size of blocks on some filesystem, or undef if unknown.
sub fs_block_size
{
if ($_[2] eq "ufs") {
	local $kout = `df -k $_[0]`;
	local $bout = `df -t $_[0]`;
	if ($kout =~ /\n\Q$_[1]\E\s+(\d+)/) {
		local $ks = $1;
		if ($bout =~ /total\s*:\s*(\d+)\s+blocks/) {
			local $bs = $1;
			return ($ks*1024) / $bs;
			}
		}
	}
return 1024;
}

%name_to_unit = ( "sec", 0, "secs", 0,
		  "min", 1, "mins", 1,
		  "hour", 2, "hours", 2,
		  "day", 3, "days", 3,
		  "week", 4, "weeks", 4,
		  "month", 5, "months", 5
		);
foreach $k (keys %name_to_unit) {
	$unit_to_name{$name_to_unit{$k}} = $k;
	}

1;

