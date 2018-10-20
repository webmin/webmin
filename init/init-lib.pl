=head1 init-lib.pl

Common functions for SYSV-style boot/shutdown sequences, MacOS, FreeBSD
and Windows. Because each system uses a different format and semantics for
bootup actions, there are separate functions for listing and managing each
type. However, some functions like enable_at_boot and disable_at_boot can 
creation actions regardless of the underlying boot system.

Example code :

 foreign_require('init', 'init-lib.pl');
 $ok = init::action_status('foo');
 if ($ok == 0) {
   init::enable_at_boot('foo', 'Start or stop the Foo server',
                        '/etc/foo/start', '/etc/foo/stop');
 }

=cut

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
@action_buttons = ( 'start', 'restart', 'condrestart', 'reload', 'status',
		    'stop' );
%access = &get_module_acl();

=head2 init_mode

This variable is set based on the bootup system in use. Possible values are :

=item osx - MacOSX hostconfig files, for older versions

=item launchd - MacOS Launchd, for newer versions

=item rc - FreeBSD 6+ RC files

=item init - System V init.d files, seen on Linux and Solaris

=item local - A single rc.local file

=item win32 - Windows services

=item upstart - Upstart, seen on Ubuntu 11

=item systemd - SystemD, seen on Fedora 16

=cut
if ($config{'init_mode'}) {
	$init_mode = $config{'init_mode'};
	}
elsif (&has_command("launchd")) {
	$init_mode = "launchd";
	}
elsif ($config{'hostconfig'}) {
	$init_mode = "osx";
	}
elsif ($config{'rc_dir'}) {
	$init_mode = "rc";
	}
elsif ($config{'init_base'} && -d "/etc/init" &&
       &has_command("initctl") &&
       &execute_command("/sbin/init --version") == 0) {
	$init_mode = "upstart";
	}
elsif (-d "/etc/systemd" && &has_command("systemctl") &&
       &execute_command("systemctl list-units") == 0) {
	$init_mode = "systemd";
	}
elsif ($config{'init_base'}) {
	$init_mode = "init";
	}
elsif ($config{'local_script'}) {
	$init_mode = "local";
	}
elsif ($gconfig{'os_type'} eq 'windows') {
	$init_mode = "win32";
	}

=head2 runlevel_actions(level, S|K)

Return a list of init.d actions started or stopped in some run-level, each of
which is a space-separated string in the format : number name inode

=cut
sub runlevel_actions
{
local($dir, $f, @stbuf, @rv);
$dir = &runlevel_dir($_[0]);
opendir(DIR, $dir);
foreach $f (readdir(DIR)) {
	if ($f !~ /^([A-Z])(\d+)(.*)$/ || $1 ne $_[1]) { next; }
	if (!(@stbuf = stat("$dir/$f"))) { next; }
	push(@rv, "$2 $3 $stbuf[1]");
	}
closedir(DIR);
@rv = sort { @a = split(/\s/,$a); @b = split(/\s/,$b); $a[0] <=> $b[0]; } @rv;
return $_[1] eq "S" ? @rv : reverse(@rv);
}


=head2 list_runlevels

Returns a list of known runlevels, such as : 2 3 5.

=cut
sub list_runlevels
{
local(@rv);
opendir(DIR, $config{init_base});
foreach (readdir(DIR)) {
	if (/^rc([A-z0-9])\.d$/ || /^(boot)\.d$/) {
		#if (!$config{show_opts} && $1 < 1) { next; }
		push(@rv, $1);
		}
	}
closedir(DIR);
return sort(@rv);
}


=head2 list_actions

List boot time action names from init.d, such as httpd and cron.

=cut
sub list_actions
{
local($dir, $f, @stbuf, @rv);
$dir = $config{init_dir};
opendir(DIR, $dir);
foreach $f (sort { lc($a) cmp lc($b) } readdir(DIR)) {
	if ($f eq "." || $f eq ".." || $f =~ /\.bak$/ || $f eq "functions" ||
	    $f eq "core" || $f eq "README" || $f eq "rc" || $f eq "rcS" ||
	    -d "$dir/$f" || $f =~ /\.swp$/ || $f eq "skeleton" ||
	    $f =~ /\.lock$/ || $f =~ /\.dpkg-(old|dist)$/ ||
	    $f =~ /^\.depend\./ || $f eq '.legacy-bootordering' ||
	    $f =~ /^mandrake/) { next; }
	if (@stbuf = stat("$dir/$f")) {
		push(@rv, "$f $stbuf[1]");
		}
	}
closedir(DIR);
foreach $f (split(/\s+/, $config{'extra_init'})) {
	if (@stbuf = stat($f)) {
		push(@rv, "$f $stbuf[1]");
		}
	}
return @rv;
}


=head2 action_levels(S|K, action)

Return a list of run levels in which some action (from init.d) is started
or stopped. Each item is a space-separated string in the format : level order name

=cut
sub action_levels
{
local(@stbuf, $rl, $dir, $f, @stbuf2, @rv);
@stbuf = stat(&action_filename($_[1]));
foreach $rl (&list_runlevels()) {
	$dir = &runlevel_dir($rl);
	opendir(DIR, $dir);
	foreach $f (readdir(DIR)) {
		if ($f =~ /^([A-Z])(\d+)(.*)$/ && $1 eq $_[0]) {
			@stbuf2 = stat("$dir/$f");
			if ($stbuf[1] == $stbuf2[1]) {
				push(@rv, "$rl $2 $3");
				last;
				}
			}
		}
	closedir(DIR);
	}
return @rv;
}


=head2 action_filename(name)

Returns the path to the file in init.d for some action, such as /etc/init.d/foo.

=cut
sub action_filename
{
return $_[0] =~ /^\// ? $_[0] : "$config{init_dir}/$_[0]";
}

=head2 runlevel_filename(level, S|K, order, name)

Returns the path to the actual script run at boot for some action, such as
/etc/rc3.d/S99foo.

=cut
sub runlevel_filename
{
local $n = $_[3];
$n =~ s/^(.*)\///;
return &runlevel_dir($_[0])."/$_[1]$_[2]$n";
}


=head2 add_rl_action(action, runlevel, S|K, order)

Add some existing action to a runlevel. The parameters are :

=item action - Name of the action, like foo

=item runlevel - A runlevel number, like 3

=item S|K - Either S for an action to run at boot, or K for shutdown

=item order - Numeric boot order, like 99

=cut
sub add_rl_action
{
$file = &runlevel_filename($_[1], $_[2], $_[3], $_[0]);
while(-r $file) {
	if ($file =~ /^(.*)_(\d+)$/) { $file = "$1_".($2+1); }
	else { $file = $file."_1"; }
	}
&lock_file($file);
if ($config{soft_links}) {
	&symlink_file(&action_filename($_[0]), $file);
	}
else {
	&link_file(&action_filename($_[0]), $file);
	}
&unlock_file($file);
}


=head2 delete_rl_action(name, runlevel, S|K)

Delete some action from a runlevel. The parameters are :

=item action - Name of the action, like foo.

=item runlevel - A runlevel number, like 3.

=item S|K - Either S for an action to run at boot, or K for shutdown.

=cut
sub delete_rl_action
{
local(@stbuf, $dir, $f, @stbuf2);
@stbuf = stat(&action_filename($_[0]));
$dir = &runlevel_dir($_[1]);
opendir(DIR, $dir);
foreach $f (readdir(DIR)) {
	if ($f =~ /^([A-Z])(\d+)(.+)$/ && $1 eq $_[2]) {
		@stbuf2 = stat("$dir/$f");
		if ($stbuf[1] == $stbuf2[1]) {
			# found file to delete.. unlink
			&unlink_logged("$dir/$f");
			last;
			}
		}
	}
closedir(DIR);
}


=head2 reorder_rl_action(name, runlevel, S|K, new_order)

Change the boot order of some existing runlevel action. The parameters are :

=item action - Name of the action, like foo.

=item runlevel - A runlevel number, like 3.

=item S|K - Either S for an action to run at boot, or K for shutdown.

=item new_order - New numeric boot order to use, like 99.

=cut
sub reorder_rl_action
{
local(@stbuf, $dir, $f, @stbuf2);
@stbuf = stat(&action_filename($_[0]));
$dir = &runlevel_dir($_[1]);
opendir(DIR, $dir);
foreach $f (readdir(DIR)) {
	if ($f =~ /^([A-Z])(\d+)(.+)$/ && $1 eq $_[2]) {
		@stbuf2 = stat("$dir/$f");
		if ($stbuf[1] == $stbuf2[1]) {
			# Found file that needs renaming
			$file = &runlevel_dir($_[1])."/$1$_[3]$3";
			while(-r $file) {
				if ($file =~ /^(.*)_(\d+)$/)
					{ $file = "$1_".($2+1); }
				else { $file = $file."_1"; }
				}
			&rename_logged("$dir/$f", $file);
			last;
			}
		}
	}
closedir(DIR);
}


=head2 rename_action(old, new)

Change the name of an action in init.d, and re-direct all soft links
to it from the runlevel directories. Parameters are :

=item old - Old action name.

=item new - New action name.

=cut
sub rename_action
{
local($file, $idx, $old);
foreach (&action_levels('S', $_[0])) {
	/^(\S+)\s+(\S+)\s+(\S+)$/;
	$file = &runlevel_dir($1)."/S$2$3";
	if (readlink($file)) {
		# File is a symbolic link.. change it
		&lock_file($file);
		&unlink_file($file);
		&symlink_file("$config{init_dir}/$_[1]", $file);
		&unlock_file($file);
		}
	if (($idx = index($file, $_[0])) != -1) {
		$old = $file;
		substr($file, $idx, length($_[0])) = $_[1];
		&rename_logged($old, $file);
		}
	}
foreach (&action_levels('K', $_[0])) {
	/^(\S+)\s+(\S+)\s+(\S+)$/;
	$file = &runlevel_dir($1)."/K$2$3";
	if (readlink($file)) {
		# File is a symbolic link.. change it
		&lock_file($file);
		&unlink_file($file);
		&symlink_file("$config{init_dir}/$_[1]", $file);
		&unlock_file($file);
		}
	if (($idx = index($file, $_[0])) != -1) {
		$old = $file;
		substr($file, $idx, length($_[0])) = $_[1];
		&rename_logged($old, $file);
		}
	}
&rename_logged("$config{init_dir}/$_[0]", "$config{init_dir}/$_[1]");
}


