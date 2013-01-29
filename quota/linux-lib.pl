=head1 linux-lib.pl

Quota functions for all linux version. See quota-lib.pl for summary
documentation for this module.

=cut

# Tell the mount module not to check which filesystems are supported,
# as we don't care for the calls made by this module
$mount::no_check_support = 1;

# Pass UIDs and GIDs to edquota instead of names
$edquota_use_ids = 1;

=head2 quotas_init

Returns an error message if some quota commands or functionality is missing
on this system, undef otherwise.

=cut
sub quotas_init
{
if (&has_command("quotaon") && &has_command("quotaoff")) {
	return undef;
	}
else {
	return "The quotas package does not appear to be installed on ".
	       "your system\n";
	}
}

=head2 quotas_supported

Checks what quota types this OS supports. Returns 1 for user quotas,
2 for group quotas or 3 for both.

=cut
sub quotas_supported
{
return 3;
}

=head2 free_space(filesystem, [blocksize])

Finds the amount of free disk space on some system. Returns an array
containing : blocks-total, blocks-free, files-total, files-free

=cut
sub free_space
{
local(@out, @rv);
$out = &backquote_command("df -k $_[0]");
$out =~ /Mounted on\n\S+\s+(\d+)\s+\d+\s+(\d+)/;
if ($_[1]) {
	push(@rv, int($1*1024/$_[1]), int($2*1024/$_[1]));
	}
else {
	push(@rv, $1, $2);
	}
$out = &backquote_command("df -i $_[0]");
$out =~ /Mounted on\n\S+\s+(\d+)\s+\d+\s+(\d+)/;
push(@rv, $1, $2);
return @rv;
}

=head2 quota_can(&mnttab, &fstab)

Can this filesystem type support quotas? Takes array refs from mounted and
mountable filesystems, and returns one of the following :

=item 0 - No quota support (or not turned on in /etc/fstab).

=item 1 - User quotas only.

=item 2 - Group quotas only.

=item 3 - User and group quotas.

=cut
sub quota_can
{
return ($_[1]->[3] =~ /usrquota|usrjquota/ ||
	$_[0]->[3] =~ /usrquota|usrjquota/ ? 1 : 0) +
       ($_[1]->[3] =~ /grpquota|grpjquota/ ||
        $_[0]->[3] =~ /grpquota|grpjquota/ ? 2 : 0);
}

=head2 quota_now(&mnttab, &fstab)

Are quotas currently active? Takes array refs from mounted and mountable
filesystems, and returns one of the following :

=item 0 - Not active.
=item 1 - User quotas active.
=item 2 - Group quotas active.
=item 3 - Both active.

Adding 4 means they cannot be turned off (such as for XFS)

