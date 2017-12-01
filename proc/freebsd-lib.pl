# freebsd-lib.pl
# Functions for parsing freebsd ps output

use IO::Handle;

sub list_processes
{
local($pcmd, $line, $i, %pidmap, @plist);
$pcmd = @_ ? "-p $_[0]" : "";
open(PS, "ps -axwwww -o pid,ppid,user,vsz,%cpu,time,nice,tty,ruser,rgid,pgid,lstart,lim,command $pcmd |");
for($i=0; $line=<PS>; $i++) {
	chop($line);
	if ($line =~ /ps -axwwww/ || $line =~ /^\s*PID/) { $i--; next; }
	$line =~ /^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+([\d\.]+)\s+(\S+)\s+(-?\d+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(-|\S+\s+\S+\s+\d+\s+\S+\s+\d+|\d+)\s+(\S+)\s+(.*)$/;

	$plist[$i]->{"pid"} = $1;
	$plist[$i]->{"ppid"} = $2;
	$plist[$i]->{"user"} = $3;
	$plist[$i]->{"size"} = "$4 kB";
	$plist[$i]->{"bytes"} = $4*1024;
	$plist[$i]->{"cpu"} = $5;
	$plist[$i]->{"time"} = $6;
	$plist[$i]->{"nice"} = $7;
	$plist[$i]->{"_tty"} = $8;
	$plist[$i]->{"_ruser"} = $9;
	$plist[$i]->{"_rgroup"} = getgrgid($10);
	$plist[$i]->{"_pgid"} = $11;
	$plist[$i]->{"_stime"} = $12;
	$plist[$i]->{"_lim"} = $13 eq "-" ? "Unlimited" : $13;
	$plist[$i]->{"args"} = $14;
	}
close(PS);
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

foreach $ia (keys %text) {
	if ($ia =~ /^freebsd(_\S+)/) {
		$info_arg_map{$1} = $text{$ia};
		}
	}

@nice_range = (-20 .. 20);

$has_fuser_command = 0;

# get_new_pty()
# Returns the filehandles and names for a pty and tty
sub get_new_pty
{
local @ptys;
opendir(DEV, "/dev");
@ptys = map { "/dev/$_" } (grep { /^pty/ } readdir(DEV));
closedir(DEV);
local ($pty, $tty);
foreach $pty (@ptys) {
	open(PTY, "+>$pty") || next;
	local $tty = $pty;
	$tty =~ s/pty/tty/;
	open(TTY, "+>$tty") || next;
	local $old = select(PTY); $| = 1;
	select(TTY); $| = 1; select($old);
	return (*PTY, *TTY, $pty, $tty);
	}
return ();
}

# close_controlling_pty()
# Disconnects this process from it's controlling PTY, if connected
sub close_controlling_pty
{
if (open(DEVTTY, "/dev/tty")) {
	# Special ioctl to disconnect (TIOCNOTTY)
	ioctl(DEVTTY, 536900721, 0);
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
ioctl($ttyfh, 536900705, 0);
}

# get_memory_info()
# Returns a list containing the real mem, free real mem, swap and free swap
# (In kilobytes).
sub get_memory_info
{
my $sysctl = {};
my $sysctl_output = &backquote_command("/sbin/sysctl -a 2>/dev/null");
return ( ) if ($?);
foreach my $line (split(/\n/, $sysctl_output)) {
	if ($line =~ m/^([^:]+):\s+(.+)\s*$/s) {
		$sysctl->{$1} = $2;
		}
	}
return ( ) if (!$sysctl->{"hw.physmem"});
my $mem_inactive = $sysctl->{"vm.stats.vm.v_inactive_count"} *
		   $sysctl->{"hw.pagesize"};
my $mem_cache = $sysctl->{"vm.stats.vm.v_cache_count"} *
		$sysctl->{"hw.pagesize"};
my $mem_free = $sysctl->{"vm.stats.vm.v_free_count"} *
	       $sysctl->{"hw.pagesize"};

my ($swapinfo_output) = &backquote_command("/usr/sbin/swapinfo");
my ($swap_total, $swap_free) = (0, 0);
foreach my $line (split(/\n/, $swapinfo_output)) {
	if ($line =~ /^(\S+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
		$swap_total += $2 * 1024;
		$swap_free += $4 * 1024;
		}
	}

return ( $sysctl->{"hw.physmem"} / 1024,
	 ($mem_inactive + $mem_cache + $mem_free) / 1024,
	 $swap_total,
	 $swap_free );
}

# os_get_cpu_info()
# Returns a list containing the 5, 10 and 15 minute load averages, and the
# CPU mhz, model, vendor, cache and count
sub os_get_cpu_info
{
local $out = &backquote_command("uptime");
local @load;
if ($out =~ /load\s+(average|averages):\s+([0-9\.]+),\s+([0-9\.]+),\s+([0-9\.]+)/) {
	@load = ($2, $3, $4);
	}
else {
	return ( );
	}
$out = &backquote_command("sysctl hw.model hw.ncpu");
if ($out =~ /hw.model:\s+(\S+)\s+(\S.*\S)\s+\@\s+(\S+)/) {
	push(@load, $3, $2, $1, undef);
	}
elsif ($out =~ /hw.model:\s+(\S+)\s+(\S.*\S)/) {
	push(@load, undef, $2, $1, undef);
	}
else {
	return @load;
	}
if ($out =~ /hw.ncpu:\s+(\d+)/) {
	push(@load, $1);
	}
return @load;
}

# get_cpu_io_usage()
# Returns a list containing CPU user, kernel and idle time
# blocks in and out
sub get_cpu_io_usage
{
my $out = &backquote_command("vmstat 0.1 2 2>/dev/null");
if ($?) {
	$out = &backquote_command("vmstat 1 2 2>/dev/null");
	}
return ( ) if ($?);
my @lines = split(/\r?\n/, $out);
my @w = split(/\s+/, $lines[$#lines]);
shift(@w) if ($w[0] eq '');
return ( $w[-3], $w[-2], $w[-1], 0, 0, undef, undef );
}

1;

