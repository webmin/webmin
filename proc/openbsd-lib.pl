# openbsd-lib.pl
# Functions for parsing openbsd ps output

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
	$plist[$i]->{"bytes"} = $4 * 1024;
	$plist[$i]->{"cpu"} = $5;
	$plist[$i]->{"time"} = $6;
	$plist[$i]->{"nice"} = $7;
	$plist[$i]->{"_tty"} = $8;
	$plist[$i]->{"_ruser"} = $9;
	$plist[$i]->{"_rgroup"} = getgrgid($10);
	$plist[$i]->{"_pgid"} = $11;
	$plist[$i]->{"_lstart"} = $12;
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

1;

