# sentry-lib.pl
# Functions for configuring portsentry, hostsentry and logcheck

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# get_portsentry_config()
# Parses the portsentry.conf file
sub get_portsentry_config
{
return &get_config($config{'portsentry_config'});
}

# get_hostsentry_config()
# Parses the hostsentry.conf file
sub get_hostsentry_config
{
return &get_config($config{'hostsentry_config'});
}

# get_logcheck_config()
# Parses the logcheck.sh program script
sub get_logcheck_config
{
return &get_config($config{'logcheck'});
}

# lock_config_files(&config)
sub lock_config_files
{
foreach $f (&unique(map { $_->{'file'} } @{$_[0]})) {
	&lock_file($f);
	}
}

# unlock_config_files(&config)
sub unlock_config_files
{
foreach $f (&unique(map { $_->{'file'} } @{$_[0]})) {
	&unlock_file($f);
	}
}

# get_config(file)
sub get_config
{
local (@rv, $lnum = 0);
open(CONF, $_[0]);
local @lines = <CONF>;
close(CONF);
foreach (@lines) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^([^=\s]+)\s*=\s*"(.*)"/ || /^([^=\s]+)\s*=\s*(\S+)/) {
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'file' => $_[0],
			    'line' => $lnum });
		}
	elsif (/^\.\s+(\S+)/) {
		# Included file!
		local $inc = &get_config("$1");
		push(@rv, @$inc);
		}
	$lnum++;
	}
return \@rv;
}

# save_config(&conf, name, value)
sub save_config
{
local $old = &find($_[1], $_[0]);
local $lref = &read_file_lines($old ? $old->{'file'} : $_[0]->[0]->{'file'});
local $nl = "$_[1]=\"$_[2]\"";
if ($old) {
	$lref->[$old->{'line'}] = $nl;
	}
else {
	push(@$lref, $nl);
	}
}

# find(name, &config)
sub find
{
foreach $c (@{$_[1]}) {
	if (lc($c->{'name'}) eq lc($_[0])) {
		return $c;
		}
	}
return undef;
}

# find_value(name, &config, subs)
sub find_value
{
local $rv = &find($_[0], $_[1]);
return undef if (!defined($rv));
local $str = $rv->{'value'};
if ($_[2]) {
	local %donevar;
	while($str =~ /\$([A-z0-9\_]+)/ && !$donevar{$1}) {
		$donevar{$1}++;
		local $val = &find_value($1, $_[1]);
		$str =~ s/\$([A-z0-9\_]+)/$val/;
		}
	}
return $str;
}

# get_portsentry_pids()
sub get_portsentry_pids
{
if ($config{'portsentry_pid'}) {
	# Get from pid file
	local $pid;
	if (open(PID, $config{'portsentry_pid'}) && chop($pid = <PID>) &&
	    kill(0, $pid)) {
		close(PID);
		return ( $pid );
		}
	else {
		return ();
		}
	}
else {
	# Just see if the process is running
	return grep { $_ != $$ } &find_byname("portsentry");
	}
}

# portsentry_start_cmd()
sub portsentry_start_cmd
{
return $config{'portsentry_start'} ? $config{'portsentry_start'} :
	"$config{'portsentry'} -$config{'portsentry_tmode'} && $config{'portsentry'} -$config{'portsentry_umode'}";
}

# stop_portsentry()
# Stops portsentry
sub stop_portsentry
{
if ($config{'portsentry_stop'}) {
	local $out = &backquote_logged("($config{'portsentry_stop'}) 2>&1 </dev/null");
	return "<tt>$out</tt>" if ($out =~ /error|failed/i);
	}
else {
	local @pids = &get_portsentry_pids();
	if (@pids) {
		&kill_logged("TERM", @pids) ||
			return &text('portsentry_ekill', join(" ", @pids), $!);
		}
	else {
		return $text{'portsentry_estopped'};
		}
	}
return undef;
}

# start_portsentry()
# Starts portsentry, and returns an error message on failure, or undef 
sub start_portsentry
{
local $cmd = &portsentry_start_cmd();
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return "<tt>$out</tt>" if ($out =~ /failed|error/i);
return undef;
}

# list_hostsentry_modules($conf)
# Returns a list of all hostsentry python modules
sub list_hostsentry_modules
{
local $dir = &find_value("MODULE_PATH", $_[0]);
opendir(DIR, $dir);
local @rv = map { /^(\S+)\.py$/; $1 }
	        grep { /\.py$/ && !/^moduleExample/ } readdir(DIR);
closedir(DIR);
return @rv;
}

# hostsentry_start_cmd()
sub hostsentry_start_cmd
{
return $config{'hostsentry_start'} ? $config{'hostsentry_start'}
				   : "python $config{'hostsentry'}";
}

# start_hostsentry()
# Start hostsentry, or return an error message
sub start_hostsentry
{
local $cmd = &hostsentry_start_cmd();
local $temp = &tempname();
&system_logged("$cmd >$temp 2>&1 </dev/null");
local $out;
open(TEMP, $temp);
while(<TEMP>) { $out .= $_; }
close(TEMP);
unlink($temp);
return "<tt>$out</tt>" if ($out =~ /failed|error/i);
return undef;
}

# stop_hostsentry()
# Stop hostsentry, or return an error message
sub stop_hostsentry
{
if ($config{'hostsentry_stop'}) {
        local $out = &backquote_logged("($config{'hostsentry_stop'}) 2>&1 </dev/null")
;
        return "<tt>$out</tt>" if ($out =~ /error|failed/i);
        }
else {
        local $pid = &get_hostsentry_pid();
        if ($pid) {
                &kill_logged("TERM", $pid) ||
                        return &text('hostsentry_ekill', $pid, $!);
                }
        else {
                return $text{'hostsentry_estopped'};
                }
        }
return undef;
}

# get_hostsentry_pid()
sub get_hostsentry_pid
{
local ($pid) = grep { $_ != $$ } &find_byname("python.*hostsentry");
return $pid;
}

# get_hostsentry_dir()
sub get_hostsentry_dir
{
$config{'hostsentry_config'} =~ /^(\S+)\//;
return $1;
}

1;