=cut
sub quota_now
{
local $rv = 0;
local $dir = $_[0]->[0];
local %opts = map { $_, 1 } split(/,/, $_[0]->[3]);
local $ufile = $_[1]->[3] =~ /(usrquota|usrjquota)=([^, ]+)/ ? $2 : undef;
local $gfile = $_[1]->[3] =~ /(grpquota|grpjquota)=([^, ]+)/ ? $2 : undef;
if ($_[0]->[2] eq "xfs") {
	# For XFS, assume enabled if setup in fstab
	$rv += 1 if ($opts{'quota'} || $opts{'usrquota'} ||
		     $opts{'uqnoenforce'});
	$rv += 2 if ($opts{'grpquota'} || $opts{'gqnoenforce'});
	return $rv + 4;
	}
if ($_[0]->[4]%2 == 1) {
	# test user quotas
	if (-r "$dir/quota.user" || -r "$dir/aquota.user" ||
	    $ufile && -r "$dir/$ufile") {
		local $stout = &supports_status($dir, "user");
		if ($stout =~ /is\s+(on|off|enabled|disabled)/) {
			# Can use output from -p mode
			if ($stout =~ /is\s+(on|enabled)/) {
				$rv += 1;
				}
			}
		else {
			# Fall back to testing by running quotaon
			&clean_language();
			$out = &backquote_command(
				"$config{'user_quotaon_command'} $dir 2>&1");
			&reset_environment();
			if ($out =~ /Device or resource busy/i) {
				# already on..
				$rv += 1;
				}
			elsif ($out =~ /Package not installed/i) {
				# No quota support!
				return 0;
				}
			else {
				# was off.. need to turn on again
				&execute_command(
				  "$config{'user_quotaoff_command'} $dir 2>&1");
				}
			}
		}
	}
if ($_[0]->[4] > 1) {
	# test group quotas
	if (-r "$dir/quota.group" || -r "$dir/aquota.group" ||
	    $gfile && -r "$dir/$gfile") {
		local $stout = &supports_status($dir, "group");
		if ($stout =~ /is\s+(on|off|enabled|disabled)/) {
			# Can use output from -p mode
			if ($stout =~ /is\s+(on|enabled)/) {
				$rv += 2;
				}
			}
		else {
			# Fall back to testing by running quotaon
			&clean_language();
			$out = &backquote_command(
				"$config{'group_quotaon_command'} $dir 2>&1");
			&reset_environment();
			if ($out =~ /Device or resource busy/i) {
				# already on..
				$rv += 2;
				}
			elsif ($out =~ /Package not installed/i) {
				# No quota support!
				return 0;
				}
			else {
				# was off.. need to turn on again
				&execute_command(
				 "$config{'group_quotaoff_command'} $dir 2>&1");
				}
			}
		}
	}
return $rv;
}

=head2 supports_status(dir, mode)

Internal function to check if the quotaon -p flag is supported.

=cut
sub supports_status
{
if (!defined($supports_status_cache{$_[0],$_[1]})) {
	&clean_language();
	local $stout = &backquote_command(
		"$config{$_[1].'_quotaon_command'} -p $_[0] 2>&1");
	&reset_environment();
	$supports_status_cache{$_[0],$_[1]} =
		$stout =~ /is\s+(on|off|enabled|disabled)/ ? $stout : 0;
	}
return $supports_status_cache{$_[0],$_[1]};
}

=head2 quotaon(filesystem, mode)

Activate quotas and create quota files for some filesystem. The mode can
be one of :

=item 1 - User only.

=item 2 - Group only.

=item 3 - User and group.

