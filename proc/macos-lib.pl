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
	if ($line =~ /ps axlwwww/ || $line =~ /^\s*UID\s+PID/) { $i--; next; }
	if ($line =~ /^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(...)\s+(\S+)\s+(\d+:\d+)\s+(.*)/) {
		if ($3 <= 0) { $i--; next; }
		$plist[$i]->{"pid"} = $3;
		$plist[$i]->{"ppid"} = $4;
		$plist[$i]->{"size"} = $8;
		$plist[$i]->{"time"} = $13;
		$plist[$i]->{"nice"} = $6;
		$plist[$i]->{"_tty"} = $12 eq '?' ? $text{'edit_none'} : "/dev/tty$12";
		$plist[$i]->{"args"} = $14;
		$pidmap{$3} = $plist[$i];
		}
	elsif ($line =~ /^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(...)\s+(\S+)\s+(\d+:\S+)\s+(.*)/) {
		if ($2 <= 0) { $i--; next; }
		$plist[$i]->{"pid"} = $2;
		$plist[$i]->{"ppid"} = $3;
		$plist[$i]->{"size"} = $7;
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

1;

