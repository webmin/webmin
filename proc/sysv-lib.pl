# sysv-lib.pl
# Functions for parsing sysv-style ps output

$has_stime = $gconfig{'os_type'} eq 'solaris';
$has_task = $gconfig{'os_type'} eq 'solaris' && $gconfig{'os_version'} >= 10;
$has_zone = $gconfig{'os_type'} eq 'solaris' && $gconfig{'os_version'} >= 10;

# list_processes([pid]*)
sub list_processes
{
local($line, $dummy, @w, $i, $_, $pcmd, @plist);
foreach (@_) { $pcmd .= " -p $_"; }
if (!$pcmd) { $pcmd = " -e"; }
$ENV{'COLUMNS'} = 10000;	# needed on AIX
local @cols = ( "user","ruser","group","rgroup","pid","ppid","pgid","pcpu","vsz",
		"nice","etime","time",
		($has_stime ? ("stime") : ( )),
		($has_task ? ("taskid") : ( )),
		($has_zone ? ("zone") : ( )),
		"tty","args" );
open(PS, "ps -o ".join(",", @cols)." $pcmd |");
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
	$plist[$i]->{"size"} = "$w[8] kB";
	local $ofs = 0;
	if ($has_stime) {
		$plist[$i]->{"_stime"} = $w[12+$ofs];
		$plist[$i]->{"_stime"} =~ s/_/ /g;
		$ofs++;
		}
	if ($has_task) {
		$plist[$i]->{"_task"} = $w[12+$ofs];
		$ofs++;
		}
	if ($has_zone) {
		$plist[$i]->{"_zone"} = $w[12+$ofs];
		$ofs++;
		}
	$plist[$i]->{"time"} = $w[11];
	$plist[$i]->{"nice"} = $w[9] =~ /\d+/ ? $w[9]-20 : $w[9];
	$plist[$i]->{"args"} = @w<14+$ofs ? "defunct"
					  : join(' ', @w[13+$ofs..$#w]);
	$plist[$i]->{"_group"} = $w[2];
	$plist[$i]->{"_ruser"} = $w[1];
	$plist[$i]->{"_rgroup"} = $w[3];
	$plist[$i]->{"_pgid"} = $w[6];
	$plist[$i]->{"_tty"} = $w[12+$ofs] =~ /\?/ ? $text{'edit_none'}
					           : "/dev/$w[12+$ofs]";
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
$files = join(' ', @_);
$out = `fuser $files 2>/dev/null`;
$out =~ s/^\s+//g; $out =~ s/\s+$//g;
return split(/\s+/, $out);
}

# renice_proc(pid, nice)
sub renice_proc
{
return undef if (&is_readonly_mode());
$out = `renice $_[1] -p $_[0] 2>&1`;
if ($?) { return $out; }
return undef;
}

# get_new_pty()
# Returns the filehandles and names for a pty and tty
sub get_new_pty
{
if (!-e "/dev/ptyp0") {
	# Must use IO::Pty :(
	&error("IO::Pty Perl module is not installed");
	}
else {
	# Need to search through pty files
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
}

$has_trace_command = $gconfig{'os_type'} eq 'solaris' &&
		     &has_command("truss");

# open_process_trace(pid, [&syscalls])
# Starts tracing on some process, and returns a trace object
sub open_process_trace
{
local $fh = time().$$;
local $sc;
if (@{$_[1]}) {
	$sc = "-t ".join(",", @{$_[1]});
	}
local $tpid = open($fh, "truss $sc -i -p $_[0] 2>&1 |");
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
	if ($line =~ /^([^\(]+)\((.*)\)(\s*=\s*(\-?\d+)|\s+(Err\S+))?/) {
		local $action = { 'time' => time(),
				  'call' => $1,
				  'rv' => $4 ne "" ? $4 : $5 };
		local $args = $2;
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
		$action->{'args'} = \@args;
		return $action;
		}
	}
}

# get_memory_info()
# Returns a list containing the real mem, free real mem, swap and free swap
sub get_memory_info
{
return ( ) if (!&has_command("top"));
local @rv;
open(TOP, "top 2>&1 |");
while(<TOP>) {
	if (/Memory:\s+(\S+)\s+real,\s+(\S+)\s+free,\s+(\S+)\s+swap\s+in\s+use,\s+(\S+)\s+swap\s+free/) {
		local ($real, $free, $swapused, $swapfree) = ($1, $2, $3, $4);
		@rv = ( &fix_suffix($real),
			&fix_suffix($free),
			&fix_suffix($swapused) + &fix_suffix($swapfree),
			&fix_suffix($swapfree) );
		}
	}
close(TOP);
return @rv;
}

sub fix_suffix
{
if ($_[0] =~ /^(\d+)K/i) {
	return $1;
	}
elsif ($_[0] =~ /^(\d+)M/i) {
	return $1*1024;
	}
elsif ($_[0] =~ /^(\d+)G/i) {
	return $1*1024*1024;
	}
else {
	return int($1);
	}
}

# os_get_cpu_info()
# Returns a list containing the 5, 10 and 15 minute load averages
sub os_get_cpu_info
{
local $out = `uptime 2>&1`;
if ($out =~ /load average:\s+(\S+),\s+(\S+),\s+(\S+)/) {
	return ($1, $2, $3);
	}
else {
	return ( );
	}
}

foreach $ia (keys %text) {
	if ($ia =~ /^sysv(_\S+)/) {
		$info_arg_map{$1} = $text{$ia};
		}
	}
delete($info_arg_map{'_stime'}) if (!$has_stime);

@nice_range = (-20 .. 19);

$has_fuser_command = 1;

1;