=head2 rename_rl_action(runlevel, S|K, order, old, new)

Change the name of a runlevel file. For internal use only.

=cut
sub rename_rl_action
{
&rename_logged(&runlevel_dir($_[0])."/$_[1]$_[2]$_[3]",
               &runlevel_dir($_[0])."/$_[1]$_[2]$_[4]");
}

=head2 get_inittab_runlevel

Returns the runlevels entered at boot time. If more than one is returned,
actions from all of them are used.

=cut
sub get_inittab_runlevel
{
local %iconfig = &foreign_config("inittab");
local @rv;
local $id = $config{'inittab_id'};
if (open(TAB, $iconfig{'inittab_file'})) {
	# Read the inittab file
	while(<TAB>) {
		if (/^$id:(\d+):/ && $1) { @rv = ( $1 ); }
		}
	close(TAB);
	}

if (&has_command("runlevel")) {
	# Use runlevel command to get current level
	local $out = &backquote_command("runlevel");
	if ($out =~ /^(\S+)\s+(\S+)/) {
		push(@rv, $2);
		}
	}
elsif (&has_command("who")) {
	# Use who -r command to get runlevel
	local $out = &backquote_command("who -r 2>/dev/null");
	if (!$? && $out =~ /run-level\s+(\d+)/) {
		push(@rv, $1);
		}
	}

# Last ditch fallback - assume runlevel 3
if (!@rv && !$config{'inittab_extra'}) {
	push(@rv, 3);
	}

# Add statically configured runlevels
if (@rv && $config{"inittab_rl_$rv[0]"}) {
	@rv = split(/,/, $config{"inittab_rl_$rv[0]"});
	}
push(@rv, $config{'inittab_extra'});
return &unique(@rv);
}

=head2 init_description(file, [&hasargs])

Given a full path to an init.d file, returns a description from the comments
about what it does. If the hasargs hash ref parameter is given, it is filled
in with supported parameters to the action, like 'start' and 'stop'.

