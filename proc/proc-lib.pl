# proc-lib.pl
# Functions for managing processes

BEGIN { push(@INC, ".."); };
use WebminCore;
use POSIX;
use Config;

&init_config();
if ($module_info{'usermin'} && !$ENV{'FOREIGN_MODULE_NAME'}) {
	&switch_to_remote_user();
	}
do "$config{ps_style}-lib.pl";
if ($module_info{'usermin'}) {
	%access = ( 'edit' => 1,
		    'run' => 1,
		    'users' => 'x' );
	$no_module_config = 1;
	$user_processes_only = 1;
	$index_file = "$user_module_config_directory/index";
	}
else {
	%access = &get_module_acl();
	map { $hide{$_}++ } split(/\s+/, $access{'hide'});
	$index_file = "$module_config_directory/index";
	$user_processes_only = $access{'only'};
	if (!defined($access{'users'})) {
		$access{'users'} = $access{'uid'} < 0 ? "x" :
				   $access{'uid'} == 0 ? "*" :
					getpwuid($access{'uid'});
		}
	}
if ($access{'run'}) {
	if ($access{'users'} eq "*") {
		$default_run_user = "root";
		}
	elsif (&can_edit_process($remote_user)) {
		$default_run_user = $remote_user;
		}
	else {
		local @canu = split(/\s+/, $access{'users'});
		if ($canu[0] =~ /^\@(.*)$/) {
			$default_run_user = undef;
			}
		elsif ($can[0] =~ /^(\d+)\-(\d+)$/) {
			$default_run_user = getpwuid($1);
			}
		else {
			$default_run_user = $canu[0];
			}
		}
	}

sub process_info
{
local @plist = &list_processes($_[0]);
return @plist ? %{$plist[0]} : ();
}

# index_links(current)
sub index_links
{
local(%linkname, $l);
print "<b>$text{'index_display'} : </b>\n";
local @links;
foreach $l ("tree", "user", "size", "cpu", ($has_zone ? ("zone") : ()),
	    "search", "run") {
	next if ($l eq "run" && !$access{'run'});
	my $link = ( $l ne $_[0] ? &ui_link("index_".$l.".cgi", $text{"index_$l"}) : "<b>".$text{"index_$l"}."</b>" );
	push(@links, $link);
	}
print &ui_links_row(\@links);
print "<p>\n";
&create_user_config_dirs();
open(INDEX, ">$index_file");
$0 =~ /([^\/]+)$/;
print INDEX "$1?$in\n";
close(INDEX);
}

# cut_string(string, [length])
sub cut_string
{
local $len = $_[1] || $config{'cut_length'};
if ($len && length($_[0]) > $len) {
	return substr($_[0], 0, $len)." ...";
	}
return $_[0];
}

# switch_acl_uid()
sub switch_acl_uid
{
return if ($module_info{'usermin'});	# already switched!
if ($access{'uid'} < 0) {
	local @u = getpwnam($remote_user);
	@u || &error("Failed to find user $remote_user");
	&switch_to_unix_user(\@u);
	}
elsif ($access{'uid'}) {
	local @u = getpwuid($access{'uid'});
	&switch_to_unix_user(\@u);
	}
}