=cut
sub quotaon
{
local($out, $qf, @qfile, $flags, $version);
return if (&is_readonly_mode());

# Check which version of quota is being used
$out = &backquote_command("quota -V 2>&1");
if ($out =~ /\s(\d+\.\d+)/) {
	$version = $1;
	}

# Force load of quota kernel modules
&system_logged("modprobe quota_v2 >/dev/null 2>&1");

local $fmt = $version >= 2 ? "vfsv0" : "vfsold";
if ($_[1]%2 == 1) {
	# turn on user quotas
	local $qf = $version >= 2 ? "aquota.user" : "quota.user";
	if (!-s "$_[0]/$qf") {
		# Setting up for the first time
		local $ok = 0;
		if (&has_command("convertquota") && $version >= 2) {
			# Try creating a quota.user file and converting it
			&open_tempfile(QUOTAFILE, ">>$_[0]/quota.user", 0, 1);
			&close_tempfile(QUOTAFILE);
			&set_ownership_permissions(undef, undef, 0600,
						   "$_[0]/quota.user");
			&system_logged("convertquota -u $_[0] 2>&1");
			$ok = 1 if (!$?);
			&unlink_file("$_[0]/quota.user");
			}
		if (!$ok) {
			# Try to create an [a]quota.user file
			if ($version < 4) {
				&open_tempfile(QUOTAFILE, ">>$_[0]/$qf", 0, 1);
				&close_tempfile(QUOTAFILE);
				&set_ownership_permissions(undef, undef, 0600,
							   "$_[0]/$qf");
				}
			&run_quotacheck($_[0]) ||
				&run_quotacheck($_[0], "-u -f") ||
				&run_quotacheck($_[0], "-u -f -m") ||
				&run_quotacheck($_[0], "-u -f -m -c");
				&run_quotacheck($_[0], "-u -f -m -c -F $fmt");
			}
		}
	$out = &backquote_logged("$config{'user_quotaon_command'} $_[0] 2>&1");
	if ($?) { return $out; }
	}
if ($_[1] > 1) {
	# turn on group quotas
	local $qf = $version >= 2 ? "aquota.group" : "quota.group";
	if (!-s "$_[0]/$qf") {
		# Setting up for the first time
		local $ok = 0;
		if (!$ok && &has_command("convertquota") && $version >= 2) {
			# Try creating a quota.group file and converting it
			&open_tempfile(QUOTAFILE, ">>$_[0]/quota.group", 0, 1);
			&close_tempfile(QUOTAFILE);
			&set_ownership_permissions(undef, undef, 0600,
						   "$_[0]/quota.group");
			&system_logged("convertquota -g $_[0] 2>&1");
			$ok = 1 if (!$?);
			&unlink_file("$_[0]/quota.group");
			}
		if (!$ok) {
			# Try to create an [a]quota.group file
			if ($version < 4) {
				&open_tempfile(QUOTAFILE, ">>$_[0]/$qf", 0, 1);
				&close_tempfile(QUOTAFILE);
				&set_ownership_permissions(undef, undef, 0600,
							   "$_[0]/$qf");
				}
			&run_quotacheck($_[0]) ||
				&run_quotacheck($_[0], "-g -f") ||
				&run_quotacheck($_[0], "-g -f -m") ||
				&run_quotacheck($_[0], "-g -f -m -c") ||
				&run_quotacheck($_[0], "-g -f -m -c -F $fmt");
			}
		}
	$out = &backquote_logged("$config{'group_quotaon_command'} $_[0] 2>&1");
	if ($?) { return $out; }
	}
return undef;
}

=head2 run_quotacheck(filesys, args)

Runs the quotacheck command on some filesytem, and returns 1 on success or
0 on failure. Mainly for internal use when enabling quotas.

=cut
sub run_quotacheck
{
&clean_language();
local $out =&backquote_logged(
	"$config{'quotacheck_command'} $_[1] $_[0] 2>&1");
&reset_environment();
return $? || $out =~ /cannot guess|cannot remount|cannot find|please stop/i ? 0 : 1;
}

=head2 quotaoff(filesystem, mode)

Turn off quotas for some filesystem. Mode must be 0 for users only, 1 for
groups only, or 2 for both.

=cut
sub quotaoff
{
return if (&is_readonly_mode());
local($out);
if ($_[1]%2 == 1) {
	$out = &backquote_logged("$config{'user_quotaoff_command'} $_[0] 2>&1");
	if ($?) { return $out; }
	}
if ($_[1] > 1) {
	$out = &backquote_logged("$config{'group_quotaoff_command'} $_[0] 2>&1");
	if ($?) { return $out; }
	}
return undef;
}

=head2 user_filesystems(user)

Fills the global hash %filesys with details of all filesystem some user has
quotas on, and returns a count of the number of filesystems. Some example code
best demonstrates how this function should be used:

 foreign_require('quota', 'quota-lib.pl');
 $n = quota::user_filesystems('joe');
 for($i=0; $i<$n; $i++) {
   print "filesystem=",$filesys{$i,'filesys'}," ",
         "block quota=",$filesys{$i,'hblocks'}," ",
         "blocks used=",$filesys{$i,'ublocks'},"\n";
 }

=cut
sub user_filesystems
{
return &parse_quota_output("$config{'user_quota_command'} ".quotemeta($_[0]));
}

=head2 group_filesystems(user)

Fills the array %filesys with details of all filesystem some group has
quotas on, and returns the filesystem count. The format of %filesys is the same
as documented in the user_filesystems function.

=cut
sub group_filesystems
{
return &parse_quota_output("$config{'group_quota_command'} ".quotemeta($_[0]));
}

=head2 parse_quota_output(command)

Internal function to parse the output of the quota command.

