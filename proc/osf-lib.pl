# sysv-lib.pl
# Functions for parsing sysv-style ps output

# list_processes([pid]*)
sub list_processes
{
local($line, $dummy, @w, $i, $_, $pcmd, @plist);
foreach (@_) { $pcmd .= " -p $_"; }
if (!$pcmd) { $pcmd = " -e"; }
open(PS, "ps -o user,ruser,group,rgroup,pid,ppid,pgid,pcpu,vsz,nice,etime,time,tty,args $pcmd |");
$dummy = <PS>;
for($i=0; $line=<PS>; $i++) {
	chop($line);
	$line =~ s/^\s+//g;
	@w = split(/\s+/, $line);
	if ($line =~ /ps -o user,ruser/) {
		# Skip ps command
		$i--; next;
		}
	$plist[$i]->{"pid"} = $w[4];
	$plist[$i]->{"ppid"} = $w[5];
	$plist[$i]->{"user"} = $w[0];
	$plist[$i]->{"cpu"} = "$w[7] %";
	if ($w[8] =~ /^([0-9\.]+)K/)
		{ $plist[$i]->{"size"} = "$1 kB"; }
	elsif ($w[8] =~ /^([0-9\.]+)M/)
		{ $plist[$i]->{"size"} = ($1 * 1000)." kB"; }
	$plist[$i]->{"time"} = $w[11];
	$plist[$i]->{"nice"} = $w[9];
	$plist[$i]->{"args"} = $w[13] eq "<defunct>" ? "defunct"
						  : join(' ', @w[13..$#w]);
	$plist[$i]->{"_group"} = $w[2];
	$plist[$i]->{"_ruser"} = $w[1];
	$plist[$i]->{"_rgroup"} = $w[3];
	$plist[$i]->{"_pgid"} = $w[6];
	$plist[$i]->{"_tty"} = $w[12] =~ /\?/ ? $text{'edit_none'} : "/dev/$w[12]";
	}
close(PS);
return @plist;
}

# find_mount_processes(mountpoint)
# Find all processes under some mount point
sub find_mount_processes
{
local($out);
$out = `fuser -c $_[0] 2>/dev/null`;
$out =~ s/^\s+//g; $out =~ s/\s+$//g;
return split(/\s+/, $out);
}

# find_file_processes([file]+)
# Find all processes with some file open
sub find_file_processes
{
local($out, $files);
$files = join(' ', map { quotemeta($_) } map { glob($_) } @_);
$out = &backquote_command("fuser $files 2>/dev/null");
$out =~ s/^\s+//g; $out =~ s/\s+$//g;
return split(/\s+/, $out);
}

# renice_proc(pid, nice)
sub renice_proc
{
return undef if (&is_readonly_mode());
local $out = &backquote_logged("renice $_[1] -p $_[0] 2>&1");
if ($?) { return $out; }
return undef;
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
	if ($ia =~ /^sysv(_\S+)/) {
		$info_arg_map{$1} = $text{$ia};
		}
	}

@nice_range = (-20 .. 19);

$has_fuser_command = 1;

1;

