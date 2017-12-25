# linux-lib.pl
# Functions for parsing linux ps output

use Time::Local;

sub get_ps_version
{
if (!$get_ps_version_cache) {
	local $out = &backquote_command("ps V 2>&1");
	if ($out =~ /version\s+([0-9\.]+)\./ ||
	    $out =~ /\S+\s+([3-9][0-9\.]+)\./) {
		$get_ps_version_cache = $1;
		}
	}
return $get_ps_version_cache;
}

sub list_processes
{
local($pcmd, $line, $i, %pidmap, @plist, $dummy, @w, $_);
local $ver = &get_ps_version();
if ($ver >= 2) {
	# New version of ps, as found in redhat 6
	local $width;
	if ($ver >= 3.2) {
		# Use width format character if allowed
		$width = ":80";
		}
	open(PS, "ps --cols 2048 -eo user$width,ruser$width,group$width,rgroup$width,pid,ppid,pgid,pcpu,vsz,nice,etime,time,stime,tty,args 2>/dev/null |");
	$dummy = <PS>;
	for($i=0; $line=<PS>; $i++) {
		chop($line);
		$line =~ s/^\s+//g;
		eval { @w = split(/\s+/, $line, -1); };
		if ($@) {
			# Hit a split loop
			$i--; next;
			}
		if ($line =~ /ps --cols 500 -eo user/) {
			# Skip process ID 0 or ps command
			$i--; next;
			}
		if (@_ && &indexof($w[4], @_) < 0) {
			# Not interested in this PID
			$i--; next;
			}
		$plist[$i]->{"pid"} = $w[4];
		$plist[$i]->{"ppid"} = $w[5];
		$plist[$i]->{"user"} = $w[0];
		$plist[$i]->{"cpu"} = "$w[7] %";
		$plist[$i]->{"size"} = "$w[8] kB";
		$plist[$i]->{"bytes"} = $w[8]*1024;
		$plist[$i]->{"time"} = $w[11];
		$plist[$i]->{"_stime"} = $w[12];
		$plist[$i]->{"nice"} = $w[9];
		$plist[$i]->{"args"} = @w<15 ? "defunct" : join(' ', @w[14..$#w]);
		$plist[$i]->{"_group"} = $w[2];
		$plist[$i]->{"_ruser"} = $w[1];
		$plist[$i]->{"_rgroup"} = $w[3];
		$plist[$i]->{"_pgid"} = $w[6];
		$plist[$i]->{"_tty"} = $w[13] =~ /\?/ ? $text{'edit_none'} : "/dev/$w[13]";
		}
	close(PS);
	}
else {
	# Old version of ps
	$pcmd = join(' ' , @_);
	open(PS, "ps aulxhwwww $pcmd 2>/dev/nul |");
	for($i=0; $line=<PS>; $i++) {
		chop($line);
		if ($line =~ /ps aulxhwwww/) { $i--; next; }
		if ($line !~ /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([\-\d]+)\s+([\-\d]+)\s+(\d+)\s+(\d+)\s+(\S*)\s+(\S+)[\s<>N]+(\S+)\s+([0-9:]+)\s+(.*)$/) {
			$i--;
			next;
			}
		$pidmap{$3} = $i;
		$plist[$i]->{"pid"} = $3;
		$plist[$i]->{"ppid"} = $4;
		$plist[$i]->{"user"} = getpwuid($2);
		$plist[$i]->{"size"} = "$7 kB";
		$plist[$i]->{"cpu"} = "Unknown";
		$plist[$i]->{"time"} = $12;
		$plist[$i]->{"nice"} = $6;
		$plist[$i]->{"args"} = $13;
		$plist[$i]->{"_pri"} = $5;
		$plist[$i]->{"_tty"} = $11 eq "?" ? $text{'edit_none'} : "/dev/tty$11";
		$plist[$i]->{"_status"} = $stat_map{substr($10, 0, 1)};
		($plist[$i]->{"_wchan"} = $9) =~ s/\s+$//g;
		if (!$plist[$i]->{"_wchan"}) { delete($plist[$i]->{"_wchan"}); }
		if ($plist[$i]->{"args"} =~ /^\((.*)\)/)
			{ $plist[$i]->{"args"} = $1; }
		}
	close(PS);
	open(PS, "ps auxh $pcmd |");
	while($line=<PS>) {
		if ($line =~ /^\s*(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+/ &&
		    defined($pidmap{$2})) {
			$plist[$pidmap{$2}]->{"cpu"} = $3;
			$plist[$pidmap{$2}]->{"_mem"} = "$4 %";
			}
		}
	close(PS);
	}
return @plist;
}

# renice_proc(pid, nice)
sub renice_proc
{
return undef if (&is_readonly_mode());
local $out = &backquote_logged("renice $_[1] -p $_[0] 2>&1");
if ($?) { return $out; }
return undef;
}

# find_mount_processes(mountpoint)
# Find all processes under some mount point
sub find_mount_processes
{
local($out);
&has_command("fuser") || &error("fuser command is not installed");
$out = &backquote_command("fuser -m ".quotemeta($_[0])." 2>/dev/null");
$out =~ s/[^0-9 ]//g;
$out =~ s/^\s+//g; $out =~ s/\s+$//g;
return split(/\s+/, $out);
}

# find_file_processes([file]+)
# Find all processes with some file open
sub find_file_processes
{
local($out, $files);
&has_command("fuser") || &error("fuser command is not installed");
$files = join(' ', map { quotemeta($_) } map { glob($_) } @_);
$out = &backquote_command("fuser $files 2>/dev/null");
$out =~ s/[^0-9 ]//g;
$out =~ s/^\s+//g; $out =~ s/\s+$//g;
return split(/\s+/, $out);
}

# get_new_pty()
# Returns the filehandles and names for a pty and tty
sub get_new_pty
{
if (-r "/dev/ptmx" && -d "/dev/pts" && open(PTMX, "+>/dev/ptmx")) {
	# Can use new-style PTY number allocation device
	local $unl;
	local $ptn;

	# ioctl to unlock the PTY (TIOCSPTLCK)
	$unl = pack("i", 0);
	ioctl(PTMX, 0x40045431, $unl) || &error("Unlock ioctl failed : $!");
	$unl = unpack("i", $unl);

	# ioctl to request a TTY (TIOCGPTN)
	ioctl(PTMX, 0x80045430, $ptn) || &error("PTY ioctl failed : $!");
	$ptn = unpack("i", $ptn);

	local $tty = "/dev/pts/$ptn";
	return (*PTMX, undef, $tty, $tty);
	}
else {
	# Have to search manually through pty files!
	local @ptys;
	local $devstyle;
	if (-d "/dev/pty") {
		opendir(DEV, "/dev/pty");
		@ptys = map { "/dev/pty/$_" } readdir(DEV);
		closedir(DEV);
		$devstyle = 1;
		}
	else {
		opendir(DEV, "/dev");
		@ptys = map { "/dev/$_" } (grep { /^pty/ } readdir(DEV));
		closedir(DEV);
		$devstyle = 0;
		}
	local ($pty, $tty);
	foreach $pty (@ptys) {
		open(PTY, "+>$pty") || next;
		local $tty = $pty;
		if ($devstyle == 0) {
			$tty =~ s/pty/tty/;
			}
		else {
			$tty =~ s/m(\d+)$/s$1/;
			}
		local $old = select(PTY); $| = 1; select($old);
		if ($< == 0) {
			# Don't need to open the TTY file here for root,
			# as it will be opened later after the controlling
			# TTY has been released.
			return (*PTY, undef, $pty, $tty);
			}
		else {
			# Must open now ..
			open(TTY, "+>$tty");
			select(TTY); $| = 1; select($old);
			return (*PTY, *TTY, $pty, $tty);
			}
		}
	return ();
	}
}

# close_controlling_pty()
# Disconnects this process from it's controlling PTY, if connected
sub close_controlling_pty
{
if (open(DEVTTY, "/dev/tty")) {
	# Special ioctl to disconnect (TIOCNOTTY)
	ioctl(DEVTTY, 0x5422, 0);
	close(DEVTTY);
	}
}

# open_controlling_pty(ptyfh, ttyfh, ptyfile, ttyfile)
# Makes a PTY returned from get_new_pty the controlling TTY (/dev/tty) for
# this process.
sub open_controlling_pty
{
local ($ptyfh, $ttyfh, $pty, $tty) = @_;

# Call special ioctl to attach /dev/tty to this new tty (TIOCSCTTY)
ioctl($ttyfh, 0x540e, 0);
}

# get_memory_info()
# Returns a list containing the real mem, free real mem, swap and free swap,
# and possibly cached memory and the burstable limit. All of these are in Kb.
sub get_memory_info
{
local %m;
local $memburst;
if (&running_in_openvz() && open(BEAN, "/proc/user_beancounters")) {
	# If we are running under Virtuozzo, there may be a limit on memory
	# use in force that is less than the real system's memory. Or it may be
	# a higher 'burstable' limit. Use this, unless it is unreasonably
	# high (like 1TB)
	local $pagesize = 1024;
	eval {
		use POSIX;
		$pagesize = POSIX::sysconf(POSIX::_SC_PAGESIZE);
		};
	while(<BEAN>) {
		if (/privvmpages\s+(\d+)\s+(\d+)\s+(\d+)/ &&
                    $3 < 1024*1024*1024*1024) {
			$memburst = $3 * $pagesize / 1024;
			last;
			}
		}
	close(BEAN);
	}
open(MEMINFO, "/proc/meminfo") || return ();
while(<MEMINFO>) {
	if (/^(\S+):\s+(\d+)/) {
		$m{lc($1)} = $2;
		}
	}
close(MEMINFO);
local $memtotal;
if ($memburst && $memburst > $m{'memtotal'}) {
	# Burstable limit is higher than actual RAM
	$memtotal = $m{'memtotal'};
	}
elsif ($memburst && $memburst < $m{'memtotal'}) {
	# Limit is less than actual RAM
	$memtotal = $memburst;
	$memburst = undef;
	}
elsif ($memburst && $memburst == $m{'memtotal'}) {
	# Same as actual RAM
	$memtotal = $memburst;
	$memburst = undef;
	}
elsif (!$memburst) {
	# No burstable limit set, like on a real system
	$memtotal = $m{'memtotal'};
	}
return ( $memtotal,
	 $m{'cached'} > $memtotal ? $m{'memfree'} :
		$m{'memfree'}+$m{'buffers'}+$m{'cached'},
	 $m{'swaptotal'}, $m{'swapfree'},
	 $m{'buffers'} + $m{'cached'},
	 $memburst, );
}

# os_get_cpu_info()
# Returns a list containing the 5, 10 and 15 minute load averages, and the
# CPU mhz, model, vendor, cache and count
sub os_get_cpu_info
{
open(LOAD, "/proc/loadavg") || return ();
local @load = split(/\s+/, <LOAD>);
close(LOAD);
local %c;
open(CPUINFO, "/proc/cpuinfo");
while(<CPUINFO>) {
	if (/^(\S[^:]*\S)\s*:\s*(.*)/) {
		$c{lc($1)} = $2;
		}
	}
close(CPUINFO);
$c{'model name'} =~ s/\d+\s*mhz//i;
if ($c{'cache size'} =~ /^(\d+)\s+KB/i) {
	$c{'cache size'} = $1*1024;
	}
elsif ($c{'cache size'} =~ /^(\d+)\s+MB/i) {
	$c{'cache size'} = $1*1024*1024;
	}
if (!$c{'cpu mhz'} && $c{'model name'}) {
	$c{'bogomips'} =~ s/\..*$//;
	$c{'model name'} .= " @ ".$c{'bogomips'}." bMips";
	}

if ($c{'model name'}) {
	return ( $load[0], $load[1], $load[2],
		 int($c{'cpu mhz'}), $c{'model name'}, $c{'vendor_id'},
		 $c{'cache size'}, $c{'processor'}+1 );
	}
else {
	return ( $load[0], $load[1], $load[2] );
	}
}

$has_trace_command = &has_command("strace");

# open_process_trace(pid, [&syscalls])
# Starts tracing on some process, and returns a trace object
sub open_process_trace
{
local $fh = time().$$;
local $sc;
if (@{$_[1]}) {
	$sc = "-e trace=".join(",", @{$_[1]});
	}
local $tpid = open($fh, "strace -t -p $_[0] $sc 2>&1 |");
$line = <$fh>;
return { 'pid' => $_[0],
	 'tpid' => $tpid,
	 'fh' => $fh };
}

# close_process_trace(&trace)
# Halts tracing on some trace object
sub close_process_trace
{
kill('TERM', $_[0]->{'tpid'}) if ($_[0]->{'tpid'});
close($_[0]->{'fh'});
}

# read_process_trace(&trace)
# Returns an action structure representing one action by traced process, or
# undef if an error occurred
sub read_process_trace
{
local $fh = $_[0]->{'fh'};
local @tm = localtime(time());
while(1) {
	local $line = <$fh>;
	return undef if (!$line);
	if ($line =~ /^(\d+):(\d+):(\d+)\s+([^\(]+)\((.*)\)\s*=\s*(\-?\d+|\?)/) {
		local $tm = timelocal($3, $2, $1, $tm[3], $tm[4], $tm[5]);
		local $action = { 'time' => $tm,
				  'call' => $4,
				  'rv' => $6 eq "?" ? undef : $6 };
		local $args = $5;
		local @args;
		while(1) {
			if ($args =~ /^[ ,]*(\{[^}]*\})(.*)$/) {
				# A structure in { }
				push(@args, $1);
				$args = $2;
				}
			elsif ($args =~ /^[ ,]*"([^"]*)"\.*(.*)$/) {
				# A quoted string
				push(@args, $1);
				$args = $2;
				}
			elsif ($args =~ /^[ ,]*\[([^\]]*)\](.*)$/) {
				# A square-bracket number
				push(@args, $1);
				$args = $2;
				}
			elsif ($args =~ /^[ ,]*\<([^\>]*)\>(.*)$/) {
				# An angle-bracketed string
				push(@args, $1);
				$args = $2;
				}
			elsif ($args =~ /[ ,]*([^, ]+)(.*)$/) {
				# Just a number
				push(@args, $1);
				$args = $2;
				}
			else {
				last;
				}
			}
		if ($args[$#args] eq $action->{'rv'}) {
			pop(@args);	# last arg is same as return value?
			}
		$action->{'args'} = \@args;
		return $action;
		}
	}
}

foreach $ia (keys %text) {
	if ($ia =~ /^linux(_\S+)/) {
		$info_arg_map{$1} = $text{$ia};
		}
	elsif ($ia =~ /^linuxstat_(\S+)/) {
		$stat_map{$1} = $text{$ia};
		}
	}

@nice_range = (-20 .. 20);

$has_fuser_command = 1;

# os_list_scheduling_classes()
# Returns a list of Linux scheduling classes, if supported. Each element is a
# 2-element array ref containing a code and description.
sub os_list_scheduling_classes
{
if (&has_command("ionice")) {
	return ( [ 1, $text{'linux_real'} ],
		 [ 2, $text{'linux_be'} ],
		 [ 3, $text{'linux_idle'} ] );
	}
return ( );
}

# os_list_scheduling_priorities()
# Returns a list of IO priorities, each of which is an array ref containing
# a number and description
sub os_list_scheduling_priorities
{
return ( [ 0, "0 ($text{'edit_prihigh'})" ],
	 [ 1 ], [ 2 ], [ 3 ], [ 4 ], [ 5 ], [ 6 ],
	 [ 7, "7 ($text{'edit_prilow'})" ] );
}

# os_get_scheduling_class(pid)
# Returns the IO scheduling class and priority for a running program
sub os_get_scheduling_class
{
local ($pid) = @_;
local $out = &backquote_command("ionice -p ".quotemeta($pid));
if ($out =~ /^(realtime|best-effort|idle|none):\s+prio\s+(\d+)/) {
	return ($1 eq "realtime" ? 1 : $1 eq "best-effort" ? 2 :
		$1 eq "idle" ? 3 : 0, $2);
	}
return ( );
}

# os_set_scheduling_class(pid, class, priority)
# Sets the ID scheduling class and priority for some process. Returns an error
# message on failure, undef on success.
sub os_set_scheduling_class
{
local ($pid, $class, $prio) = @_;
local $cmd = "ionice -c ".quotemeta($class);
$cmd .= " -n ".quotemeta($prio) if (defined($prio));
$cmd .= " -p ".quotemeta($pid);
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# get_current_cpu_temps()
# Returns a list of hash refs containing CPU temperatures
sub get_current_cpu_temps
{
my @rv;
if (&has_command("sensors")) {
        my $fh = "SENSORS";
        &open_execute_command($fh, "sensors </dev/null 2>/dev/null", 1);
        while(<$fh>) {
                if (/Core\s+(\d+):\s+([\+\-][0-9\.]+)/) {
                        push(@rv, { 'core' => $1,
                                    'temp' => $2 });
                        }
                elsif (/CPU:\s+([\+\-][0-9\.]+)/) {
                        push(@rv, { 'core' => 0,
                                    'temp' => $1 });
                        }
                }
        close($fh);
        }
return @rv;
}

# get_cpu_io_usage()
# Returns a list containing CPU user, kernel, idle, io and VM time, and IO
# blocks in and out
sub get_cpu_io_usage
{
my $out,@lines,@w;
if (&has_command("vmstat")) {
        $out = &backquote_command("vmstat 1 2 2>/dev/null");
        @lines = split(/\r?\n/, $out);
        @w = split(/\s+/, $lines[$#lines]);
        shift(@w) if ($w[0] eq '');
        if ($w[8] =~ /^\d+$/ && $w[9] =~ /^\d+$/) {
            return ( @w[12..16], $w[8], $w[9] );
        }
    } elsif (&has_command("dstat")) {
        $out = &backquote_command("dstat 1 1 2>/dev/null");
        @lines = split(/\r?\n/, $out);
        @w = split(/[\s|]+/, $lines[$#lines]);
        shift(@w) if ($w[0] eq '');
        return( @w[0..4], @w[6..7]);
    }
    return undef;
}

1;