=cut
sub parse_quota_output
{
local($n, $_, %mtab);
%mtab = &get_mtab_map();
open(QUOTA, "$_[0] 2>/dev/null |");
$n=0; while(<QUOTA>) {
	chop;
	if (/^(Disk|\s+Filesystem)/) { next; }
	if (/^(\S+)$/) {
		# Bogus wrapped line
		my $dev = $1;
		$filesys{$n,'filesys'} = $mtab{&resolve_and_simplify($dev)};
		local $nl = <QUOTA>;
		$nl =~/^\s+(\S+)\s+(\S+)\s+(\S+)(.{8}\s+)(\S+)\s+(\S+)\s+(\S+)(.*)/ ||
		      $nl =~ /^.{15}.(.{7}).(.{7}).(.{7})(.{8}.)(.{7}).(.{7}).(.{7})(.*)/;
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
	elsif (/^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)(.{8}\s+)(\S+)\s+(\S+)\s+(\S+)(.*)/ ||
	       /^(.{15}).(.{7}).(.{7}).(.{7})(.{8}.)(.{7}).(.{7}).(.{7})(.*)/) {
		# Single quota line
		$filesys{$n,'ublocks'} = int($2);
		$filesys{$n,'sblocks'} = int($3);
		$filesys{$n,'hblocks'} = int($4);
		$filesys{$n,'gblocks'} = $5;
		$filesys{$n,'ufiles'} = int($6);
		$filesys{$n,'sfiles'} = int($7);
		$filesys{$n,'hfiles'} = int($8);
		$filesys{$n,'gfiles'} = $9;
		my $dev = $1; $dev =~ s/\s+$//g; $dev =~ s/^\s+//g;
		$filesys{$n,'filesys'} = $mtab{&resolve_and_simplify($dev)};
		$filesys{$n,'gblocks'} = &trunc_space($filesys{$n,'gblocks'});
		$filesys{$n,'gfiles'} = &trunc_space($filesys{$n,'gfiles'});
		$n++;
		}
	}
close(QUOTA);
return $n;
}

=head2 filesystem_users(filesystem)

Fills the array %user with information about all users with quotas
on this filesystem, and returns the number of users. Some example code shows
how this can be used :

 foreign_require('quota', 'quota-lib.pl');
 $n = quota::filesystem_users('/home');
 for($i=0; $i<$n; $i++) {
   print "user=",$user{$i,'user'}," ",
	 "block quota=",$user{$i,'hblocks'}," ",
	 "blocks used=",$user{$i,'ublocks'},"\n";
 }

=cut
sub filesystem_users
{
return &parse_repquota_output(
	$config{'user_repquota_command'}, \%user, "user", $_[0]);
}

=head2 filesystem_groups(filesystem)

Fills the array %group with information about all groups  with quotas on some
filesystem, and returns the group count. The format of %group is the same as
documented in the filesystem_users function.

=cut
sub filesystem_groups
{
return &parse_repquota_output(
	$config{'group_repquota_command'}, \%group, "group", $_[0]);
}

=head2 parse_repquota_output(command, hashname, dir)

Internal function to parse the output of the repquota command.

