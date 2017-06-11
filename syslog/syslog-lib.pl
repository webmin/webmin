# syslog-lib.pl
# Functions for the syslog module

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();

# get_config([file])
# Parses the syslog configuration file into an array ref of hash refs, one
# for each log file or destination
sub get_config
{
local ($cfile) = @_;
$cfile ||= $config{'syslog_conf'};
local $lnum = 0;
local ($line, $cont, @rv);
local $tag = { 'tag' => '*',
	       'index' => 0,
	       'line' => 0 };
push(@rv, $tag);
&open_readfile(CONF, $cfile);
local @lines = <CONF>;
close(CONF);
foreach my $line (@lines) {
	local $slnum = $lnum;
	$line =~ s/\r|\n//g;
	if ($line =~ /\\$/) {
		# continuation .. get the next lines
		$line =~ s/\\$//;
		while($cont = <CONF>) {
			$lnum++;
			$cont =~ s/^[#\s]+//;
			$cont =~ s/\r|\n//g;
			$line .= $cont;
			last if ($line !~ s/\\$//);
			}
		}
	if ($line =~ /^\$IncludeConfig\s+(\S+)/) {
		# rsyslog include statement .. follow the money
		foreach my $icfile (glob($1)) {
			my $ic = &get_config($icfile);
			if ($ic) {
				foreach my $c (@$ic) {
					$c->{'index'} += scalar(@rv);
					}
				push(@rv, @$ic);
				}
			}
		}
	elsif ($line =~ /^\$(\S+)\s*(\S*)/) {
		# rsyslog special directive - ignored for now
		}
	elsif ($line =~ /^if\s+/) {
		# rsyslog if statement .. ignored too
		}
	elsif ($line =~ /^(#*)\s*([^#\s]+\.\S+)\s+(\S+)$/ ||
	       $line =~ /^(#*)\s*([^#\s]+\.\S+)\s+(\|.*)$/) {
		# Regular log destination
		local $act = $3;
		local $log = { 'active' => !$1,
			       'sel' => [ split(/;/, $2) ],
			       'cfile' => $cfile,
			       'line' => $slnum,
			       'eline' => $lnum };
		if ($act =~ /^\-(\/\S+)$/) {
			$log->{'file'} = $1;
			$log->{'sync'} = 0;
			}
		elsif ($act =~ /^\|(.*)$/) {
			$log->{'pipe'} = $1;
			}
		elsif ($act =~ /^(\/\S+)$/) {
			$log->{'file'} = $1;
			$log->{'sync'} = 1;
			}
		elsif ($act =~ /^\@\@(\S+)$/) {
			$log->{'socket'} = $1;
			}
		elsif ($act =~ /^\@(\S+)$/) {
			$log->{'host'} = $1;
			}
		elsif ($act eq '*') {
			$log->{'all'} = 1;
			}
		else {
			$log->{'users'} = [ split(/,/, $act) ];
			}
		$log->{'index'} = scalar(@rv);
		$log->{'section'} = $tag;
		$tag->{'eline'} = $lnum;
		if ($log->{'file'} =~ s/^(\/\S+);(\S+)$/$1/ ||
                    $log->{'pipe'} =~ s/^(\/\S+);(\S+)$/$1/) {
			# rsyslog file format
			$log->{'format'} = $2;
			}
		push(@rv, $log);
		}
	elsif ($line =~ /^(#?)!(\S+)$/) {
		# Start of tagged section, as seen on BSD
		push(@rv, { 'tag' => $2,
			    'index' => scalar(@rv),
			    'cfile' => $cfile,
			    'line' => $lnum,
			    'eline' => $lnum });
		$tag = $rv[@rv-1];
		}
	$lnum++;
	}
return \@rv;
}

# create_log(&log)
sub create_log
{
local $lref = &read_file_lines($config{'syslog_conf'});
if ($config{'tags'}) {
	splice(@$lref, $_[0]->{'section'}->{'eline'}+1, 0, &log_line($_[0]));
	}
else {
	push(@$lref, &log_line($_[0]));
	}
&flush_file_lines();
}

# update_log(&old, &log)
sub update_log
{
local $lref = &read_file_lines($_[0]->{'cfile'} || $config{'syslog_conf'});
if ($config{'tags'} && $_[0]->{'section'} ne $_[1]->{'section'}) {
	if ($_[0]->{'section'}->{'line'} < $_[1]->{'section'}->{'line'}) {
		splice(@$lref, $_[1]->{'section'}->{'eline'}+1, 0,
		       &log_line($_[1]));
		splice(@$lref, $_[0]->{'line'},
		       $_[0]->{'eline'} - $_[0]->{'line'} + 1);
		}
	else {
		splice(@$lref, $_[0]->{'line'},
		       $_[0]->{'eline'} - $_[0]->{'line'} + 1);
		splice(@$lref, $_[1]->{'section'}->{'eline'}+1, 0,
		       &log_line($_[1]));
		}
	}
else {
	splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
	       &log_line($_[1]));
	}
&flush_file_lines();
}

# delete_log(&log)
sub delete_log
{
local $lref = &read_file_lines($_[0]->{'cfile'} || $config{'syslog_conf'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1);
&flush_file_lines();
}

sub log_line
{
local $d;
if ($_[0]->{'file'}) {
	$d = ($_[0]->{'sync'} || !$config{'sync'} ? "" : "-").$_[0]->{'file'};
	}
elsif ($_[0]->{'pipe'}) {
	$d = '|'.$_[0]->{'pipe'};
	}
elsif ($_[0]->{'host'}) {
	$d = '@'.$_[0]->{'host'};
	}
elsif ($_[0]->{'users'}) {
	$d = join(",", @{$_[0]->{'users'}});
	}
elsif ($_[0]->{'socket'}) {
	$d = '@@'.$_[0]->{'socket'};
	}
else {
	$d = '*';
	}
if ($_[0]->{'format'}) {
	# Add rsyslog format
	$d .= ";".$_[0]->{'format'};
	}
return ($_[0]->{'active'} ? "" : "#").join(";", @{$_[0]->{'sel'}})."\t".$d;
}

# list_priorities()
# Returns a list of all priorities
sub list_priorities
{
return ( 'debug', 'info', 'notice', 'warning',
	 'err', 'crit', 'alert', 'emerg' );
}

# can_edit_log(&log|file)
# Returns 1 if some log can be viewed/edited, 0 if not
sub can_edit_log
{
return 1 if (!$access{'logs'});
local @files = split(/\s+/, $access{'logs'});
local $lf;
if (ref($_[0])) {
	$lf = $_[0]->{'file'} || $_[0]->{'pipe'} || $_[0]->{'host'} ||
	      $_[0]->{'socket'} || $_[0]->{'cmd'} ||
	      ($_[0]->{'all'} ? "*" : "users");
	}
else {
	$lf = $_[0];
	}
foreach $f (@files) {
	return 1 if ($f eq $lf || &is_under_directory($f, $lf));
	}
return 0;
}

sub needs_m4
{
local $oldslash = $/;
$/ = undef;
&open_readfile(CONF, $config{'syslog_conf'});
local $conf1 = <CONF>;
close(CONF);
&open_execute_command(CONF, "$config{'m4_path'} $config{'syslog_conf'}", 1, 1);
local $conf2 = <CONF>;
close(CONF);
$/ = $oldslash;
return $conf1 ne $conf2;
}

# get_syslog_pid(pid)
# Returns the syslog PID file
sub get_syslog_pid
{
local $pid;
if ($config{'pid_file'}) {
	foreach my $pfile (map { glob($_) } split(/\s+/, $config{'pid_file'})) {
		my $poss = &check_pid_file($pfile);
		if ($poss) {
			$pid = $poss;
			last;
			}
		}
	}
else {
	($pid) = &find_byname("syslogd");
	($pid) = &find_byname("rsyslogd") if (!$pid);
	}
return $pid;
}

# restart_syslog()
# Stop and re-start the syslog server. Returns an error message on failure.
sub restart_syslog
{
if ($config{'restart_cmd'}) {
	&system_logged("$config{'restart_cmd'} >/dev/null 2>/dev/null </dev/null");
	}
else {
	local $pid = &get_syslog_pid();
	$pid && &kill_logged('TERM', $pid) ||
		return &text('restart_ekill', $pid, $!);
	sleep(2);
	if ($config{'start_cmd'}) {
		&system_logged("$config{'start_cmd'} >/dev/null 2>/dev/null </dev/null");
		}
	else {
		&system_logged("cd / ; $config{'syslogd'} >/dev/null 2>/dev/null </dev/null &");
		}
	}
return undef;
}

# signal_syslog()
# Tell the syslog server to re-open it's log files
sub signal_syslog
{
if ($config{'signal_cmd'}) {
	&system_logged("$config{'signal_cmd'} >/dev/null 2>/dev/null </dev/null");
	}
else {
	# Use HUP signal
	local $pid = &get_syslog_pid();
	if ($pid) {
		&kill_logged('HUP', $pid);
		}
	}
}

# all_log_files(file)
# Given a filename, returns all rotated versions, ordered by oldest first
sub all_log_files
{
$_[0] =~ /^(.*)\/([^\/]+)$/;
local $dir = $1;
local $base = $2;
local ($f, @rv);
opendir(DIR, &translate_filename($dir));
foreach $f (readdir(DIR)) {
	local $trans = &translate_filename("$dir/$f");
	if ($f =~ /^\Q$base\E/ && -f $trans && $f !~ /\.offset$/) {
		push(@rv, "$dir/$f");
		$mtime{"$dir/$f"} = [ stat($trans) ];
		}
	}
closedir(DIR);
return sort { $mtime{$a}->[9] <=> $mtime{$b}->[9] } @rv;
}

# get_other_module_logs([module])
# Returns a list of logs supplied by other modules
sub get_other_module_logs
{
local ($mod) = @_;
local @rv;
local %done;
foreach my $minfo (&get_all_module_infos()) {
	next if ($mod && $minfo->{'dir'} ne $mod);
	next if (!$minfo->{'syslog'});
	next if (!&foreign_installed($minfo->{'dir'}));
	local $mdir = &module_root_directory($minfo->{'dir'});
	next if (!-r "$mdir/syslog_logs.pl");
	&foreign_require($minfo->{'dir'}, "syslog_logs.pl");
	local $j = 0;
	foreach my $l (&foreign_call($minfo->{'dir'}, "syslog_getlogs")) {
		local $fc = $l->{'file'} || $l->{'cmd'};
		next if ($done{$fc}++);
		$l->{'minfo'} = $minfo;
		$l->{'mod'} = $minfo->{'dir'};
		$l->{'mindex'} = $j++;
		push(@rv, $l);
		}
	}
@rv = sort { $a->{'minfo'}->{'desc'} cmp $b->{'minfo'}->{'desc'} } @rv;
local $i = 0;
foreach my $l (@rv) {
	$l->{'index'} = $i++;
	}
return @rv;
}

# catter_command(file)
# Given a file that may be compressed, returns the command to output it in
# plain text, or undef if impossible
sub catter_command
{
local ($l) = @_;
local $q = quotemeta($l);
if ($l =~ /\.gz$/i) {
	return &has_command("gunzip") ? "gunzip -c $q" : undef;
	}
elsif ($l =~ /\.Z$/i) {
	return &has_command("uncompress") ? "uncompress -c $q" : undef;
	}
elsif ($l =~ /\.bz2$/i) {
	return &has_command("bunzip2") ? "bunzip2 -c $q" : undef;
	}
elsif ($l =~ /\.xz$/i) {
	return &has_command("xz") ? "xz -d -c $q" : undef;
	}
else {
	return "cat $q";
	}
}

# extra_log_files()
# Returns a list of extra log files available to the current Webmin user. No filtering
# based on allowed directory is done though!
sub extra_log_files
{
local @rv;
foreach my $fd (split(/\t+/, $config{'extras'}), split(/\t+/, $access{'extras'})) {
	if ($fd =~ /^"(\S+)"\s+"(\S.*)"$/) {
		push(@rv, { 'file' => $1, 'desc' => $2 });
		}
	elsif ($fd =~ /^"(\S+)"$/) {
		push(@rv, { 'file' => $1 });
		}
	elsif ($fd =~ /^(\S+)\s+(\S.*)$/) {
		push(@rv, { 'file' => $1, 'desc' => $2 });
		}
	else {
		push(@rv, { 'file' => $fd });
		}
	}
return @rv;
}

1;

