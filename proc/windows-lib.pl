# windows-lib.pl
# Functions for parsing Windows process.exe command output

sub list_processes
{
local($pcmd, $line, $i, %pidmap, @plist);
open(PS, "process -t -c |");
while(<PS>) {
	s/\r|\n//g;
	if (/^\s*(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)/) {
		local $proc = { 'pid' => $2,
				'ppid' => 0,
				'time' => $6,
				'args' => $1,
				'_threads' => $3,
				'nice' => $4,
				'cpu' => "$5 %",
				'size' => "Unknown" };
		$pidmap{$proc->{'pid'}} = $proc;
		push(@plist, $proc);
		}
	}
close(PS);
open(PS, "process -v |");
while(<PS>) {
	local $proc;
	s/\r|\n//g;
	if (/^\s*(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.*)/ &&
	    ($proc = $pidmap{$2})) {
		local $user = $6;
		$user = "Unknown" if ($user =~ /^Error/);
		$proc->{'user'} = $user;
		}
	}
close(PS);
if (@_) {
	# Limit to PIDs
	local %want = map { $_, 1 } @_;
	@plist = grep { $want{$_->{'pid'}} } @plist;
	}
return @plist;
}

# renice_proc(pid, nice)
sub renice_proc
{
return undef if (&is_readonly_mode());
local $out = &backquote_logged("process -p $_[0] $_[1] 2>&1");
if ($?) { return $out; }
return undef;
}

%info_arg_map=(	"_threads", $text{'windows_threads'} );

@nice_range = ( 0 .. 20 );

$has_fuser_command = 0;

sub os_supported_signals
{
return ("KILL", "TERM", "STOP", "CONT");
}

1;

