# hpux-lib.pl
# Functions for parsing hpux ps output

sub list_processes
{
local($line, $i, $pcmd, $_, $tty, @plist);

foreach (@_) { $pcmd .= "-p $_"; }
if (!$pcmd) { $pcmd = "-e"; }

open(PS, "ps -fl $pcmd |");

for($i=0; $line=<PS>; $i++) {
        chop($line);
        if ($line =~ /ps -fl/ || $line =~ /COMD/) { $i--; next; }
        $line =~ /^\s*(\d+)\s+(\S*)\s+(\S*)\s+(\d+)\s+(\d+)\s+(\d+)\s+([\-\d]+)\s+([\-\d]+)\s+(\S*)\s+(\d+)\s+(\S*)\s+(.*)$/;
        $plist[$i]->{"pid"} = $4;
        $plist[$i]->{"ppid"} = $5;
        $plist[$i]->{"user"} = $3;
        $plist[$i]->{"size"} = "$10 Pg";
        $plist[$i]->{"cpu"} = "0.$6 %";
        $plist[$i]->{"time"} = substr($12,17,6);
        $plist[$i]->{"nice"} = $8;
        $plist[$i]->{"args"} = substr($12,23,60);
        $plist[$i]->{"_pri"} = $7;
        $tty = substr($12,8,8);
        $plist[$i]->{"_tty"} =  $tty eq "?       " ? $text{'edit_none'} : "/dev/$tty";
        $plist[$i]->{"_status"} = $stat_map{$2};
        $plist[$i]->{"_wchan"} = $11;
	local $rest = $12;
	if ($rest =~ /^(\d+:\d+:\d+)/) {
		$plist[$i]->{"_stime"} = $1;
		}
	elsif ($rest =~ /^([A-Za-z]+\s+\d+)/) {
		$plist[$i]->{"_stime"} = $1;
		}
        }
close(PS);
return @plist;
}

# renice_proc(pid, nice)
sub renice_proc
{
return undef if (&is_readonly_mode());
local($out, $nice);
$nice = $_[1] - 20;
local $out = &backquote_logged("renice -n $nice -p $_[0] 2>&1");
if ($?) { return $out; }
return undef;
}

# find_mount_processes(mountpoint)
# Find all processes under some mount point
sub find_mount_processes
{
local($out);
$out = `fuser -c $_[0]`;
$out =~ s/[^0-9 ]//g;
$out =~ s/^\s+//g; $out =~ s/\s+$//g;
return split(/\s+/, $out);
}

# find_file_processes([file]+)
# Find all processes with some file open
sub find_file_processes
{
local($out, $files);
$files = join(' ', map { quotemeta($_) } map { glob($_) } @_);
$out = &backquote_command("fuser -f $files");
$out =~ s/[^0-9 ]//g;
$out =~ s/^\s+//g; $out =~ s/\s+$//g;
return split(/\s+/, $out);
}

# get_new_pty()
# Returns the filehandles and names for a pty and tty
sub get_new_pty
{
opendir(DEV, "/dev");
local @ptys = map { "/dev/$_" } (grep { /^pty/ } readdir(DEV));
closedir(DEV);
local ($pty, $tty);
foreach $pty (@ptys) {
	open(PTY, "+>$pty") || next;
	local $tty = $pty; $tty =~ s/pty/tty/;
	open(TTY, "+>$tty") || next;
	local $old = select(PTY); $| = 1;
	select(TTY); $| = 1; select($old);
	return (*PTY, *TTY, $pty, $tty);
	}
return ();
}

foreach $ia (keys %text) {
	if ($ia =~ /^hpux(_\S+)/) {
		$info_arg_map{$1} = $text{$ia};
		}
	elsif ($ia =~ /^hpuxstat_(\S+)/) {
		$stat_map{$1} = $text{$ia};
		}
	}

@nice_range = (0 .. 39);

$has_fuser_command = 1;

1;