=cut
sub parse_repquota_output
{
local ($cmd, $what, $mode, $dir) = @_;
local($rep, @rep, $n, $u, @uinfo);
%$what = ( );
$rep = &backquote_command("$cmd $dir 2>&1");
if ($?) { return -1; }
local $st = &supports_status($dir, $mode);
if (!$st) {
	# Older system, need to build username map to identify truncation
	if ($mode eq 'user') {
		setpwent();
		while(@uinfo = getpwent()) {
			$hasu{$uinfo[0]}++;
			}
		endpwent();
		}
	else {
		setgrent();
		while(@uinfo = getgrent()) {
			$hasu{$uinfo[0]}++;
			}
		endgrent();
		}
	}
@rep = split(/\n/, $rep); @rep = @rep[3..$#rep];
local $nn = 0;
local %already;
for($n=0; $n<@rep; $n++) {
	if ($rep[$n] =~ /^\s*(\S.*\S|\S)\s+[\-\+]{2}\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)(.*)/ ||
	    $rep[$n] =~ /^\s*(\S.*\S|\S)\s+[\-\+]{2}\s+(\S+)\s+(\S+)\s+(\S+)(.{7})\s+(\S+)\s+(\S+)\s+(\S+)(.*)/ ||
	    $rep[$n] =~ /([^\-\s]\S*)\s*[\-\+]{2}(.{8})(.{8})(.{8})(.{7})(.{8})(.{6})(.{6})(.*)/) {
		$what->{$nn,$mode} = $1;
		$what->{$nn,'ublocks'} = int($2);
		$what->{$nn,'sblocks'} = int($3);
		$what->{$nn,'hblocks'} = int($4);
		$what->{$nn,'gblocks'} = $5;
		$what->{$nn,'ufiles'} = int($6);
		$what->{$nn,'sfiles'} = int($7);
		$what->{$nn,'hfiles'} = int($8);
		$what->{$nn,'gfiles'} = $9;
		if (!$st && $what->{$nn,$mode} !~ /^\d+$/ &&
			    !$hasu{$what->{$nn,$mode}}) {
			# User/group name was truncated! Try to find him..
			foreach $u (keys %hasu) {
				if (substr($u, 0, length($what->{$nn,$mode})) eq
				    $what->{$nn,$what}) {
					# found him..
					$what->{$nn,$mode} = $u;
					last;
					}
				}
			}
		next if ($already{$what->{$nn,$mode}}++); # skip dupe users
		$what->{$nn,'gblocks'} = &trunc_space($what->{$nn,'gblocks'});
		$what->{$nn,'gfiles'} = &trunc_space($what->{$nn,'gfiles'});
		$nn++;
		}
	}
return $nn;
}

=head2 edit_quota_file(data, filesys, sblocks, hblocks, sfiles, hfiles)

Internal function that is called indirectly by the 'edquota' command to
modify a user's quotas on one filesystem, by editing a file.

=cut
sub edit_quota_file
{
local($rv, $line, %mtab, @m, @line);
%mtab = &get_mtab_map();
@line = split(/\n/, $_[0]);
for(my $i=0; $i<@line; $i++) {
	if ($line[$i] =~ /^(\S+): blocks in use: (\d+), limits \(soft = (\d+), hard = (\d+)\)$/ && $mtab{&resolve_and_simplify("$1")} eq $_[1]) {
		# Found old-style lines to change
		$rv .= "$1: blocks in use: $2, limits (soft = $_[2], hard = $_[3])\n";
		$line[++$i] =~ /^\s*inodes in use: (\d+), limits \(soft = (\d+), hard = (\d+)\)$/;
		$rv .= "\tinodes in use: $1, limits (soft = $_[4], hard = $_[5])\n";
		}
	elsif ($line[$i] =~ /^device\s+(\S+)\s+\((\S+)\):/i && $2 eq $_[1]) {
		# Even newer-style line to change
		$rv .= "$line[$i]\n";
		$line[++$i] =~ /^used\s+(\S+),\s+limits:\s+soft=(\d+)\s+hard=(\d+)/i;
		$rv .= "Used $1, limits: soft=$_[2] hard=$_[3]\n";
		$line[++$i] =~ /^used\s+(\S+) inodes,\s+limits:\s+soft=(\d+)\s+hard=(\d+)/i;
		$rv .= "Used $1 inodes, limits: soft=$_[4] hard=$_[5]\n";
		}
	elsif ($line[$i] =~ /^\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/ && $mtab{&resolve_and_simplify("$1")} eq $_[1]) {
		# New-style line to change
		$rv .= "  $1 $2 $_[2] $_[3] $5 $_[4] $_[5]\n";
		}
	else {
		# Leave this line alone
		$rv .= "$line[$i]\n";
		}
	}
return $rv;
}

=head2 quotacheck(filesystem, mode)

Runs quotacheck on some filesystem, and returns the output in case of error,
or undef on failure. The mode must be one of :

=item 0 - Users and groups.

=item 1 - Users only.