=cut
sub init_description
{
# Read contents of script, extract start/stop commands
open(FILE, $_[0]);
local @lines = <FILE>;
close(FILE);
local $data = join("", @lines);
if ($_[1]) {
	foreach (@lines) {
		if (/^\s*(['"]?)([a-z]+)\1\)/i) {
			$_[1]->{$2}++;
			}
		}
	}

local $desc;
if ($config{'daemons_dir'}) {
	# First try the daemons file
	local %daemon;
	if ($_[0] =~ /\/([^\/]+)$/ &&
	    &read_env_file("$config{'daemons_dir'}/$1", \%daemon) &&
	    $daemon{'DESCRIPTIVE'}) {
		return $daemon{'DESCRIPTIVE'};
		}
	}
if ($config{'chkconfig'}) {
	# Find the redhat-style description: section
	foreach (@lines) {
		s/\r|\n//g;
		if (/^#+\s*description:(.*?)(\\?$)/) {
			$desc = $1;
			}
		elsif (/^#+\s*(.*?)(\\?$)/ && $desc && $1) {
			$desc .= "\n".$1;
			}
		if ($desc && !$2) {
			last;
			}
		}
	}
elsif ($config{'init_info'} || $data =~ /BEGIN INIT INFO/) {
	# Find the suse-style Description: line
	foreach (@lines) {
		s/\r|\n//g;
		if (/^#\s*(Description|Short-Description):\s*(.*)/) {
			$desc = $2;
			}
		}
	}
else {
	# Use the first comments
	foreach (@lines) {
		s/\r|\n//g;
		next if (/^#!\s*\/(bin|sbin|usr)\// || /\$id/i || /^#+\s+@/ ||
			 /source function library/i || /^#+\s*copyright/i);
		if (/^#+\s*(.*)/) {
			last if ($desc && !$1);
			$desc .= $1."\n" if ($1);
			}
		elsif (/\S/) { last; }
		}
	$_[0] =~ /\/([^\/]+)$/;
	$desc =~ s/^Tag\s+(\S+)\s*//i;
	$desc =~ s/^\s*$1\s+//;
	}
return $desc;
}

=head2 chkconfig_info(file)

If a file has a chkconfig: section specifying the runlevels to start in and
the orders to use, return an array containing the levels (as array ref),
start order, stop order and description.

=cut
sub chkconfig_info
{
local @rv;
local $desc;
open(FILE, $_[0]);
while(<FILE>) {
	if (/^#\s*chkconfig:\s+(\S+)\s+(\d+)\s+(\d+)/) {
		@rv = ( $1 eq '-' ? [ ] : [ split(//, $1) ], $2, $3 );
		}
	elsif (/^#\s*description:\s*(.*)/) {
		$desc = $1;
		}
	}
close(FILE);
$rv[3] = $desc if ($desc && @rv);
return @rv;
}

=head2 action_status(action)

Returns 0 if some action doesn't exist, 1 if it does but is not enabled,
or 2 if it exists and is enabled. This works for all supported boot systems,
such as init.d, OSX and FreeBSD.

=cut
sub action_status
{
my ($name) = @_;
if ($init_mode eq "upstart") {
	# Check upstart service status
	local $out = &backquote_command("initctl status ".
					quotemeta($name)." 2>&1");
	if (!$?) {
		my $cfile = "/etc/init/$name.conf";
		open(CONF, $cfile);
		while(<CONF>) {
			if (/^(#*)\s*start/) {
				return $1 ? 1 : 2;
				}
			}
		close(CONF);
		return 1;	# Should never happen
		}
	}
elsif ($init_mode eq "systemd") {
	# Check systemd service status
	local $unit = $name;
	$unit .= ".service" if ($unit !~ /\.service$/);
	local $out = &backquote_command("systemctl show ".
					quotemeta($unit)." 2>&1");
	if ($out =~ /UnitFileState=(\S+)/ &&
	    $out !~ /Description=LSB:\s/) {
		# Exists .. but is it started at boot?
		return lc($1) eq 'enabled' || lc($1) eq 'static' ? 2 : 1;
		}
	}
if ($init_mode eq "init" || $init_mode eq "upstart" ||
    $init_mode eq "systemd") {
	# Look for init script
	local ($a, $exists, $starting, %daemon);
	foreach $a (&list_actions()) {
		local @a = split(/\s+/, $a);
		if ($a[0] eq $name) {
			$exists++;
			local @boot = &get_inittab_runlevel();
			foreach $s (&action_levels("S", $a[0])) {
				local ($l, $p) = split(/\s+/, $s);
				$starting++ if (&indexof($l, @boot) >= 0);
				}
			}
		}
	if ($starting && $config{'daemons_dir'} &&
	    &read_env_file("$config{'daemons_dir'}/$name", \%daemon)) {
		$starting = lc($daemon{'ONBOOT'}) eq 'yes' ? 1 : 0;
		}
	return !$exists ? 0 : $starting ? 2 : 1;
	}
elsif ($init_mode eq "local") {
	# Look for entry in rc.local
	local $fn = "$module_config_directory/$name.sh";
	local $cmd = "$fn start";
	open(LOCAL, $config{'local_script'});
	while(<LOCAL>) {
		s/\r|\n//g;
		$found++ if ($_ eq $cmd);
		}
	close(LOCAL);
	return $found && -r $fn ? 2 : -r $fn ? 1 : 0;
	}
elsif ($init_mode eq "win32") {
	# Look for a win32 service, enabled at boot
	local ($svc) = &list_win32_services($name);
	return !$svc ? 0 :
	       $svc->{'boot'} == 2 ? 2 : 1;
	}
elsif ($init_mode eq "rc") {
	# Look for an RC script
	local @rcs = &list_rc_scripts();
	local ($rc) = grep { $_->{'name'} eq $name } @rcs;
	return !$rc ? 0 :
	       $rc->{'enabled'} ? 2 : 1;
	}
elsif ($init_mode eq "osx") {
	# Look for a hostconfig entry
	local $ucname = uc($name);
	local %hc;
	&read_env_file($config{'hostconfig'}, \%hc);
	return $hc{$ucname} eq '-YES-' ? 2 :
	       $hc{$ucname} eq '-NO-' ? 1 : 0;
	}
elsif ($init_mode eq "launchd") {
	local @agents = &list_launchd_agents();
	local ($agent) = grep { $_->{'name'} eq &launchd_name($name) } @agents;
	return !$agent ? 0 :
	       $agent->{'boot'} ? 2 : 1;
	}
}

=head2 enable_at_boot(action, description, startcode, stopcode, statuscode, &opts)

Makes some action start at boot time, creating the script by copying the
specified file if necessary. The parameters are :

=item action - Name of the action to create or enable.

=item description - A human-readable description for the action.

=item startcode - Shell commands to run at boot time.

=item stopcode - Shell commands to run at shutdown time.

=item statuscode - Shell code to output the action's status.

=item opts - Hash ref of additional options, like : fork -> server will fork into background

If this is called for a named action that already exists (even if it isn't
enabled), only the first parameter needs to be given.

=cut
sub enable_at_boot
{
local $st = &action_status($_[0]);
return if ($st == 2);	# already exists and is enabled
local ($daemon, %daemon);
local $unit = $_[0];
$unit .= ".service" if ($unit !~ /\.service$/);

if ($init_mode eq "upstart" && (!-r "$config{'init_dir'}/$_[0]" ||
				-r "/etc/init/$_[0].conf")) {
	# Create upstart action if missing, as long as this isn't an old-style
	# init script
	my $cfile = "/etc/init/$_[0].conf";
	if (-r $cfile) {
		# Config file exists, make sure it is enabled
		if (&has_command("insserv")) {
			&system_logged(
				"insserv ".quotemeta($_[0])." >/dev/null 2>&1");
			}
		my $lref = &read_file_lines($cfile);
		my $foundstart;
		foreach my $l (@$lref) {
			if ($l =~ /^#+start/) {
				# Start of start block
				$l =~ s/^#+//;
				$foundstart = 1;
				}
			elsif ($l =~ /^#+\s+\S/ && $foundstart) {
				# Continuation line for start
				$l =~ s/^#+//;
				}
			elsif ($l =~ /^\S/ && $foundstart) {
				# Some other directive after start
				last;
				}
			}
		&flush_file_lines($cfile);
		}
	else {
		# Need to create config
		$_[2] || &error("Upstart service $_[0] cannot be created ".
				"unless a command is given");
		&create_upstart_service($_[0], $_[1], $_[2], undef,
					$_[5]->{'fork'});
		if (&has_command("insserv")) {
			&system_logged(
				"insserv ".quotemeta($_[0])." >/dev/null 2>&1");
			}
		}
	return;
	}
if ($init_mode eq "systemd" && (!-r "$config{'init_dir'}/$_[0]" ||
				&is_systemd_service($unit))) {
	# Create systemd unit if missing, as long as this isn't an old-style
	# init script
	my $cfile = &get_systemd_root($_[0])."/".$unit;
	if (!-r $cfile) {
		# Need to create config
		$_[2] || &error("Systemd service $_[0] cannot be created ".
				"unless a command is given");
		&create_systemd_service($unit, $_[1], $_[2], $_[3], undef,
					$_[5]->{'fork'}, $_[5]->{'pidfile'},
					$_[5]->{'exit'});
		}
	&system_logged("systemctl unmask ".
		       quotemeta($unit)." >/dev/null 2>&1");
	&system_logged("systemctl enable ".
		       quotemeta($unit)." >/dev/null 2>&1");
	return;
	}
if ($init_mode eq "init" || $init_mode eq "local" || $init_mode eq "upstart" ||
    $init_mode eq "systemd") {
	# In these modes, we create a script to run
	if ($config{'daemons_dir'} &&
	    &read_env_file("$config{'daemons_dir'}/$_[0]", \%daemon)) {
		$daemon++;
		}
	local $fn;
	if ($init_mode eq "init" || $init_mode eq "upstart" ||
            $init_mode eq "systemd") {
		# Normal init.d system
		$fn = &action_filename($_[0]);
		}
	else {
		# Need to create hack init script
		$fn = "$module_config_directory/$_[0].sh";
		}
	local @chk = &chkconfig_info($fn);
	local @start = @{$chk[0]} ? @{$chk[0]} : &get_start_runlevels();
	local $start_order = $chk[1] || "9" x $config{'order_digits'};
	local $stop_order = $chk[2] || "9" x $config{'order_digits'};
	local @stop;
	if (@chk) {
		local %starting = map { $_, 1 } @start;
		@stop = grep { !$starting{$_} && /^\d+$/ } &list_runlevels();
		}

	local $need_links = 0;
	if ($st == 1 && $daemon) {
		# Just update daemons file
		$daemon{'ONBOOT'} = 'yes';
		&lock_file("$config{'daemons_dir'}/$_[0]");
		&write_env_file("$config{'daemons_dir'}/$_[0]", \%daemon);
		&unlock_file("$config{'daemons_dir'}/$_[0]");
		}
	elsif ($st == 1) {
		# Just need to create links (later)
		$need_links++;
		}
	elsif ($_[1]) {
		# Need to create the init script
		&lock_file($fn);
		&open_tempfile(ACTION, ">$fn");
		&print_tempfile(ACTION, "#!/bin/sh\n");
		if ($config{'chkconfig'}) {
			# Redhat-style description: and chkconfig: lines
			&print_tempfile(ACTION, "# description: $_[1]\n");
			&print_tempfile(ACTION, "# chkconfig: $config{'chkconfig'} ",
				     "$start_order $stop_order\n");
			}
		elsif ($config{'init_info'}) {
			# Suse-style init info section
			&print_tempfile(ACTION, "### BEGIN INIT INFO\n",
				     "# Provides: $_[0]\n",
				     "# Required-Start: \$network \$syslog\n",
				     "# Required-Stop: \$network\n",
				     "# Default-Start: ",join(" ", @start),"\n",
				     "# Default-Stop:\n",
				     "# Description: $_[1]\n",
				     "### END INIT INFO\n");
			}
		else {
			&print_tempfile(ACTION, "# $_[1]\n");
			}
		&print_tempfile(ACTION, "\n");
		&print_tempfile(ACTION, "case \"\$1\" in\n");

		if ($_[2]) {
			&print_tempfile(ACTION, "'start')\n");
			&print_tempfile(ACTION, &tab_indent($_[2]));
			&print_tempfile(ACTION, "\tRETVAL=\$?\n");
			if ($config{'subsys'}) {
				&print_tempfile(ACTION, "\tif [ \"\$RETVAL\" = \"0\" ]; then\n");
				&print_tempfile(ACTION, "\t\ttouch $config{'subsys'}/$_[0]\n");
				&print_tempfile(ACTION, "\tfi\n");
				}
			&print_tempfile(ACTION, "\t;;\n");
			}

		if ($_[3]) {
			&print_tempfile(ACTION, "'stop')\n");
			&print_tempfile(ACTION, &tab_indent($_[3]));
			&print_tempfile(ACTION, "\tRETVAL=\$?\n");
			if ($config{'subsys'}) {
				&print_tempfile(ACTION, "\tif [ \"\$RETVAL\" = \"0\" ]; then\n");
				&print_tempfile(ACTION, "\t\trm -f $config{'subsys'}/$_[0]\n");
				&print_tempfile(ACTION, "\tfi\n");
				}
			&print_tempfile(ACTION, "\t;;\n");
			}

		if ($_[4]) {
			&print_tempfile(ACTION, "'status')\n");
			&print_tempfile(ACTION, &tab_indent($_[4]));
			&print_tempfile(ACTION, "\t;;\n");
			}

		if ($_[2] && $_[3]) {
			&print_tempfile(ACTION, "'restart')\n");
			&print_tempfile(ACTION, "\t\$0 stop ; \$0 start\n");
			&print_tempfile(ACTION, "\tRETVAL=\$?\n");
			&print_tempfile(ACTION, "\t;;\n");
			}

		&print_tempfile(ACTION, "*)\n");
		&print_tempfile(ACTION, "\techo \"Usage: \$0 { start | stop }\"\n");
		&print_tempfile(ACTION, "\tRETVAL=1\n");
		&print_tempfile(ACTION, "\t;;\n");
		&print_tempfile(ACTION, "esac\n");
		&print_tempfile(ACTION, "exit \$RETVAL\n");
		&close_tempfile(ACTION);
		chmod(0755, $fn);
		&unlock_file($fn);
		$need_links++;
		}

	if ($need_links && ($init_mode eq "init" ||
			    $init_mode eq "upstart" ||
			    $init_mode eq "systemd")) {
		local $data = &read_file_contents($fn);
		my $done = 0;
		if (&has_command("chkconfig") && !$config{'no_chkconfig'} &&
		    (@chk && $chk[3] || $data =~ /Default-Start:/i)) {
			# Call the chkconfig command to link up
			&system_logged("chkconfig --add ".quotemeta($_[0]));
			my $ex = &system_logged(
				"chkconfig ".quotemeta($_[0])." on");
			if (!$ex) {
				$done = 1;
				}
			}
		elsif (&has_command("insserv") && !$config{'no_chkconfig'} &&
		       $data =~ /Default-Start:/i) {
			# Call the insserv command to enable
			my $ex = &system_logged("insserv ".quotemeta($_[0]).
				       " >/dev/null 2>&1");
			$done = 1 if (!$ex && &action_status($_[0]) == 2);
			}
		if (!$done) {
			# Just link up the init script
			local $s;
			foreach $s (@start) {
				&add_rl_action($_[0], $s, "S", $start_order);
				}
			local @klevels = &action_levels("K", $_[0]);
			if (!@klevels) {
				# Only add K scripts if none exist
				foreach $s (@stop) {
					&add_rl_action($_[0], $s, "K", $stop_order);
					}
				}
			}
		}
	elsif ($need_links) {
		# Just add rc.local entry
		local $lref = &read_file_lines($config{'local_script'});
		local $i;
		for($i=0; $i<@$lref && $lref->[$i] !~ /^exit\s/; $i++) { }
		splice(@$lref, $i, 0, "$fn start");
		if ($config{'local_down'}) {
			# Also add to shutdown script
			$lref = &read_file_lines($config{'local_down'});
			for($i=0; $i<@$lref &&
				  $lref->[$i] !~ /^exit\s/; $i++) { }
			splice(@$lref, $i, 0, "$fn stop");
			}
		&flush_file_lines();
		}
	}
elsif ($init_mode eq "win32") {
	# Enable and/or create a win32 service
	if ($st == 1) {
		# Just enable
		&enable_win32_service($_[0]);
		}
	else {
		# Need to create service, which calls wrapper program
		eval "use Win32::Daemon";

        	# modify the string handed over
	        # so it does not contain backslashes ...
        	$_[2] =~ s/\\/\//g;

		local $perl_path = &get_perl_path();
		local %svc = ( 'name' => $_[0],
			 'display' => $_[1],
			 'path' => $perl_path,
			 'user' => '',
			 'description' => "OCM Webmin Pro Service",
			 'pwd' => $module_root_directory,
			 'parameters' => "\"$module_root_directory/win32.pl\" $_[2]",
			);
		if (!Win32::Daemon::CreateService(\%svc)) {
			print STDERR "Failed to create Win32 service : ",
			     Win32::FormatMessage(Win32::Daemon::GetLastError()),"\n";
			}
		}
	}
elsif ($init_mode eq "rc") {
	# Enable and/or create an RC script
	&lock_rc_files();
	if ($st == 1) {
		# Just enable
		&enable_rc_script($_[0]);
		}
	else {
		# Need to create a local rc script, and enable
		local @dirs = split(/\s+/, $config{'rc_dir'});
		local $file = $dirs[$#dirs]."/".$_[0].".sh";
		local $name = $_[0];
		$name =~ s/-/_/g;
		&open_lock_tempfile(SCRIPT, ">$file");
		&print_tempfile(SCRIPT, "#!/bin/sh\n");
		&print_tempfile(SCRIPT, "#\n");
		&print_tempfile(SCRIPT, "# PROVIDE: $_[0]\n");
		&print_tempfile(SCRIPT, "# REQUIRE: LOGIN\n");
		&print_tempfile(SCRIPT, "\n");
		&print_tempfile(SCRIPT, ". /etc/rc.subr\n");
		&print_tempfile(SCRIPT, "\n");
		&print_tempfile(SCRIPT, "name=$name\n");
		&print_tempfile(SCRIPT, "rcvar=`set_rcvar`\n");
		&print_tempfile(SCRIPT, "start_cmd=\"$_[2]\"\n");
		if ($_[3]) {
			&print_tempfile(SCRIPT, "stop_cmd=\"$_[3]\"\n")
			}
		if ($_[4] && $_[4] !~ /\n/) {
			&print_tempfile(SCRIPT, "status_cmd=\"$_[4]\"\n")
			}
		&print_tempfile(SCRIPT, "\n");
		&print_tempfile(SCRIPT, "load_rc_config \${name}\n");
		&print_tempfile(SCRIPT, "run_rc_command \"\$1\"\n");
		&close_tempfile(SCRIPT);
		&set_ownership_permissions(undef, undef, 0755, $file);
		&enable_rc_script($_[0]);
		}
	&unlock_rc_files();
	}
elsif ($init_mode eq "osx") {
	# Add hostconfig file entry
	local $ucname = uc($_[0]);
	local %hc;
	&lock_file($config{'hostconfig'});
	&read_env_file($config{'hostconfig'}, \%hc);
	if (!$hc{$ucname}) {
		# Need to create action
		local $ucfirst = ucfirst($_[0]);
		local $dir = "$config{'darwin_setup'}/$ucfirst";
		local $paramlist = "$dir/$config{'plist'}";
		local $scriptfile = "$dir/$ucfirst";

		# Create dirs if missing
		if (!-d $config{'darwin_setup'}) {
			&make_dir($config{'darwin_setup'}, 0755);
			}
		if (!-d $dir) {
			&make_dir($dir, 0755);
			}

		# Make params list file
		&open_lock_tempfile(PLIST, ">$paramlist");
		&print_tempfile(PLIST, "{\n");
		&print_tempfile(PLIST, "\t\tDescription\t\t= \"$_[1]\";\n");
		&print_tempfile(PLIST, "\t\tProvides\t\t= (\"$ucfirst\");\n");
		&print_tempfile(PLIST, "\t\tRequires\t\t= (\"Resolver\");\n");
		&print_tempfile(PLIST, "\t\tOrderPreference\t\t= \"None\";\n");
		&print_tempfile(PLIST, "\t\tMessages =\n");
		&print_tempfile(PLIST, "\t\t{\n");
		&print_tempfile(PLIST, "\t\t\tstart\t= \"Starting $ucfirst\";\n");
		&print_tempfile(PLIST, "\t\t\tstop\t= \"Stopping $ucfirst\";\n");
		&print_tempfile(PLIST, "\t\t};\n");
		&print_tempfile(PLIST, "}\n");
		&close_tempfile(PLIST);

		# Create Bootup Script
		&open_lock_tempfile(STARTUP, ">$scriptfile");
		&print_tempfile(STARTUP, "#!/bin/sh\n\n");
		&print_tempfile(STARTUP, ". /etc/rc.common\n\n");
		&print_tempfile(STARTUP, "if [ \"\${$ucname:=-NO-}\" = \"-YES-\" ]; then\n");
		&print_tempfile(STARTUP, "\tConsoleMessage \"Starting $ucfirst\"\n");
		&print_tempfile(STARTUP, "\t$_[2]\n");
		&print_tempfile(STARTUP, "fi\n");
		&close_tempfile(STARTUP);
		&set_ownership_permissions(undef, undef, 0750, $scriptfile);
		}

	# Update hostconfig file
	$hc{$ucname} = '-YES-';
	&write_env_file($config{'hostconfig'}, \%hc);
	&unlock_file($config{'hostconfig'});
	}
elsif ($init_mode eq "launchd") {
	# Create and if necessary enable a launchd agent
	my $name = &launchd_name($_[0]);
	my @agents = &list_launchd_agents();
	my ($agent) = grep { $_->{'name'} eq $name } @agents;
	if (!$agent) {
		# Need to create script
		&create_launchd_agent($name, $_[1], 1);
		}
	else {
		# Just enable at boot
		my $out = &read_file_contents($agent->{'file'});
		if ($out =~ /<key>RunAtLoad<\/key>/i) {
			# Just fix setting
			$out =~ s/<key>RunAtLoad<\/key>\s*<(true|false)\/>/<key>RunAtLoad<\/key>\n<true\/>/;
			}
		else {
			# Defaults to false, so need to add before </plist>
			$out =~ s/<\/plist>/<key>RunAtLoad<\/key>\n<true\/>\n<\/plist>/;
			}
		&open_lock_tempfile(PLIST, ">$agent->{'file'}");
		&print_tempfile(PLIST, $out);
		&close_tempfile(PLIST);
		}
	}
}

=head2 disable_at_boot(action)

Disabled some action from starting at boot, identified by the action
parameter. The config files that define what commands the action runs are not
touched, so it can be re-enabled with the enable_at_boot function.

=cut
sub disable_at_boot
{
my ($name) = @_;
local $st = &action_status($_[0]);
return if ($st == 0);	# does not exist
local $unit = $_[0];
$unit .= ".service" if ($unit !~ /\.service$/);

if ($init_mode eq "upstart") {
	# Just use insserv to disable, and comment out start line in .conf file
	if (&has_command("insserv")) {
		&system_logged(
			"insserv -r ".quotemeta($_[0])." >/dev/null 2>&1");
		}
	my $cfile = "/etc/init/$_[0].conf";
	if (-r $cfile) {
		my $lref = &read_file_lines($cfile);
		my $foundstart;
		foreach my $l (@$lref) {
			if ($l =~ /^start\s/) {
				# Start of start block
				$l = "#".$l;
				$foundstart = 1;
				}
			elsif ($l =~ /^\s+\S/ && $foundstart) {
				# Continuation line for start
				$l = "#".$l;
				}
			elsif ($l =~ /^\S/ && $foundstart) {
				# Some other directive after start
				last;
				}
			}
		&flush_file_lines($cfile);
		}
	}
elsif ($init_mode eq "systemd") {
	# Use systemctl to disable at boot
	&system_logged("systemctl disable ".quotemeta($unit).
		       " >/dev/null 2>&1");
	}
if ($init_mode eq "init" || $init_mode eq "upstart" ||
    $init_mode eq "systemd") {
	# Unlink or disable init script
	local ($daemon, %daemon);
	local $file = &action_filename($_[0]);
	local @chk = &chkconfig_info($file);
	local $data = &read_file_contents($file);

	if ($config{'daemons_dir'} &&
	    &read_env_file("$config{'daemons_dir'}/$_[0]", \%daemon)) {
		# Update daemons file
		$daemon{'ONBOOT'} = 'no';
		&lock_file("$config{'daemons_dir'}/$_[0]");
		&write_env_file("$config{'daemons_dir'}/$_[0]", \%daemon);
		&unlock_file("$config{'daemons_dir'}/$_[0]");
		}
	elsif (&has_command("chkconfig") && !$config{'no_chkconfig'} && @chk) {
		# Call chkconfig to remove the links
		&system_logged("chkconfig ".quotemeta($_[0])." off");
		}
	else {
		# Just unlink the S links
		foreach my $a (&action_levels('S', $_[0])) {
			$a =~ /^(\S+)\s+(\S+)\s+(\S+)$/;
			&delete_rl_action($_[0], $1, 'S');
			}

		if (@chk) {
			# Take out the K links as well, since we know how to put
			# them back from the chkconfig info
			foreach my $a (&action_levels('K', $_[0])) {
				$a =~ /^(\S+)\s+(\S+)\s+(\S+)$/;
				&delete_rl_action($_[0], $1, 'K');
				}
			}
		}
	}
elsif ($init_mode eq "local") {
	# Take out of rc.local file
	local $lref = &read_file_lines($config{'local_script'});
	local $cmd = "$module_config_directory/$_[0].sh start";
	local $i;
	for($i=0; $i<@$lref; $i++) {
		if ($lref->[$i] eq $cmd) {
			splice(@$lref, $i, 1);
			last;
			}
		}
	if ($config{'local_down'}) {
		# Take out of shutdown script
		$lref = &read_file_lines($config{'local_down'});
		local $cmd = "$module_config_directory/$_[0].sh stop";
		for($i=0; $i<@$lref; $i++) {
			if ($lref->[$i] eq $cmd) {
				splice(@$lref, $i, 1);
				last;
				}
			}
		}
	&flush_file_lines();
	}
elsif ($init_mode eq "win32") {
	# Disable the service
	&disable_win32_service($_[0]);
	}
elsif ($init_mode eq "rc") {
	# Disable an RC script
	&lock_rc_files();
	&disable_rc_script($_[0]);
	&unlock_rc_files();
	}
elsif ($init_mode eq "osx") {
	# Disable in hostconfig
	local $ucname = uc($_[0]);
	local %hc;
	&lock_file($config{'hostconfig'});
	&read_env_file($config{'hostconfig'}, \%hc);
	if ($hc{$ucname} eq '-YES-' || $hc{$ucname} eq '-AUTOMATIC-') {
		$hc{$ucname} = '-NO-';
		&write_env_file($config{'hostconfig'}, \%hc);
		}
	&unlock_file($config{'hostconfig'});
	}
elsif ($init_mode eq "launchd") {
	# Adjust plist file to not run at boot
	my @agents = &list_launchd_agents();
	my ($a) = grep { $_->{'name'} eq &launchd_name($name) } @agents;
	if ($a && $a->{'file'}) {
		my $out = &read_file_contents($a->{'file'});
		$out =~ s/<key>RunAtLoad<\/key>\s*<(true|false)\/>/<key>RunAtLoad<\/key>\n<false\/>/;
		&open_lock_tempfile(PLIST, ">$a->{'file'}");
		&print_tempfile(PLIST, $out);
		&close_tempfile(PLIST);
		}
	}
}

=head2 delete_at_boot(name)

Delete the init script, RC script or whatever with some name

=cut
sub delete_at_boot
{
my ($name) = @_;
my $mode = &get_action_mode($name);
if ($mode eq "systemd") {
	# Delete systemd service
	&delete_systemd_service($name);
	&delete_systemd_service($name.".service");
	}
elsif ($mode eq "upstart") {
	# Delete upstart service
	&delete_upstart_service($name);
	}
elsif ($mode eq "launchd") {
	# Delete launchd service
	&delete_launchd_agent(&launchd_name($name));
	}
elsif ($mode eq "init") {
	# Delete init script links and init.d file
	foreach my $a (&action_levels('S', $name)) {
		$a =~ /^(\S+)\s+(\S+)\s+(\S+)$/ &&
			&delete_rl_action($name, $1, 'S');
		}
	foreach my $a (&action_levels('K', $name)) {
		$a =~ /^(\S+)\s+(\S+)\s+(\S+)$/ &&
			&delete_rl_action($name, $1, 'K');
		}
	my $fn = &action_filename($name);
	&unlink_logged($fn);
	}
elsif ($mode eq "win32") {
	# Delete windows service
	&delete_win32_service($name);
	}
elsif ($mode eq "rc") {
	# Delete FreeBSD RC script
	&delete_rc_script($name);
	}
elsif ($mode eq "osx") {
	# Delete OSX hostconfig entry
	open(LOCAL, $config{'hostconfig'});
	my @local = <LOCAL>;
	close(LOCAL);
	my $start = $name."=-";
	&open_tempfile(LOCAL, ">$config{'hostconfig'}");
	&print_tempfile(LOCAL, grep { !/^$start/i } @local);
	&close_tempfile(LOCAL);
	my $paramlist = "$config{'darwin_setup'}/$ucproduct/$config{'plist'}";
	my $scriptfile = "$config{'darwin_setup'}/$ucproduct/$ucproduct";
	&unlink_logged($paramlist);
	&unlink_logged($scriptfile);
	}
elsif ($mode eq "local") {
	# Delete from local rc file
	&disable_at_boot($name);
	}
}

=head2 start_action(name)

Start the action with the given name, using whatever method is appropriate
for this operating system. Returns a status code (0 or 1 for failure or 
success) and all output from the action script.

=cut
sub start_action
{
local ($name) = @_;
local $action_mode = &get_action_mode($name);
if ($action_mode eq "init" || $action_mode eq "local") {
	# Run the init script or Webmin-created wrapper
	local $fn = $action_mode eq "init" ? &action_filename($name) :
			"$module_config_directory/$name.sh";
	if (!-x $fn) {
		return (0, "$fn does not exist");
		}
	&clean_environment();
	local $out = &backquote_logged("$fn start 2>&1 </dev/null");
	&reset_environment();
	local $ex = $?;
	return (!$ex, $out);
	}
elsif ($action_mode eq "rc") {
	# Run FreeBSD RC script
	return &start_rc_script($name);
	}
elsif ($action_mode eq "win32") {
	# Start Windows service
	local $err = &start_win32_service($name);
	return (!$err, $err);
	}
elsif ($action_mode eq "upstart") {
	# Run upstart action
	return &start_upstart_service($name);
	}
elsif ($action_mode eq "systemd") {
	# Start systemd service
	return &start_systemd_service($name);
	}
elsif ($action_mode eq "launchd") {
	# Start launchd service
	return &start_launchd_agent(&launchd_name($name));
	}
else {
	return (0, "Bootup mode $action_mode not supported");
	}
}

=head2 stop_action(name)

Stop the action with the given name, using whatever method is appropriate
for this operating system. Returns a status code (0 or 1 for failure or
success) and all output from the action script.

=cut
sub stop_action
{
local ($name) = @_;
local $action_mode = &get_action_mode($name);
if ($action_mode eq "init" || $action_mode eq "local") {
	# Run the init script or Webmin-created wrapper
	local $fn = $action_mode eq "init" ? &action_filename($name) :
			"$module_config_directory/$name.sh";
	if (!-x $fn) {
		return (0, "$fn does not exist");
		}
	local $out = &backquote_logged("$fn stop 2>&1 </dev/null");
	local $ex = $?;
	return (!$ex, $out);
	}
elsif ($action_mode eq "rc") {
	# Run FreeBSD RC script
	return &stop_rc_script($name);
	}
elsif ($action_mode eq "win32") {
	# Start Windows service
	local $err = &stop_win32_service($name);
	return (!$err, $err);
	}
elsif ($action_mode eq "upstart") {
	# Stop upstart action
	return &stop_upstart_service($name);
	}
elsif ($action_mode eq "systemd") {
	# Stop systemd service
	return &stop_systemd_service($name);
	}
elsif ($action_mode eq "launchd") {
	# Stop launchd service
	return &stop_launchd_agent(&launchd_name($name));
	}
else {
	return (0, "Bootup mode $action_mode not supported");
	}
}

=head2 restart_action(action)

Calls a stop then a start for some named action.

=cut
sub restart_action
{
local ($name) = @_;
local $action_mode = &get_action_mode($name);
if ($action_mode eq "upstart") {
	return &restart_upstart_service($name);
	}
elsif ($action_mode eq "systemd") {
	return &restart_systemd_service($name);
	}
else {
	&stop_action($name);
	return &start_action($name);
	}
}

=head2 status_action(name)

Returns 1 if some action is running right now, 0 if not, or -1 if unknown

=cut
sub status_action
{
local ($name) = @_;
local $action_mode = &get_action_mode($name);
if ($action_mode eq "init") {
	# Run init script to get status
	return &action_running(&action_filename($name));
	}
elsif ($action_mode eq "win32") {
	# Check with Windows if it is running
	my ($w) = &list_win32_services($name);
	return !$w ? -1 : $w->{'status'} == 4 ? 1 : 0;
	}
elsif ($action_mode eq "upstart") {
	# Check with upstart if it is running
	my @upstarts = &list_upstart_services();
	my ($u) = grep { $_->{'name'} eq $name } @upstarts;
	return !$u ? -1 : $u>{'status'} eq 'running' ? 1 :
	       $u->{'status'} eq 'waiting' ? 0 : -1;
	}
elsif ($action_mode eq "systemd") {
	# Check with systemd if it is running
	my @systemds = &list_systemd_services();
	my ($u) = grep { $_->{'name'} eq $name ||
			 $_->{'name'} eq $name.".service" } @systemds;
	return !$u ? -1 : $u->{'status'} ? 1 : 0;
	}
elsif ($action_mode eq "launchd") {
	my @agents = &list_launchd_agents();
	my ($a) = grep { $_->{'name'} eq &launchd_name($name) } @agents;
	return !$u ? -1 : $u->{'status'} ? 1 : 0;
	}
else {
	return -1;
	}
}

=head2 get_action_mode(name)

Returns the init mode used by some action. May be different from the global
default on systems with mixed modes

=cut
sub get_action_mode
{
local ($name) = @_;
if ($init_mode eq "systemd") {
	# If classic init script exists but no systemd unit, assume init
	if (-r "$config{'init_dir'}/$name" && !&is_systemd_service($name)) {
		return "init";
		}
	}
elsif ($init_mode eq "upstart") {
	# If classic init script exists but not upstart config, assume init
	if (-r "$config{'init_dir'}/$name" && !-r "/etc/init/$name.conf") {
		return "init";
		}
	}
return $init_mode;
}

=head2 tab_indent(lines)

Given a string with multiple \n separated lines, returns the same string
with lines prefixed by tabs.

=cut
sub tab_indent
{
local ($rv, $l);
foreach $l (split(/\n/, $_[0])) {
	$rv .= "\t$l\n";
	}
return $rv;
}

=head2 get_start_runlevels

Returns a list of runlevels that actions should be started in, either based
on the module configuration or /etc/inittab.

=cut
sub get_start_runlevels
{
if ($config{'boot_levels'}) {
	return split(/[ ,]+/, $config{'boot_levels'});
	}
else {
	local @boot = &get_inittab_runlevel();
	return ( $boot[0] );
	}
}

=head2 runlevel_dir(runlevel)

Given a runlevel like 3, returns the directory containing symlinks for it,
like /etc/rc2.d.

=cut
sub runlevel_dir
{
if ($_[0] eq "boot") {
	return "$config{init_base}/boot.d";
	}
else {
	return "$config{init_base}/rc$_[0].d";
	}
}

=head2 list_win32_services([name])

Returns a list of known Win32 services, each of which is a hash ref. If the
name parameter is given, only details of that service are returned. Useful
keys for each hash are :

=item name - A unique name for the service.

=item desc - A human-readable description.

=item boot - Set to 2 if started at boot, 3 if not, 4 if disabled.

=item state -Set to 4 if running now, 1 if stopped.

=cut
sub list_win32_services
{
local ($name) = @_;
local @rv;
local $svc;

# Get the current statuses
if ($name) {
	&open_execute_command(SC, "sc query $name", 1, 1);
	}
else {
	&open_execute_command(SC, "sc query type= service state= all", 1, 1);
	}
while(<SC>) {
	s/\r|\n//g;
	if (/^SERVICE_NAME:\s+(\S.*\S)/) {
		$svc = { 'name' => $1 };
		push(@rv, $svc);
		}
	elsif (/^DISPLAY_NAME:\s+(\S.*)/ && $svc) {
		$svc->{'desc'} = $1;
		}
	elsif (/^\s+TYPE\s+:\s+(\d+)\s+(\S+)/ && $svc) {
		$svc->{'type'} = $1;
		$svc->{'type_desc'} = $2;
		}
	elsif (/^\s+STATE\s+:\s+(\d+)\s+(\S+)/ && $svc) {
		$svc->{'state'} = $1;
		$svc->{'state_desc'} = $2;
		}
	}
close(SC);

# For each service, see if it starts at boot or not
foreach $svc (@rv) {
	&open_execute_command(SC, "sc qc \"$svc->{'name'}\"", 1, 1);
	while(<SC>) {
		s/\r|\n//g;
		if (/^\s+START_TYPE\s+:\s+(\d+)\s+(\S+)/) {
			$svc->{'boot'} = $1;
			$svc->{'boot_desc'} = $2;
			}
		}
	close(SC);
	}

return @rv;
}

=head2 start_win32_service(name)

Attempts to start a service, returning undef on success, or some error message.

=cut
sub start_win32_service
{
local ($name) = @_;
local $out = &backquote_command("sc start \"$name\" 2>&1");
return $? ? $out : undef;
}

=head2 stop_win32_service(name)

Attempts to stop a service, returning undef on success, or some error message.

=cut
sub stop_win32_service
{
local ($name) = @_;
local $out = &backquote_command("sc stop \"$name\" 2>&1");
return $? ? $out : undef;
}

=head2 enable_win32_service(name)

Marks some service as starting at boot time. Returns undef on success or an
error message on failure.

=cut
sub enable_win32_service
{
local ($name) = @_;
local $out = &backquote_command("sc config \"$name\" start= auto 2>&1");
return $? ? $out : undef;
}

=head2 disable_win32_service(name)

Marks some service as disabled at boot time. Returns undef on success or an
error message on failure.

=cut
sub disable_win32_service
{
local ($name) = @_;
local $out = &backquote_command("sc config \"$name\" start= demand 2>&1");
return $? ? $out : undef;
}

=head2 create_win32_service(name, command, desc)

Creates a new win32 service, enabled at boot time. The required parameters are:
name - A unique name for the service
command - The DOS command to run at boot time
desc - A human-readable description.

=cut
sub create_win32_service
{
local ($name, $cmd, $desc) = @_;
local $out = &backquote_command("sc create \"$name\" DisplayName= \"$desc\" type= share start= auto binPath= \"$cmd\" 2>&1");
return $? ? $out : undef;
}

=head2 delete_win32_service(name)

Delete some existing service, identified by some name. Returns undef on
success or an error message on failure.

=cut
sub delete_win32_service
{
local ($name) = @_;
local $out = &backquote_command("sc delete \"$name\" 2>&1");
return $? ? $out : undef;
}

=head2 list_rc_scripts

Returns a list of known BSD RC scripts, and their enabled statuses. Each
element of the return list is a hash ref, with the following keys :

=item name - A unique name for the script.

=item desc - A human-readable description.

=item enabled - Set to 1 if enabled, 0 if not, 2 if unknown.

=item file - Full path to the action script file.

=item standard - Set to 0 for user-defined actions, 1 for those supplied with FreeBSD.

=cut
sub list_rc_scripts
{
# Build a list of those that are enabled in the rc.conf files
local @rc = &get_rc_conf();
local (%enabled, %cmt);
foreach my $r (@rc) {
	if ($r->{'name'} =~ /^(\S+)_enable$/) {
		local $name = $1;
		if (lc($r->{'value'}) eq 'yes') {
			$enabled{$name} = 1;
			}
		$r->{'cmt'} =~ s/\s*\(\s*or\s+NO\)//i;
		$r->{'cmt'} =~ s/\s*\(YES.*NO\)//i;
		$cmt{$name} ||= $r->{'cmt'};
		}
	}

# Scan the script dirs
local @rv;
foreach my $dir (split(/\s+/, $config{'rc_dir'})) {
	opendir(DIR, $dir);
	foreach my $f (readdir(DIR)) {
		next if ($f =~ /^\./ || $f =~ /\.(bak|tmp)/i);
		next if (uc($f) eq $f);		# Dummy actions are upper-case
		local $name = $f;
		$name =~ s/\.sh$//;
		local $data = &read_file_contents("$dir/$f");
		local $ename = $name;
		$ename =~ s/-/_/g;
		push(@rv, { 'name' => $name,
			    'file' => "$dir/$f",
			    'enabled' => $data !~ /rc\.subr/ ? 2 :
					 $enabled{$ename},
			    'startstop' => $data =~ /rc\.subr/ ||
					   $data =~ /start\)/,
			    'desc' => $cmt{$name},
			    'standard' => ($dir !~ /local/)
			  });
		}
	closedir(DIR);
	}
return sort { $a->{'name'} cmp $b->{'name'} } @rv;
}

=head2 save_rc_conf(name, value)

Internal function to modify the value of a single entry in the FreeBSD
rc.conf file.

=cut
sub save_rc_conf
{
local $found;
local @rcs = split(/\s+/, $config{'rc_conf'});
local $rcfile = $rcs[$#rcs];
&open_readfile(CONF, $rcfile);
local @conf = <CONF>;
close(CONF);
&open_tempfile(CONF, ">$rcfile");
foreach (@conf) {
	if (/^\s*([^=]+)\s*=\s*(.*)/ && $1 eq $_[0]) {
		&print_tempfile(CONF, "$_[0]=\"$_[1]\"\n") if (@_ > 1);
		$found++;
		}
	else {
		&print_tempfile(CONF, $_);
		}
	}
if (!$found && @_ > 1) {
	&print_tempfile(CONF, "$_[0]=\"$_[1]\"\n");
	}
&close_tempfile(CONF);
}

=head2 get_rc_conf

Reads the default and system-specific FreeBSD rc.conf files, and parses
them into a list of hash refs. Each element in the list has the following keys:

=item name - Name of this configuration parameter. May appear more than once, with the later one taking precedence.

=item value - Current value.

=item cmt - A human-readable comment about the parameter.

=cut
sub get_rc_conf
{
local ($file, @rv);
foreach $file (map { glob($_) } split(/\s+/, $config{'rc_conf'})) {
	local $lnum = 0;
	&open_readfile(FILE, $file);
	while(<FILE>) {
		local $cmt;
		s/\r|\n//g;
		if (s/#(.*)$//) {
			$cmt = $1;
			}
		if (/^\s*([^=\s]+)\s*=\s*"(.*)"/ ||
		    /^\s*([^=\s]+)\s*=\s*'(.*)'/ ||
		    /^\s*([^=\s]+)\s*=\s*(\S+)/) {
			push(@rv, { 'name' => $1,
				    'value' => $2,
				    'line' => $lnum,
				    'file' => $file,
				    'cmt' => $cmt });
			}
		$lnum++;
		}
	close(FILE);
	}
return @rv;
}

=head2 enable_rc_script(name)

Mark some RC script as enabled at boot.

=cut
sub enable_rc_script
{
local ($name) = @_;
$name =~ s/-/_/g;
&save_rc_conf($name."_enable", "YES");
}

=head2 disable_rc_script(name)

Mark some RC script as disabled at boot.

=cut
sub disable_rc_script
{
local ($name) = @_;
$name =~ s/-/_/g;
local $enabled;
foreach my $r (&get_rc_conf()) {
	if ($r->{'name'} eq $name."_enable" &&
	    lc($r->{'value'}) eq 'yes') {
		$enabled = 1;
		}
	}
&save_rc_conf($name."_enable", "NO") if ($enabled);
}

=head2 start_rc_script(name)

Attempt to start some RC script, and returns 1 or 0 (for success or failure)
and the output.

=cut
sub start_rc_script
{
local ($name) = @_;
local @rcs = &list_rc_scripts();
local ($rc) = grep { $_->{'name'} eq $name } @rcs;
$rc || return "No script found for $name";
local $out = &backquote_logged("$rc->{'file'} forcestart 2>&1 </dev/null");
return (!$?, $out);
}

=head2 stop_rc_script(name)

Attempts to stop some RC script, and returns 1 or 0 (for success or failure)
and the output.

=cut
sub stop_rc_script
{
local ($name) = @_;
local @rcs = &list_rc_scripts();
local ($rc) = grep { $_->{'name'} eq $name } @rcs;
$rc || return "No script found for $name";
local $out = &backquote_logged("$rc->{'file'} forcestop 2>&1 </dev/null");
return (!$?, $out);
}

=head2 delete_rc_script(name)

Delete the FreeBSD RC script with some name

=cut
sub delete_rc_script
{
local ($name) = @_;
my @rcs = &list_rc_scripts();
my ($rc) = grep { $_->{'name'} eq $name } @rcs;
if ($rc) {
	&lock_rc_files();
	&disable_rc_script($in{'name'});
	&unlock_rc_files();
	&unlink_logged($rc->{'file'});
	}
}

=head2 lock_rc_files

Internal function to lock all FreeBSD rc.conf files.

=cut
sub lock_rc_files
{
foreach my $f (split(/\s+/, $config{'rc_conf'})) {
	&lock_file($f);
	}
}

=head2 unlock_rc_files

Internal function to un-lock all FreeBSD rc.conf files.

=cut
sub unlock_rc_files
{
foreach my $f (split(/\s+/, $config{'rc_conf'})) {
	&unlock_file($f);
	}
}

=head2 list_upstart_services

Returns a list of all known upstart services, each of which is a hash ref
with 'name', 'desc', 'boot', 'status' and 'pid' keys. Also includes init.d
scripts, but if both exist then the native service will be preferred.

=cut
sub list_upstart_services
{
# Start with native upstart services
my @rv;
my $out = &backquote_command("initctl list");
my %done;
foreach my $l (split(/\r?\n/, $out)) {
	if ($l =~ /^(\S+)\s+(start|stop)\/([a-z]+)/) {
		my $s = { 'name' => $1,
			  'goal' => $2,
			  'status' => $3 };
		if ($l =~ /process\s+(\d+)/) {
			$s->{'pid'} = $1;
			}
		open(CONF, "/etc/init/$s->{'name'}.conf");
		while(<CONF>) {
			if (/^description\s+"([^"]+)"/ && !$s->{'desc'}) {
				$s->{'desc'} = $1;
				}
			elsif (/^(#*)\s*start/ && !$s->{'boot'}) {
				$s->{'boot'} = $1 ? 'stop' : 'start';
				}
			}
		close(CONF);
		push(@rv, $s);
		$done{$s->{'name'}} = 1;
		}
	}

# Also add legacy init scripts
my @rls = &get_inittab_runlevel();
foreach my $a (&list_actions()) {
	$a =~ s/\s+\d+$//;
	next if ($done{$a});
	my $f = &action_filename($a);
	my $s = { 'name' => $a,
		  'legacy' => 1 };
	$s->{'boot'} = 'stop';
	foreach my $rl (@rls) {
		my $l = glob("/etc/rc$rl.d/S*$a");
		$s->{'boot'} = 'start' if ($l);
		}
	$s->{'desc'} = &init_description($f);
	my $hasarg = &get_action_args($f);
	if ($hasarg->{'status'}) {
		my $r = &action_running($f);
		if ($r == 0) {
			$s->{'status'} = 'waiting';
			}
		elsif ($r == 1) {
			$s->{'status'} = 'running';
			}
		}
	push(@rv, $s);
	}

return sort { $a->{'name'} cmp $b->{'name'} } @rv;
}

=head2 start_upstart_service(name)

Run the upstart service with some name, and return an OK flag and output

=cut
sub start_upstart_service
{
my ($name) = @_;
my $out = &backquote_logged(
	"initctl start ".quotemeta($name)." 2>&1 </dev/null");
return (!$?, $out);
}

=head2 stop_upstart_service(name)

Shut down the upstart service with some name, and return an OK flag and output

=cut
sub stop_upstart_service
{
my ($name) = @_;
my $out = &backquote_logged(
	"initctl stop ".quotemeta($name)." 2>&1 </dev/null");
return (!$?, $out);
}

=head2 restart_upstart_service(name)

Restart the upstart service with some name, and return an OK flag and output

=cut
sub restart_upstart_service
{
my ($name) = @_;
my $out = &backquote_logged(
	"service ".quotemeta($name)." restart 2>&1 </dev/null");
return (!$?, $out);
}

=head2 create_upstart_service(name, description, command, [pre-script], [fork])

Create a new upstart service with the given details.

=cut
sub create_upstart_service
{
my ($name, $desc, $server, $prestart, $forks) = @_;
my $cfile = "/etc/init/$name.conf";
&open_lock_tempfile(CFILE, ">$cfile");
&print_tempfile(CFILE,
  "# $name\n".
  "#\n".
  "# $desc\n".
  "\n".
  "description  \"$desc\"\n".
  "\n".
  "start on runlevel [2345]\n".
  "stop on runlevel [!2345]\n".
  "\n"
  );
if ($forks) {
	&print_tempfile(CFILE,
	  "expect fork\n".
	  "\n"
	  );
	}
if ($prestart) {
	&print_tempfile(CFILE,
	  "pre-start script\n".
	  join("\n",
	    map { "    ".$_."\n" }
		split(/\n/, $prestart))."\n".
	  "end script\n".
	  "\n");
	}
&print_tempfile(CFILE, "exec ".$server."\n");
&close_tempfile(CFILE);
}

=head2 delete_upstart_service(name)

Delete all traces of some upstart service

=cut
sub delete_upstart_service
{
my ($name) = @_;
if (&has_command("insserv")) {
	&system_logged("insserv -r ".quotemeta($name)." >/dev/null 2>&1");
	}
my $cfile = "/etc/init/$name.conf";
my $ifile = "/etc/init.d/$name";
&unlink_logged($cfile, $ifile);
}

=head2 list_systemd_services

Returns a list of all known systemd services, each of which is a hash ref
with 'name', 'desc', 'boot', 'status' and 'pid' keys. Also includes init.d
scripts, which will be preferred over native systemd services (because sometimes
systemd automatically includes init scripts).

=cut
sub list_systemd_services
{
# Get all systemd unit names
my $out = &backquote_command("systemctl list-units --full --all -t service --no-legend");
&error("Failed to list systemd units : $out") if ($?);
foreach my $l (split(/\r?\n/, $out)) {
	$l =~ s/^[^a-z0-9\-\_\.]+//i;
	my ($unit, $loaded, $active, $sub, $desc) = split(/\s+/, $l, 5);
	my $a = $unit;
	$a =~ s/\.service$//;
	my $f = &action_filename($a);
	if ($unit ne "UNIT" && $loaded eq "loaded" && !-r $f) {
		push(@units, $unit);
		}
	}

# Also find unit files for units that may be disabled at boot and not running,
# and so don't show up in systemctl list-units
my $root = &get_systemd_root();
opendir(UNITS, $root);
push(@units, grep { !/\.wants$/ && !/^\./ && !-d "$root/$_" } readdir(UNITS));
closedir(UNITS);

# Also add units from list-unit-files that also don't show up
$out = &backquote_command("systemctl list-unit-files -t service --no-legend");
foreach my $l (split(/\r?\n/, $out)) {
	if ($l =~ /^(\S+\.service)\s+disabled/ ||
	    $l =~ /^(\S+)\s+disabled/) {
		push(@units, $1);
		}
	}

# Skip useless units
@units = grep { !/^sys-devices-/ &&
	        !/^\-\.mount/ &&
	        !/^\-\.slice/ &&
		!/^dev-/ &&
		!/^systemd-/ } @units;
@units = &unique(@units);

# Filter out templates
my @templates = grep { /\@$/ || /\@\.service$/ } @units;
@units = grep { !/\@$/ && !/\@\.service$/ } @units;

# Dump state of all of them, 100 at a time
my %info;
my $ecount = 0;
while(@units) {
	my @args;
	while(@args < 100 && @units) {
		push(@args, shift(@units));
		}
	$out = &backquote_command("systemctl show -- ".join(" ", @args).
				  " 2>/dev/null");
	my @lines = split(/\r?\n/, $out);
	my $curr;
	foreach my $l (@lines) {
		my ($n, $v) = split(/=/, $l, 2);
		next if (!$n);
		if (lc($n) eq 'id') {
			$curr = $v;
			$info{$curr} ||= { };
			}
		if ($curr) {
			$info{$curr}->{$n} = $v;
			}
		}
	$ecount++ if ($?);
	}
if ($ecount && keys(%info) < 2) {
	&error("Failed to read systemd units : $out");
	}

# Extract info we want
my @rv;
foreach my $name (keys %info) {
	my $root = &get_systemd_root($name);
	my $i = $info{$name};
	next if ($i->{'Description'} =~ /^LSB:\s/);
	push(@rv, { 'name' => $name,
		    'desc' => $i->{'Description'},
		    'legacy' => 0,
		    'boot' => $i->{'UnitFileState'} eq 'enabled' ? 1 :
			      $i->{'UnitFileState'} eq 'static' ? 2 : 0,
		    'status' => $i->{'ActiveState'} eq 'active' ? 1 : 0,
		    'start' => $i->{'ExecStart'},
		    'stop' => $i->{'ExecStop'},
		    'reload' => $i->{'ExecReload'},
		    'pid' => $i->{'ExecMainPID'},
		    'file' => $root."/".$name,
		  });
	}

# Also add legacy init scripts
my @rls = &get_inittab_runlevel();
foreach my $a (&list_actions()) {
	$a =~ s/\s+\d+$//;
	my $f = &action_filename($a);
	my $s = { 'name' => $a,
		  'legacy' => 1 };
	$s->{'boot'} = 0;
	foreach my $rl (@rls) {
		my $l = glob("/etc/rc$rl.d/S*$a");
		$s->{'boot'} = 1 if ($l);
		}
	$s->{'desc'} = &init_description($f);
	my $hasarg = &get_action_args($f);
	if ($hasarg->{'status'}) {
		my $r = &action_running($f);
		$s->{'status'} = $r;
		}
	push(@rv, $s);
	}

return sort { $a->{'name'} cmp $b->{'name'} } @rv;
}

=head2 start_systemd_service(name)

Run the systemd service with some name, and return an OK flag and output

=cut
sub start_systemd_service
{
my ($name) = @_;
my $out = &backquote_logged(
	"systemctl start ".quotemeta($name)." 2>&1 </dev/null");
if ($? && $out =~ /journalctl/) {
	$out .= &backquote_command("journalctl -xe 2>/dev/null");
	}
return (!$?, $out);
}

=head2 stop_systemd_service(name)

Shut down the systemctl service with some name, and return an OK flag and output

=cut
sub stop_systemd_service
{
my ($name) = @_;
my $out = &backquote_logged(
	"systemctl stop ".quotemeta($name)." 2>&1 </dev/null");
return (!$?, $out);
}

=head2 restart_systemd_service(name)

Restart the systemd service with some name, and return an OK flag and output

=cut
sub restart_systemd_service
{
my ($name) = @_;
my $out = &backquote_logged(
	"systemctl restart ".quotemeta($name)." 2>&1 </dev/null");
return (!$?, $out);
}

=head2 create_systemd_service(name, description, start-script, stop-script,
			      restart-script, [forks], [pidfile])

Create a new systemd service with the given details.

=cut
sub create_systemd_service
{
my ($name, $desc, $start, $stop, $restart, $forks, $pidfile, $exits) = @_;
$start =~ s/\r?\n/ ; /g;
$stop =~ s/\r?\n/ ; /g;
$restart =~ s/\r?\n/ ; /g;
my $sh = &has_command("sh") || "sh";
if ($start =~ /<|>/) {
	$start = "$sh -c '$start'";
	}
if ($restart =~ /<|>/) {
	$restart = "$sh -c '$restart'";
	}
if ($stop =~ /<|>/) {
	$stop = "$sh -c '$stop'";
	}
my $cfile = &get_systemd_root($name)."/".$name;
&open_lock_tempfile(CFILE, ">$cfile");
&print_tempfile(CFILE, "[Unit]\n");
&print_tempfile(CFILE, "Description=$desc\n") if ($desc);
&print_tempfile(CFILE, "\n");
&print_tempfile(CFILE, "[Service]\n");
&print_tempfile(CFILE, "ExecStart=$start\n");
&print_tempfile(CFILE, "ExecStop=$stop\n") if ($stop);
&print_tempfile(CFILE, "ExecReload=$restart\n") if ($restart);
&print_tempfile(CFILE, "Type=forking\n") if ($forks);
&print_tempfile(CFILE, "Type=oneshot\n",
		       "RemainAfterExit=yes\n") if ($exits);
&print_tempfile(CFILE, "PIDFile=$pidfile\n") if ($pidfile);
&print_tempfile(CFILE, "\n");
&print_tempfile(CFILE, "[Install]\n");
&print_tempfile(CFILE, "WantedBy=multi-user.target\n");
&close_tempfile(CFILE);
&restart_systemd();
}

=head2 delete_systemd_service(name)

Delete all traces of some systemd service

=cut
sub delete_systemd_service
{
my ($name) = @_;
&unlink_logged(&get_systemd_root($name)."/".$name);
&unlink_logged(&get_systemd_root($name)."/".$name.".service");
&restart_systemd();
}

=head2 is_systemd_service(name)

Returns 1 if some service is managed by systemd

=cut
sub is_systemd_service
{
my ($name) = @_;
foreach my $s (&list_systemd_services()) {
	if ($s->{'name'} eq $name && !$s->{'legacy'}) {
		return 1;
		}
	}
return 0;
}

=head2 get_systemd_root([name])

Returns the base directory for systemd unit config files

=cut
sub get_systemd_root
{
my ($name) = @_;
if ($name && (-r "/etc/systemd/system/$name.service" ||
	      -r "/etc/systemd/system/$name")) {
	return "/etc/systemd/system";
	}
if (-d "/usr/lib/systemd/system") {
	return "/usr/lib/systemd/system";
	}
return "/lib/systemd/system";
}

=head2 restart_systemd()

Tell the systemd daemon to re-read its config

=cut
sub restart_systemd
{
my @pids = &find_byname("systemd");
if (@pids) {
	&kill_logged('HUP', @pids);
	&system_logged("systemctl --system daemon-reload >/dev/null 2>&1");
	}
}

=head2 reboot_system

Immediately reboots the system.

=cut
sub reboot_system
{
&system_logged("$config{'reboot_command'} >$null_file 2>$null_file");
}

=head2 shutdown_system

Immediately shuts down the system.

=cut
sub shutdown_system
{
&system_logged("$config{'shutdown_command'} >$null_file 2>$null_file");
}

=head2 get_action_args(filename)

Returns the args that this action script appears to support, like stop, start
and status.

=cut
sub get_action_args
{
my ($file) = @_;
my %hasarg;
open(FILE, $file);
while(<FILE>) {
	if (/^\s*(['"]?)([a-z]+)\1\)/i) {
		$hasarg{$2}++;
		}
	}
close(FILE);
return \%hasarg;
}

=head2 action_running(filename)

Assuming some init.d action supports the status parameter, returns a 1 if
running, 0 if not, or -1 if unknown

=cut
sub action_running
{
my ($file) = @_;
&clean_language();
my ($out, $timedout) = &backquote_with_timeout("$file status", 2);
&reset_environment();
if ($timedout) {
	return -1;
	}
elsif ($out =~ /not\s+running/i ||
       $out =~ /no\s+server\s+running/i) {
	return 0;
	}
elsif ($out =~ /running/i) {
	return 1;
	}
elsif ($out =~ /stopped/i) {
	return 0;
	}
return -1;
}

=head2 list_launchd_agents()

Returns an array of hash refs, each of which is a launchd daemon/agent

=cut
sub list_launchd_agents
{
my @rv;

# Get the initial list of actions
my $out = &backquote_command("launchctl list");
&error("Failed to list launchd agents : $out") if ($?);
foreach my $l (split(/\r?\n/, $out)) {
	next if ($l =~ /^PID/);		# Header line
	my ($pid, $status, $label) = split(/\s+/, $l);
	next if ($label =~ /^0x/);	# Not really a launchd job
	next if ($label =~ /\.peruser\./);	# Skip user-owned actions
	push(@rv, { 'name' => $label,
		    'status' => $pid eq "-" ? 0 : 1,
		    'pid' => $pid eq "-" ? undef : $pid, });
	}

# Build map from plist files to agents
my @dirs = ("/Library/LaunchAgents",
            "/Library/LaunchDaemons",
            "/System/Library/LaunchAgents",
            "/System/Library/LaunchDaemons");
my (%pmap, %runatload);
foreach my $dir (@dirs) {
	foreach my $file (glob("$dir/*.plist")) {
		my $plist = &read_file_contents($file);
		if ($plist =~ /<key>Label<\/key>\s*<string>([^<]+)/i) {
			$pmap{$1} = $file;
			}
		if ($plist =~ /<key>RunAtLoad<\/key>\s*<(true|false)\/>/i) {
			$runatload{$file} = $1;
			}
		}
	}

# Get details on each one
foreach my $a (@rv) {
	my $out = &backquote_command("launchctl list ".quotemeta($a->{'name'}));
	my %attrs;
	foreach my $l (split(/\r?\n/, $out)) {
		if ($l =~ /"(\S+)"\s*=\s*"([^"]*)";/ ||
		    $l =~ /"(\S+)"\s*=\s*(\S+);/) {
			$attrs{lc($1)} = $2;
			}
		}
	$a->{'start'} = $attrs{'program'};
	$a->{'file'} = $pmap{$a->{'name'}};
	$a->{'boot'} = $runatload{$a->{'file'}} eq 'true';
	}

return @rv;
}

=head2 create_launchd_agent(name, start-script, boot-flag)

Creates a new local launchd agent

=cut
sub create_launchd_agent
{
my ($name, $start, $boot) = @_;
my $file = "/Library/LaunchDaemons/".$name.".plist";
my $plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n".
	    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n".
	    "<plist version=\"1.0\">\n".
	    "<dict>\n".
	    "<key>Label</key>\n";
$plist .= "<string>$name</string>\n";
$plist .= "<key>ProgramArguments</key>\n";
$plist .= "<array>\n";
foreach my $a (&split_quoted_string($start)) {
        $plist .= "<string>$a</string>\n";
	}
$plist .= "</array>\n";
$plist .= "<key>RunAtLoad</key>\n";
$plist .= ($boot ? "<true/>\n" : "<false/>\n");
$plist .= "<key>KeepAlive</key>\n";
$plist .= "<false/>\n";
$plist .= "</dict>\n";
$plist .= "</plist>\n";
&open_lock_tempfile(PLIST, ">$file");
&print_tempfile(PLIST, $plist);
&close_tempfile(PLIST);
my $out = &backquote_logged("launchctl load ".quotemeta($file)." 2>&1");
&error("Failed to load plist : $out") if ($?);
}

=head2 delete_launchd_agent(name)

Stop and remove the agent with some name

=cut
sub delete_launchd_agent
{
my ($name) = @_;
&system_logged("launchctl stop ".quotemeta($name)." 2>&1");
&system_logged("launchctl remove ".quotemeta($name)." 2>&1");
my ($a) = grep { $_->{'name'} eq $name } &list_launchd_agents();
if ($a && $a->{'file'} && -f $a->{'file'}) {
	&system_logged("launchctl unload ".quotemeta($a->{'file'})." 2>&1");
	&unlink_logged($a->{'file'});
	}
}

=head2 stop_launchd_agent(name)

Kill the launchd daemon with some name

=cut
sub stop_launchd_agent
{
my ($name) = @_;
my $out = &backquote_logged(
	"launchctl stop ".quotemeta($name)." 2>&1 </dev/null");
return (!$?, $out);
}

=head2 start_launchd_agent(name)

Startup the launchd daemon with some name

=cut
sub start_launchd_agent
{
my ($name) = @_;
my $out = &backquote_logged(
	"launchctl start ".quotemeta($name)." 2>&1 </dev/null");
return (!$?, $out);
}

# launchd_name(name)
# If an action name isn't fully qualified, prepend com.webmin to it
sub launchd_name
{
my ($name) = @_;
return $name =~ /\./ ? $name : "com.webmin.".$name;
}

1;
