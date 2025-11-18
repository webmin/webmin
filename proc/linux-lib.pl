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
if ($ver && $ver < 2) {
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
		$plist[$i]->{"bytes"} = $7*1024;
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
else {
	# New version of ps, as found in redhat 6
	local $width;
	if (!$ver || $ver >= 3.2) {
		# Use width format character if allowed
		$width = ":80";
		}
	my $pscmd = "ps --cols 2048 -eo user$width,ruser$width,group$width,rgroup$width,pid,ppid,pgid,pcpu,rss,nice,etime,time,stime,tty,args";
	open(PS, "$pscmd 2>/dev/null |");
	$dummy = <PS>;
	my @now = localtime(time());
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
		eval {
			if (($w[12] =~ /^(\d+):(\d+)$/ ||
			     $w[12] =~ /^(\d+):(\d+):(\d+)$/) &&
			    $3 < 60 && $2 < 60 && $1 < 24) {
				# Started today
				$plist[$i]->{"_stime_unix"} =
					timelocal($3 || 0, $2, $1,
						  $now[3], $now[4], $now[5]);
				}
			elsif ($w[12] =~ /^(\S\S\S)\s*(\d+)$/ && $2 < 32) {
				# Started on some other day
				$plist[$i]->{"_stime_unix"} =
					timelocal(0, 0, 0, $2,
						&month_to_number($1), $now[5]);
				}
			};
		$plist[$i]->{"nice"} = $w[9];
		$plist[$i]->{"args"} = @w<15 ? "defunct" : join(' ', @w[14..$#w]);
		$plist[$i]->{"_group"} = $w[2];
		$plist[$i]->{"_ruser"} = $w[1];
		$plist[$i]->{"_rgroup"} = $w[3];
		$plist[$i]->{"_pgid"} = $w[6];
		$plist[$i]->{"_tty"} = $w[13] =~ /\?/ ? $text{'edit_none'} : "/dev/$w[13]";
		$plist[$i]->{"_pscmd"} = 1 if ($plist[$i]->{"args"} =~ /\Q$pscmd\E/);
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

# linux_openpty()
# Linux-only, pure-Perl openpty(3)-style helper.
# Returns master fh, slave fh, slave path, and ioctl value on success
sub linux_openpty
{

require Fcntl; Fcntl->import(qw(O_RDWR));
require POSIX; POSIX->import(qw(setsid));

# Linux ioctl values
my $TIOCGPTN   = 0x80045430;	# get pty number
my $TIOCSPTLCK = 0x40045431;	# unlock slave
my $TIOCSCTTY  = 0x540E;	# set controlling tty

my ($ptmx, $ttyfh);

# Open PTY master
sysopen($ptmx, "/dev/ptmx", O_RDWR) || return;

# Unlock the slave
my $lock = pack("i", 0);
ioctl($ptmx, $TIOCSPTLCK, $lock) || do {
	close($ptmx);
	return;
	};

# Get slave number
my $buf = pack("i", 0);
ioctl($ptmx, $TIOCGPTN, $buf) || do {
	close($ptmx);
	return;
	};
my $n = unpack("i", $buf);

# Open PTY slave
my $tty = "/dev/pts/$n";
open($ttyfh, "+<", $tty) || do {
	close($ptmx);
	return;
	};

# Return master fh, slave fh, slave path, ioctl value
return ($ptmx, $ttyfh, $tty, $TIOCSCTTY);
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
if (open(DEVTTY, "</dev/tty")) {
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
if (&running_in_openvz() && open(BEAN, "</proc/user_beancounters")) {
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
open(MEMINFO, "</proc/meminfo") || return ();
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
open(LOAD, "</proc/loadavg") || return ();
local @load = split(/\s+/, <LOAD>);
close(LOAD);
local %c;
open(CPUINFO, "</proc/cpuinfo");
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

# Merge in info from /proc/device-tree
if (!$c{'model name'}) {
	$c{'model name'} = &read_file_contents("/proc/device-tree/model");
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

# get_current_cpu_data()
# Returns a list of hash refs containing CPU temperatures
sub get_current_cpu_data
{
my @cpu;
my @fans;
my @fans_all;
my @cpu_thermisters;
my $cpu_broadcoms;
my @sensors;
my $ceil = sub {
	my $x = shift;
	$x //= 0;
	my $i = int($x);
	return $i + ($x > $i);
	};
if (&has_command("sensors")) {
    my ($cpu, $cpu_aux, $cpu_unnamed, $cpu_package, $cpu_broadcom, $cpu_amd);
    my $fh = "SENSORS";

    # Examples https://gist.github.com/547451c9ca376b2d18f9bb8d3748276c
    # &open_execute_command($fh, "cat /tmp/.webmin/sensors </dev/null 2>/dev/null", 1);
    &open_execute_command($fh, "sensors </dev/null 2>/dev/null", 1);

    while (<$fh>) {
	# Buffer output for later use
	push(@sensors, $_);
        # CPU full output must have either voltage or fan data
        my ($cpu_volt) = $_ =~ /(?|in\d+\s*:\s+([\+\-0-9\.]+)\s+V|cpu\s+core\s+voltage\s*:\s+([0-9\.]+)\s+V)/i;
	# CPU fans should be always labeled as 'cpu fan' or 'cpu_fan' or 'cpufan'
	# and/or 'cpu fan 1', 'cpu_fan1', 'cpufan1', 'cpu_fan 2', 'cpu_fan2',
	# 'cpufan2' etc.
        my ($cpu_fan_num, $cpu_fan_rpm) =
		$_ =~ /(?|^\s*cpu[_ ]?fan(?:[_ ]?(\d+))?\s*:\s*(\d+)\s*rpm)/i;
	$cpu_fan_num //= 1 if (defined($cpu_fan_rpm));
        $cpu++ if ($cpu_volt || $cpu_fan_num);

        # First just store fan data for any device if any
        push(@fans,
                {  'fan' => &trim($cpu_fan_num),
                   'rpm' => $cpu_fan_rpm
                }
        ),
	push(@fans_all, 
		{
		   $cpu_fan_num => @fans
		}
	) if ($cpu_fan_num);

        # AMD CPU Thermisters #1714
        if ($cpu && /thermistor\s+[\d]+:\s+[+-]([\d]+)/i) {
            my $temp = $ceil->($1);
            push(@cpu_thermisters,
                 {  'core' => scalar(@cpu_thermisters) + 1,
                    'temp' => $temp
                 }) if ($temp);
            }

        # CPU package
        ($cpu_package) = $_ =~ /(?|(package\s+id\s+[\d]+)|(coretemp-[a-z]+-[\d]+))/i
          if (!$cpu_package);

        # Standard outputs
        if ($cpu_package) {

            # Common CPU multi
            if (/Core\s+(\d+):\s+([\+\-][0-9\.]+)/) {

                # Prioritize package core temperature
                # data over motherboard but keep fans
                @cpu = (), $cpu_aux++
                    if ($cpu_aux & 1 && grep { $_->{'core'} eq $1 } @cpu);
                push(@cpu,
                     {  'core' => $1,
                        'temp' => $ceil->($2)
                     });
                }

            # Common CPU single
            elsif (/CPU:\s+([\+\-][0-9\.]+)/) {
                push(@cpu,
                     {  'core' => 0,
                        'temp' => $ceil->($1)
                     });
                }
            }

        # Non-standard outputs
        else {

            # Auxiliary CPU temperature and fans were already captured
            next if ($cpu_aux && !$cpu_unnamed);

            # CPU types
            ($cpu_broadcom) = $_ =~ /cpu_thermal-virtual-[\d]+/i if (!$cpu_broadcom);
            ($cpu_amd)      = $_ =~ /\w[\d]{2}temp-pci/i         if (!$cpu_amd);

            # Full CPU output #1253
            if ($cpu) {

                # Standard output
                if (/temp(\d+):\s+([\+][0-9\.]+).*?[Cc]\s+.*?[=+].*?\)/) {
                    push(@cpu,
                         {  'core' => (int($1) - 1),
                            'temp' => $ceil->($2)
                         });
                    }

                # Approx from motherboard sensor as last resort
                elsif (/(cputin|cpu\s+temp)\s*:\s+([\+][0-9\.]+).*?[Cc]\s+.*?[=+].*?\)/i ||
                       /(cpu\s+temperature)\s*:\s+([\+][0-9\.]+).*?[Cc]/i) {
                    push(@cpu,
                         {  'core' => 0,
                            'temp' => $ceil->($2)
                         });
                    }
                }

            # Broadcom
            elsif ($cpu_broadcom) {
                if (/temp(\d+):\s+([\+\-][0-9\.]+)/) {
                    push(@cpu,
                         {  'core' => int($1),
                            'temp' => $ceil->($2)
                         });
                    $cpu_broadcoms++;
                    }
                elsif (/cpu\s+temp(.*?):\s+([\+\-][0-9\.]+)/i) {
                    $cpu_unnamed++;
                    push(@cpu,
                         {  'core' => $cpu_unnamed,
                            'temp' => $ceil->($2)
                         });
                    $cpu_broadcoms++;
                    }
                }

            # AMD
            elsif ($cpu_amd) {

                # Like in sourceforge.net/p/webadmin/discussion/600155/thread/a9d8fe19c0
                if (/Tdie:\s+([\+\-][0-9\.]+)/) {
                    push(@cpu,
                         {  'core' => 0,
                            'temp' => $ceil->($1),
                         });
                    }

                # Like in #1481 #1484
                elsif (/temp(\d+):\s+([\+\-][0-9\.]+).*?[Cc]\s+.*?[=+].*?\)/) {
                    push(@cpu,
                         {  'core' => ($ceil->($1) - 1),
                            'temp' => $ceil->($2),
                         });
                    }
		
		# Like in #2140
                elsif (/Tctl:\s*([\+\-][0-9\.]+)/) {
                    push(@cpu,
                         {  'core' => 0,
                            'temp' => $ceil->($1),
                         });
                    }
                }

            # New line represents another device
            if (/^\s*$/) {

                # Do we have CPU data already, if so add fans
                # output, if any, and continue checking for
                # priority package id core temperature data
                $cpu_aux++ if (@cpu);
                next if ($cpu_aux);

                # Reset cpu and fans and continue
                @cpu  = ();
                @fans = ();

                $cpu          = 0;
                $cpu_broadcom = 0;
                $cpu_amd      = 0;
                }
            }
        }
    close($fh);
    }
@cpu = @cpu_thermisters
    if (!@cpu && @cpu_thermisters);

# Fix to remove cannot detect 
# package temperatures (178)
if (@cpu) {
	@cpu = grep {$_->{'temp'} != 178} @cpu;
	}

# Fix output when FAN data
# precedes CPU data (/t/125292)
if (!@fans && @cpu && @fans_all &&
    $cpu_broadcoms && @cpu == @fans_all) {
	foreach my $fan (@fans_all) {
		foreach my $cpu (@cpu) {
			push(@fans, $fan->{$cpu->{'core'}})
				if ($fan->{$cpu->{'core'}});
			}
		}
	}

# Fall back logic for CPU temperature and fans spread over multiple
# devices like Raspberry Pi #2517 and #2539 #2545
if (@cpu || !@fans) {
	# - Look for least two ISA voltage rails anywhere
	# - See a CPU temp under cpu_thermal
	# - Optionally grab a fan RPM under *fan-isa-*
	my $can_fallback =
		(!@cpu && (grep { /^\s*cpu_thermal/i } @sensors)) ||
		(@cpu && !@fans && (grep { /fan-isa-\d+/i } @sensors));
	return (\@cpu, \@fans) if (!$can_fallback);
	my ($chip, $bus); 	# isa|pci|platform|virtual
	my $isa_volt;
	my ($cpu_temp, $fan_rpm);
	for (@sensors) {
		# Chip header
		if (/^([A-Za-z0-9_+\-]+)-(isa|pci|platform|virtual)-[\w:]+\s*$/) {
			$chip = lc $1;
			$bus  = lc $2;
			next;
			}

		# Count real voltage rails
		if (defined $bus && $bus eq 'isa' &&
		    /\bin\d+\s*:\s*([+\-]?[0-9]+(?:\.[0-9]+)?)\s*V\b/i) {
			$isa_volt++;
			next;
			}

		# CPU temperature
		if (defined $chip && $chip =~ /^cpu_thermal/i &&
		    /\b(?:CPU(?:\s*Temp)?|temp\d+)\s*:\s*([+\-]?[0-9]+(?:\.[0-9]+)?)\s*°?C\b/i) {
			$cpu_temp //= $1;
			next;
			}

		# Fan RPM
		if (defined $chip && $chip =~ /fan$/i &&
		    /\b(?:cpu[_ ]?fan(?:\s*\d+)?|fan\d+)\s*:\s*(\d+)\s*rpm\b/i) {
			my $rpm = $1 + 0;
			$fan_rpm = $rpm if (!$fan_rpm || $rpm > $fan_rpm);
			next;
			}
		}

	# Update only what's missing
	push(@cpu, { 'core' => 1, 'temp' => $ceil->($cpu_temp) })
		if (!@cpu && defined $cpu_temp && $isa_volt >= 2);
	push(@fans, { 'fan' => 1, 'rpm' => $fan_rpm })
		if (!@fans && defined $fan_rpm);
	}

return (\@cpu, \@fans);
}

# get_cpu_io_usage()
# Returns a list of "us", "sy", "id", "wa", "st", "bi", "bo" that match `vmstat`
# output by using /proc with much lower overhead
sub get_cpu_io_usage
{
# Read CPU counters from /proc/stat, the first "cpu" line
my $read_cpu = sub {
	open(my $fh, '<', '/proc/stat') or return;
	my $line = <$fh>;
	close($fh);
	return unless defined $line && $line =~ /^cpu\s+/;
	my @v = split /\s+/, $line; shift @v;
	push @v, (0) x (8-@v) if @v < 8;
	return @v[0..7];
};

# Read pgpgin/pgpgout from /proc/vmstat (in KB). Note, that all modern kernels,
# /proc/vmstat pgpgin/pgpgout are KiB (scale=1); not as *pages*, so no need to
# convert deltas
my $read_io = sub {
	open(my $fh, '<', '/proc/vmstat') or return (undef, undef);
	my ($in, $out);
	while (my $l = <$fh>) {
		$in  = $1 if !defined $in  && $l =~ /^pgpgin\s+(\d+)/;
		$out = $1 if !defined $out && $l =~ /^pgpgout\s+(\d+)/;
		last if defined $in && defined $out;
		}
	close($fh);
	return ($in, $out);   	   # KB on kernels 2.6.18+; no conversion needed
};

# Sample A
my @cb = $read_cpu->() or return;
my ($pgin_b, $pgout_b) = $read_io->();

# Sleep half a second
select(undef, undef, undef, 0.5);

# Sample B
my @ca = $read_cpu->() or return;
my ($pgin_a, $pgout_a) = $read_io->();

# CPU percentages as in vmstat
my @d = map { $ca[$_] - $cb[$_] } 0..7;
for (@d) { $_ = 0 if $_ < 0 }
my $tot = 0; $tot += $_ for @d[0..7];
return if !$tot;

# Calculate percentages
my $us = int( (($d[0] + $d[1]) / $tot) * 100 );          # user+nice
my $sy = int( (($d[2] + $d[5] + $d[6]) / $tot) * 100 );  # system+irq+softirq
my $id = int( ( $d[3] / $tot ) * 100 );                  # idle
my $wa = int( ( $d[4] / $tot ) * 100 );                  # iowait
my $st = int( ( $d[7] / $tot ) * 100 );                  # steal

# Calculate bi/bo in KiB/s over half a second
my ($bi, $bo) = (0, 0);
$bi = int( (($pgin_a  // 0) - ($pgin_b  // 0)) / 0.5 );
$bo = int( (($pgout_a // 0) - ($pgout_b // 0)) / 0.5 );
return ($us, $sy, $id, $wa, $st, $bi, $bo);
}

# has_disk_stats()
# Returns 1 if disk I/O stats are available
sub has_disk_stats
{
return 1;
}

# has_network_stats()
# Returns 1 if network I/O stats are available
sub has_network_stats
{
return 1;
}

1;