=item 2 - Groups only.

=cut
sub quotacheck
{
local $out;
if ($_[1] == 0 || $_[1] == 1) {
	&unlink_file("$_[0]/aquota.user.new");
	}
if ($_[1] == 0 || $_[1] == 2) {
	&unlink_file("$_[0]/aquota.group.new");
	}
local $cmd = $config{'quotacheck_command'};
$cmd =~ s/\s+-[ug]//g;
local $flag = $_[1] == 1 ? "-u" : $_[1] == 2 ? "-g" : "-u -g";
$out = &backquote_logged("$cmd $flag $_[0] 2>&1");
if ($?) {
	# Try with the -f and -m options
	$out = &backquote_logged("$cmd $flag -f -m $_[0] 2>&1");
	if ($?) {
		# Try with the -F option
		$out = &backquote_logged("$config{'quotacheck_command'} $flag -F $_[0] 2>&1");
		}
	return $out if ($?);
	}
return undef;
}

=head2 copy_user_quota(user, [user]+)

Copy the quotas for some user (the first parameter) to many others (named by
the remaining parameters). Returns undef on success, or an error message on
failure.

=cut
sub copy_user_quota
{
for($i=1; $i<@_; $i++) {
	$out = &backquote_logged("$config{'user_copy_command'} ".
				quotemeta($_[0])." ".quotemeta($_[$i])." 2>&1");
	if ($?) { return $out; }
	}
return undef;
}

=head2 copy_group_quota(group, [group]+)

Copy the quotas for some group (the first parameter) to many others (named by
the remaining parameters). Returns undef on success, or an error message on
failure.

=cut
sub copy_group_quota
{
for($i=1; $i<@_; $i++) {
	$out = &backquote_logged("$config{'group_copy_command'} ".
				quotemeta($_[0])." ".quotemeta($_[$i])." 2>&1");
	if ($?) { return $out; }
	}
return undef;
}

=head2 get_user_grace(filesystem)

Returns an array containing information about grace times on some filesystem,
which is the amount of time a user can exceed his soft quota before it becomes
hard. The elements of the array are :

=item Grace time for block quota, in units below.

=item Units for block quota grace time, where 0=sec, 1=min, 2=hour, 3=day.

=item Grace time for files quota, in units below.

=item Units for files quota grace time, where 0=sec, 1=min, 2=hour, 3=day.

=cut
sub get_user_grace
{
return &parse_grace_output($config{'user_grace_command'}, $_[0]);
}

=head2 get_group_grace(filesystem)

Returns an array containing information about grace times on some filesystem,
which is the amount of time a group can exceed its soft quota before it becomes
hard. The elements of the array are :

=item Grace time for block quota, in units below.

=item Units for block quota grace time, where 0=sec, 1=min, 2=hour, 3=day.

=item Grace time for files quota, in units below.

=item Units for files quota grace time, where 0=sec, 1=min, 2=hour, 3=day.

=cut
sub get_group_grace
{
return &parse_grace_output($config{'group_grace_command'}, $_[0]);
}

=head2 default_grace

Returns 0 if grace time can be 0, 1 if zero grace means default.

=cut
sub default_grace
{
return 0;
}

=head2 parse_grace_output(command)

Internal function to parse output from the quota -t command.

=cut
sub parse_grace_output
{
local(@rv, %mtab, @m);
%mtab = &get_mtab_map();
$ENV{'EDITOR'} = $ENV{'VISUAL'} = "cat";
open(GRACE, "$_[0] 2>&1 |");
while(<GRACE>) {
	if (/^(\S+): block grace period: (\d+) (\S+), file grace period: (\d+) (\S+)/ && $mtab{&resolve_and_simplify("$1")} eq $_[1]) {
		@rv = ($2, $name_to_unit{$3}, $4, $name_to_unit{$5});
		}
	elsif (/^\s+(\S+)\s+(\d+)(\S+)\s+(\d+)(\S+)/ && $mtab{&resolve_and_simplify("$1")} eq $_[1]) {
		@rv = ($2, $name_to_unit{$3}, $4, $name_to_unit{$5});
		}
	elsif (/^device\s+(\S+)\s+\((\S+)\):/i && $2 eq $_[1]) {
		if (<GRACE> =~ /^block\s+grace:\s+(\S+)\s+(\S+)\s+inode\s+grace:\s+(\S+)\s+(\S+)/i) {
			@rv = ($1, $name_to_unit{$2}, $3, $name_to_unit{$4});
			last;
			}
		}
	}
close(GRACE);
return @rv;
}

