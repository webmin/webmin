# macos-lib.pl
# Functions for parsing macos server ps output

sub list_processes
{
local($pcmd, $line, $i, %pidmap, @plist);
if (@_) {
	open(PS, "ps xlwwwwp $_[0] |");
	}
else {
	open(PS, "ps axlwwww |");
	}
for($i=0; $line=<PS>; $i++) {
	chop($line);
	if ($line =~ /ps (axlwwww|xlwwwwp)/ ||
	    $line =~ /^\s*UID\s+PID/) { $i--; next; }
	if ($line =~ /^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(...)\s+(\S+)\s+(\d+:\d+)\s+(.*)/) {
		# Old MacOS
		if ($3 <= 0) { $i--; next; }
		$plist[$i]->{"pid"} = $3;
		$plist[$i]->{"ppid"} = $4;
		$plist[$i]->{"size"} = $8;
		$plist[$i]->{"bytes"} = $8 * 1024;
		$plist[$i]->{"time"} = $13;
		$plist[$i]->{"nice"} = $6;
		$plist[$i]->{"_tty"} = $12 eq '?' ? $text{'edit_none'} : "/dev/tty$12";
		$plist[$i]->{"args"} = $14;
		$pidmap{$3} = $plist[$i];
		}
	elsif ($line =~ /^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(...)\s+(\S+)\s+(\d+:\S+)\s+(.*)/) {
		# New MacOS
		if ($2 <= 0) { $i--; next; }
		$plist[$i]->{"pid"} = $2;
		$plist[$i]->{"ppid"} = $3;
		$plist[$i]->{"size"} = $7;
		$plist[$i]->{"bytes"} = $7 * 1024;
		$plist[$i]->{"time"} = $12;
		$plist[$i]->{"nice"} = $6;
		$plist[$i]->{"_tty"} = $11 eq '??' ? $text{'edit_none'} : "/dev/tty$11";
		$plist[$i]->{"args"} = $13;
		$pidmap{$2} = $plist[$i];
		}
	else {
		# Unknown line?
		$i--;
		}
	}
close(PS);
open(PS, "ps auxwwww $_[0] |");
while($line = <PS>) {
	chop($line);
	$line =~ /^(\S+)\s+(\d+)\s+(\S+)\s+(\S+)/ || next;
	if ($pidmap{$2}) {
		$pidmap{$2}->{"user"} = $1;
		$pidmap{$2}->{"cpu"} = "$3 %";
		}
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

%info_arg_map=(	"_tty", $text{'macos_tty'} );

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

# get_memory_info()
# Returns a list containing the real mem, free real mem, swap and free swap,
# and possibly cached memory and the burstable limit. All of these are in Kb.
sub get_memory_info
{
my @rv;

# Get total memory
my $out = &backquote_command("hostinfo 2>/dev/null");
if ($out =~ /Primary\s+memory\s+available:\s+([0-9\.]+)\s+g/i) {
	$rv[0] = $1 * 1024 * 1024;
	}
else {
	my $out = &backquote_command("sysctl -a hw.physmem 2>/dev/null");
	if ($out =~ /:\s*(\d+)/) {
		$rv[0] = $1 / 1024;
		}
	}

# Get memory usage
$out = &backquote_command("vm_stat 2>/dev/null");
my %stat;
foreach my $l (split(/\r?\n/, $out)) {
	if ($l =~ /^(.*):\s*(\d+)/) {
		$stat{lc($1)} = $2;
		}
	}
my $usage = ($stat{'pages active'} + $stat{'pages wired down'}) * 4;
if ($usage > $rv[0]) {
	$usage = $rv[0];
	}
$rv[1] = $rv[0] - $usage;

# Get swap usage
$out = &backquote_command("sysctl -a vm.swapusage 2>/dev/null");
if ($out =~ /total\s*=\s*([0-9\.]+)([KMGT]).*free\s*=\s*([0-9\.]+)([KMGT])/) {
	$rv[2] = $1*($2 eq "K" ? 1 :
		     $2 eq "M" ? 1024 :
		     $2 eq "G" ? 1024*1024 :
		     $2 eq "T" ? 1024*1024*1024 : 0);
	$rv[3] = $3*($4 eq "K" ? 1 :
		     $4 eq "M" ? 1024 :
		     $4 eq "G" ? 1024*1024 :
		     $4 eq "T" ? 1024*1024*1024 : 0);
	}

return @rv;
}

# os_get_cpu_info()
# Returns a list containing the 5, 10 and 15 minute load averages, and the
# CPU mhz, model, vendor, cache and count
sub os_get_cpu_info
{
&clean_language();
my $out = &backquote_command("uptime 2>&1");
&reset_environment();
my @rv = $out =~ /average(s)?:\s+([0-9\.]+),?\s+([0-9\.]+),?\s+([0-9\.]+)/i ?
	 ( $2, $3, $4 ) : ( undef, undef, undef );

$out = &backquote_command("sysctl -a machdep.cpu.brand_string");
if ($out =~ /:\s*(\S.*)/) {
	$rv[4] = $1;
	if ($rv[4] =~ s/\s*\@\s*([0-9\.]+)(GHz|MHz)//i) {
		$rv[3] = $1 * ($2 eq "GHz" ? 1000 : 1);
		}
	}

$out = &backquote_command("sysctl -a machdep.cpu.vendor");
if ($out =~ /:\s*(\S.*)/) {
	$rv[5] = $1;
	}

$out = &backquote_command("sysctl -a machdep.cpu.cache.size");
if ($out =~ /:\s*(\d+)/) {
	$rv[6] = $1 * 1024;
	}

$out = &backquote_command("sysctl -a machdep.cpu.core_count");
if ($out =~ /:\s*(\d+)/) {
	$rv[7] = $1;
	}

return @rv;
}

1;