# safe_process_exec(command, uid, gid, handle, [input], [fixtags], [bsmode],
#		    [timeout], [safe])
# Executes the given command as the given user/group and writes all output
# to the given file handle. Finishes when there is no more output or the
# process stops running. Returns the number of bytes read.
sub safe_process_exec
{
if (&is_readonly_mode() && !$_[8]) {
	# Veto command in readonly mode
	return 0;
	}
&webmin_debug_log('CMD', "cmd=$_[0] uid=$_[1] gid=$_[2]")
	if ($gconfig{'debug_what_cmd'});

if ($gconfig{'os_type'} eq 'windows') {
	# For Windows, just run the command and read output
	local $temp = &transname();
	open(TEMP, ">$temp");
	print TEMP $_[4];
	close(TEMP);
	&open_execute_command(OUT, "$_[0] <$temp 2>&1", 1);
	local $fh = $_[3];
	while(<OUT>) {
		if ($_[5]) {
			print $fh &html_escape($_);
			}
		else {
			print $fh $_;
			}
		}
	close(OUT);
	return $got;
	}
else {
	# setup pipes and fork the process
	local $chld = $SIG{'CHLD'};
	$SIG{'CHLD'} = \&safe_exec_reaper;
	pipe(OUTr, OUTw);
	pipe(INr, INw);
	local $pid = fork();
	if (!$pid) {
		#setsid();
		untie(*STDIN);
		untie(*STDOUT);
		untie(*STDERR);
		open(STDIN, "<&INr");
		open(STDOUT, ">&OUTw");
		open(STDERR, ">&OUTw");
		$| = 1;
		close(OUTr); close(INw);

		if ($_[1]) {
			if (defined($_[2])) {
				# switch to given UID and GID
				&switch_to_unix_user(
					[ undef, undef, $_[1], $_[2] ]);
				}
			else {
				# switch to UID and all GIDs
				local @u = getpwuid($_[1]);
				&switch_to_unix_user(\@u);
				}
			}

		# run the command
		delete($ENV{'FOREIGN_MODULE_NAME'});
		delete($ENV{'SCRIPT_NAME'});
		exec("/bin/sh", "-c", $_[0]);
		print "Exec failed : $!\n";
		exit 1;
		}
	close(OUTw); close(INr);

	# Feed input (if any)
	print INw $_[4];
	close(INw);

	# Read and show output
	local $fn = fileno(OUTr);
	local $got = 0;
	local $out = $_[3];
	local $line;
	local $start = time();
	$safe_process_exec_timeout = 0;
	while(1) {
		local ($rmask, $buf);
		vec($rmask, $fn, 1) = 1;
		local $sel = select($rmask, undef, undef, 1);
		if ($sel > 0 && vec($rmask, $fn, 1)) {
			# got something to read.. print it
			sysread(OUTr, $buf, 1024) || last;
			$got += length($buf);
			if ($_[5]) {
				$buf = &html_escape($buf);
				}
			if ($_[6]) {
				# Convert backspaces and returns and escapes
				$line .= $buf;
				while($line =~ s/^([^\n]*\n)//) {
					local $one = $1;
					while($one =~ s/.\010//) { }
					$one =~ s/\033[^m]+m//g;
					print $out $one;
					}
				}
			else {
				print $out $buf;
				}
			}
		elsif ($sel == 0) {
			# nothing to read. maybe the process is done, and a
			# subprocess is hanging things up
			last if (!kill(0, $pid));
			}
		if ($_[7] && time() - $start > $_[7]) {
			# Timeout exceeded - kill the process
			kill(KILL, $pid);
			$safe_process_exec_timeout = 1;
			}
		}
	close(OUTr);
	print $out $line;
	$SIG{'CHLD'} = $chld;
	return $got;
	}
}

# safe_process_exec_logged(..)
# Like safe_process_exec, but also logs the command
sub safe_process_exec_logged
{
&additional_log('exec', undef, $_[0]);
return &safe_process_exec(@_);
}

sub safe_exec_reaper
{
local $xp;
do {    local $oldexit = $?;
	$xp = waitpid(-1, WNOHANG);
	$? = $oldexit if ($? < 0);
	} while($xp > 0);
}

# pty_process_exec(command, [uid, gid])
# Starts the given command in a new pty and returns the pty filehandle and PID
sub pty_process_exec
{
local ($cmd, $uid, $gid) = @_;
if (&is_readonly_mode()) {
	# When in readonly mode, don't run the command
	$cmd = "/bin/true";
	}
&webmin_debug_log('CMD', "cmd=$cmd uid=$uid gid=$gid")
	if ($gconfig{'debug_what_cmd'});

eval "use IO::Pty";
if (!$@) {
	# Use the IO::Pty perl module if installed
	local $ptyfh = new IO::Pty;
	if (!$ptyfh) {
		&error("Failed to create new PTY with IO::Pty");
		}
	local $pid = fork();
	if (!$pid) {
		local $ttyfh = $ptyfh->slave();
		local $tty = $ptyfh->ttyname();
		if (defined(&close_controlling_pty)) {
			&close_controlling_pty();
			}
		setsid();	# create a new session group
		$ptyfh->make_slave_controlling_terminal();

		# Turn off echoing, if we can
		eval "use IO::Stty";
		if (!$@) {
			IO::Stty::stty($ttyfh, 'raw', '-echo');
			}

		close(STDIN); close(STDOUT); close(STDERR);
		untie(*STDIN); untie(*STDOUT); untie(*STDERR);
		if ($_[1]) {
			&switch_to_unix_user([ undef, undef, $_[1], $_[2] ]);
			}

		close($ptyfh);		# Used by other side only
		open(STDIN, "<&".fileno($ttyfh));
		open(STDOUT, ">&".fileno($ttyfh));
		open(STDERR, ">&".fileno($ttyfh));
		close($ttyfh);		# Already dup'd
		exec($cmd);
		print "Exec failed : $!\n";
		exit 1;
		}
	$ptyfh->close_slave();
	return ($ptyfh, $pid);
	}
else {
	# Need to create a PTY using built-in Webmin code
	local ($ptyfh, $ttyfh, $pty, $tty) = &get_new_pty();
	$tty || &error("Failed to create new PTY - try installing the IO::Tty Perl module");
	local $pid = fork();
	if (!$pid) {
		if (defined(&close_controlling_pty)) {
			&close_controlling_pty();
			}

		setsid();	# create a new session group

		if (!$ttyfh) {
			# Needs to be opened, as get_new_pty on linux cannot do
			# this so soon
			$ttyfh = "TTY";
			if ($_[1]) {
				chown($_[1], $_[2], $tty);
				}
			open($ttyfh, "+<$tty") || &error("Failed to open $tty : $!");
			}

		# Turn off echoing, if we can
		eval "use IO::Stty";
		if (!$@) {
			IO::Stty::stty($ttyfh, 'raw', '-echo');
			}

		if (defined(&open_controlling_pty)) {
			&open_controlling_pty($ptyfh, $ttyfh, $pty, $tty);
			}

		close(STDIN); close(STDOUT); close(STDERR);
		untie(*STDIN); untie(*STDOUT); untie(*STDERR);
		#setpgrp(0, $$);
		if ($_[1]) {
			&switch_to_unix_user([ undef, undef, $_[1], $_[2] ]);
			}

		open(STDIN, "<$tty");
		open(STDOUT, ">&$ttyfh");
		open(STDERR, ">&STDOUT");
		close($ptyfh);
		exec($cmd);
		print "Exec failed : $!\n";
		exit 1;
		}
	close($ttyfh);
	return ($ptyfh, $pid);
	}
}

# pty_process_exec_logged(..)
# Like pty_process_exec, but logs the command as well
sub pty_process_exec_logged
{
&additional_log('exec', undef, $_[0]);
return &pty_process_exec(@_);
}

# find_process(name)
# Returns an array of all processes matching some name
sub find_process
{
local $name = $_[0];
local @rv = grep { $_->{'args'} =~ /$name/ } &list_processes();
return wantarray ? @rv : $rv[0];
}

$has_lsof_command = &has_command("lsof");

# find_socket_processes(protocol, port)
# Returns all processes using some port and protocol
sub find_socket_processes
{
local @rv;
open(LSOF, "lsof -i '$_[0]:$_[1]' |");
while(<LSOF>) {
	if (/^(\S+)\s+(\d+)/) {
		push(@rv, $2);
		}
	}
close(LSOF);
return @rv;
}

# find_ip_processes(ip)
# Returns all processes using some IP address
sub find_ip_processes
{
local @rv;
open(LSOF, "lsof -i '\@$_[0]' |");
while(<LSOF>) {
	if (/^(\S+)\s+(\d+)/) {
		push(@rv, $2);
		}
	}
close(LSOF);
return @rv;
}

# find_process_sockets(pid)
# Returns all network connections made by some process
sub find_process_sockets
{
local @rv;
open(LSOF, "lsof -i tcp -i udp -n |");
while(<LSOF>) {
	if (/^(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+).*(TCP|UDP)\s+(.*)/
	    && $2 eq $_[0]) {
		local $n = { 'fd' => $4,
			     'type' => $5,
			     'proto' => $7 };
		local $m = $8;
		if ($m =~ /^([^:\s]+):([^:\s]+)\s+\(listen\)/i) {
			$n->{'lhost'} = $1;
			$n->{'lport'} = $2;
			$n->{'listen'} = 1;
			}
		elsif ($m =~ /^([^:\s]+):([^:\s]+)->([^:\s]+):([^:\s]+)\s+\((\S+)\)/) {
			$n->{'lhost'} = $1;
			$n->{'lport'} = $2;
			$n->{'rhost'} = $3;
			$n->{'rport'} = $4;
			$n->{'state'} = $5;
			}
		elsif ($m =~ /^([^:\s]+):([^:\s]+)/) {
			$n->{'lhost'} = $1;
			$n->{'lport'} = $2;
			}
		push(@rv, $n);
		}
	}
close(LSOF);
return @rv;
}

# find_process_files(pid)
# Returns all files currently held open by some process
sub find_process_files
{
local @rv;
open(LSOF, "lsof -p '$_[0]' |");
while(<LSOF>) {
	if (/^(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+),(\d+)\s+(\d+)\s+(\d+)\s+(.*)/) {
		push(@rv, { 'fd' => lc($4),
			    'type' => lc($5),
			    'device' => [ $6, $7 ],
			    'size' => $8,
			    'inode' => $9,
			    'file' => $10 });
		}
	elsif (/^(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+),(\d+)\s+(\d+)\s+(.*)/) {
		push(@rv, { 'fd' => lc($4),
			    'type' => lc($5),
			    'device' => [ $6, $7 ],
			    'inode' => $8,
			    'file' => $9 });
		}
	}
close(LSOF);
return @rv;
}

# pty_backquote(cmd, uid, gid)
# Like the normal Perl backquote operator, but executes the command in a PTY
sub pty_backquote
{
local $rv;
local ($fh, $pid) = &pty_process_exec(@_);
while(<$fh>) {
	$rv .= $_;
	}
close($fh);
waitpid($pid, WNOHANG);
return $rv;
}

# pty_backquote_logged(cmd, uid, gid)
# Like pty_backquote, but logs the command as well
sub pty_backquote_logged
{
&additional_log('exec', undef, $_[0]);
return &pty_backquote(@_);
}

# get_cpu_info()
# Returns a list containing the 5, 10 and 15 minute load averages, and possibly
# the CPU mhz, model, vendor, cache and count
sub get_cpu_info
{
if (defined(&os_get_cpu_info)) {
	return &os_get_cpu_info();
	}
&clean_language();
local $out = &backquote_command("uptime 2>&1");
&reset_environment();
return $out =~ /average(s)?:\s+([0-9\.]+),?\s+([0-9\.]+),?\s+([0-9\.]+)/i ?
		( $2, $3, $4 ) : ( );
}

# find_subprocesses(&proc, [&plist])
# Returns a list of all processes under the one given
sub find_subprocesses
{
local $proc = $_[0];
local @plist = $_[1] ? @{$_[1]} : &list_processes();
local @sp = grep { $_->{'ppid'} &&
		   $_->{'ppid'} == $proc->{'pid'} } @plist;
local (@rv, $sp);
foreach $sp (@sp) {
	push(@rv, $sp, &find_subprocesses($sp, \@plist));
	}
return @rv;
}

# supported_signals()
# Returns signal names known to Perl for the kill function
sub supported_signals
{
if (defined(&os_supported_signals)) {
	return &os_supported_signals();
	}
else {
	return split(/\s+/, $Config{'sig_name'});
	}
}

# can_view_process(&process)
# Returns 1 if processes belong to this user can be seen
sub can_view_process
{
local ($p) = @_;
return 0 if ($p->{'pid'} == $$ && $config{'hide_self'});
local $user = $p->{'user'};
if ($hide{$user}) {
	return 0;
	}
elsif ($user_processes_only) {
	return &can_edit_process($user);
	}
else {
	return 1;
	}
}

# can_edit_process(user)
# Returns 1 if processes belong to this user can be edited. The 'manage as'
# user will still apply though.
sub can_edit_process
{
local ($user) = @_;
if (!$access{'edit'}) {
	return 0;
	}
elsif ($hide{$user}) {
	return 0;
	}
elsif ($access{'users'} eq '*') {
	return 1;
	}
elsif ($access{'users'} eq 'x') {
	return $user eq $remote_user;
	}
else {
	local @uinfo = getpwnam($user);
	foreach my $u (split(/\s+/, $access{'users'})) {
		if ($u =~ /^\@(.*)$/) {
			# Is he in this group?
			local @ginfo = getgrnam($1);
			return 1 if ($uinfo[3] == $ginfo[2]);
			return 1 if (&indexof($ginfo[0],
					      &other_groups($user)) >= 0);
			}
		elsif ($u =~ /^(\d+)\-(\d+)$/) {
			# Check UID
			return 1 if ($uinfo[2] >= $1 && $uinfo[2] <= $2);
			}
		else {
			return 1 if ($u eq $user);
			}
		}
	return 0;
	}
}

# nice_selector(name, value)
# Returns a menu for selecting a nice level
sub nice_selector
{
local ($name, $value) = @_;
local $l = scalar(@nice_range);
return &ui_select($name, $value,
	[ map { [ $_, $_.($_ == $nice_range[0] ? " ($text{'edit_prihigh'})" :
			  $_ == 0 ? " ($text{'edit_pridef'})" :
			  $_ == $nice_range[$l-1] ? " ($text{'edit_prilow'})" :
						    "") ] } @nice_range ]);
}

# get_kernel_info()
# Returns the system's kernel version, architecture and OS
sub get_kernel_info
{
if (defined(&os_get_kernel_info)) {
	return &os_get_kernel_info();
	}
else {
	my $uname = &has_command("uptrack-uname") || &has_command("uname");
	my $out = &backquote_command("$uname -r 2>/dev/null ; ".
				     "$uname -m 2>/dev/null ; ".
				     "$uname -s 2>/dev/null");
	return split(/\r?\n/, $out);
	}
}

# get_system_uptime()
# Returns uptime in days, minutes and hours
sub get_system_uptime
{
my $out = &backquote_command("LC_ALL='' LANG='' uptime");
if ($out =~ /up\s+(\d+)\s+(day|days),?\s+(\d+):(\d+)/) {
	# up 198 days,  2:06
	return ( $1, $3, $4 );
	}
elsif ($out =~ /up\s+(\d+)\s+(day|days),?\s+(\d+)\s+min/) {
	# up 198 days,  10 mins
	return ( $1, 0, $3 );
	}
elsif ($out =~ /up\s+(\d+):(\d+)/) {
	# up 3:10
	return ( 0, $1, $2 );
	}
elsif ($out =~ /up\s+(\d+)\s+min/) {
	# up 45 mins
	return ( 0, 0, $1 );
	}
else {
	return ( );
	}
}

1;