=head2 edit_grace_file(data, filesystem, btime, bunits, ftime, funits)

Internal function called by edquota -t to set grace times on some filesystem,
by editing a file.

=cut
sub edit_grace_file
{
local($rv, $line, @m, %mtab, @line);
%mtab = &get_mtab_map();
@line = split(/\n/, $_[0]);
for(my $i=0; $i<@line; $i++) {
	$line = $line[$i];
	if ($line =~ /^(\S+): block grace period: (\d+) (\S+), file grace period: (\d+) (\S+)/ && $mtab{&resolve_and_simplify("$1")} eq $_[1]) {
		# replace this line
		$line = "$1: block grace period: $_[2] $unit_to_name{$_[3]}, file grace period: $_[4] $unit_to_name{$_[5]}";
		}
	elsif ($line =~ /^\s+(\S+)\s+(\d+)(\S+)\s+(\d+)(\S+)/ && $mtab{&resolve_and_simplify("$1")} eq $_[1]) {
		# replace new-style line
		$line = "  $1 $_[2]$unit_to_name{$_[3]} $_[4]$unit_to_name{$_[5]}";
		}
	elsif ($line =~ /^device\s+(\S+)\s+\((\S+)\):/i && $2 eq $_[1]) {
		# replace even newer-style line
		$rv .= "$line\n";
		$line = "Block grace: $_[2] $unit_to_name{$_[3]} Inode grace: $_[4] $unit_to_name{$_[5]}";
		$i++;
		}
	$rv .= "$line\n";
	}
return $rv;
}

=head2 grace_units

Returns an array of possible units for grace periods, in human-readable format.

=cut
sub grace_units
{
return ($text{'grace_seconds'}, $text{'grace_minutes'}, $text{'grace_hours'},
	$text{'grace_days'});
}

=head2 fs_block_size(dir, device, filesystem)

Returns the size of quota blocks on some filesystem, or undef if unknown.
Consult the dumpe2fs command where possible.

=cut
sub fs_block_size
{
if ($_[2] =~ /^ext\d+$/) {
	return 1024;
	# This code isn't needed, because the quota block size is
	# not the same as the filesystem block size!!
	#if (&has_command("dumpe2fs")) {
	#	local $out = `dumpe2fs -h $_[1] 2>&1`;
	#	if (!$? && $out =~ /block size:\s+(\d+)/i) {
	#		return $1;
	#		}
	#	}
	}
elsif ($_[2] eq "xfs") {
	return 1024;
	}
return undef;
}

%name_to_unit = ( "second", 0, "seconds", 0,
		  "minute", 1, "minutes", 1,
		  "hour", 2, "hours", 2,
		  "day", 3, "days", 3,
		);
foreach $k (keys %name_to_unit) {
	$unit_to_name{$name_to_unit{$k}} = $k;
	}

=head2 get_mtab_map

Returns a hash mapping devices to mount points. For internal use.

=cut
sub get_mtab_map
{
local $mm = $module_info{'usermin'} ? "usermount" : "mount";
&foreign_require($mm, "$mm-lib.pl");
local ($m, %mtab);
foreach $m (&foreign_call($mm, "list_mounted", 1)) {
	if ($m->[3] =~ /loop=([^,]+)/) {
		$mtab{&resolve_and_simplify("$1")} ||= $m->[0];
		}
	else {
		$mtab{&resolve_and_simplify($m->[1])} ||= $m->[0];
		}
	}
$mtab{"/dev/root"} = "/";
return %mtab;
}

1;

