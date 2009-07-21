# ppp-client-lib.pl
# Common functions for configuring WV-Dial
# XXX what about redhat connect process?
# XXX what about SuSE connect process?

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
$details_file = "$module_config_directory/connect";
$resolv_conf = "/etc/resolv.conf";
$ppp_resolv_conf = "/etc/ppp/resolv.conf";
$save_resolv_conf = $resolv_conf.".save";

# get_config()
# Returns a list of all configuration settings
sub get_config
{
local (@rv, $sect);
local $lnum = 0;
open(FILE, $config{'file'});
while(<FILE>) {
	s/^\s*;.*//;
	s/\r|\n//g;
	if (/^\s*\[(.*)\]/) {
		# Start of a section
		$sect = { 'name' => $1,
			  'index' => scalar(@rv),
			  'line' => $lnum,
			  'eline' => $lnum,
			  'values' => { },
			  'onames' => { } };
		push(@rv, $sect);
		}
	elsif (/^\s*([^=]+\S)\s*=\s*(.*)/ && $sect) {
		# A directive within a section
		$sect->{'values'}->{lc($1)} = $2;
		$sect->{'onames'}->{lc($1)} = $1;
		$sect->{'eline'} = $lnum;
		}
	$lnum++;
	}
close(FILE);
return \@rv;
}

# create_dialer(&dialer)
# Add a dialer to the configuration
sub create_dialer
{
local $lref = &read_file_lines($config{'file'});
push(@$lref, "", &dialer_lines($_[0]));
&flush_file_lines();
}

# update_dialer(&dialer)
sub update_dialer
{
local $lref = &read_file_lines($config{'file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
       &dialer_lines($_[0]));
&flush_file_lines();
}

# delete_dialer(&dialer)
sub delete_dialer
{
local $lref = &read_file_lines($config{'file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1);
if ($_[0]->{'line'} && $lref->[$_[0]->{'line'}-1] eq "") {
	splice(@$lref, $_[0]->{'line'}-1, 1);
	}
&flush_file_lines();
}

# dialer_lines(&dialer)
sub dialer_lines
{
local @rv = "[$_[0]->{'name'}]";
local $k;
foreach $k (keys %{$_[0]->{'values'}}) {
	local $pk = $_[0]->{'onames'}->{$k} || $k;
	push(@rv, $pk." = ".$_[0]->{'values'}->{$k});
	}
return @rv;
}

# device_name(device)
# Returns a human-readable modem device name
sub device_name
{
if ($_[0] =~ /^\/dev\/ttyS(\d+)$/) {
	return &text('device_serial', $1+1);
	}
else {
	return "<tt>$_[0]</tt>";
	}
}

# save_connect_details(ip, pid, section)
sub save_connect_details
{
&open_tempfile(DETAILS, ">$details_file");
&print_tempfile(DETAILS, $_[0],"\n",$_[1],"\n",$_[2],"\n");
&close_tempfile(DETAILS);
}

# get_connect_details()
sub get_connect_details
{
local ($ip, $pid, $sect);
open(DETAILS, $details_file) || return ();
chop($ip = <DETAILS>);
chop($pid = <DETAILS>);
chop($sect = <DETAILS>);
close(DETAILS);
return ($ip, $pid, $sect);
}

# get_wvdial_pid()
# Returns the PID of a running wvdial process
sub get_wvdial_pid
{
local $p;
&foreign_require("proc", "proc-lib.pl");
foreach $p (&proc::list_processes()) {
	if ($p->{'args'} =~ /^\S*wvdial($|\s)/ && $p->{'args'} !~ /\[/) {
		return $p->{'pid'};
		}
	}
return undef;
}

sub dialer_name
{
return $_[0] =~ /^Dialer Defaults$/i ?
		$text{'index_defaults'} :
       $_[0] =~ /^Dialer\s+(.*)$/i ?
		&text('index_dialer', "$1") : $_[0];
}

# ppp_connect(section-name, textmode)
sub ppp_connect
{
# Get this dialer's configuration
local $conf = &get_config();
local ($dialer) = grep { lc($_->{'name'}) eq lc($_[0]) } @$conf;
local ($ddialer) = grep { lc($_->{'name'}) eq 'dialer defaults' } @$conf;
local ($inherits, $parent, $autodns);
if ($inherits = $dialer->{'values'}->{'inherits'}) {
	($parent) = grep { lc($_->{'name'}) eq lc($inherits) } @$conf;
	}
$autodns = $dialer->{'values'}->{'auto dns'} ?
		($dialer->{'values'}->{'auto dns'} =~ /on|yes|1/ ? 1 : 0) :
	   $parent->{'values'}->{'auto dns'} ?
		($parent->{'values'}->{'auto dns'} =~ /on|yes|1/ ? 1 : 0) :
	   $ddialer->{'values'}->{'auto dns'} ?
		($ddialer->{'values'}->{'auto dns'} =~ /on|yes|1/ ? 1 : 0) :
		1;

# Run wvdial, writing to a temp file in the background
local $stime = time();
local $sect = $_[0];
$sect =~ s/^Dialer\s+//;
local $temp = &tempname();
if (!($pid = fork())) {
	untie(*STDIN);
	untie(*STDOUT);
	untie(*STDERR);
	open(STDOUT, ">$temp");
	open(STDERR, ">&STDOUT");
	open(STDIN, "/dev/null");
	exec($config{'wvdial'}, $sect);
	exit(1);
	}
while (!open(TEMP, $temp)) { }
&additional_log("exec", undef, "$config{'wvdial'} $sect");
unlink($temp);

# Read output until success or failure
if ($_[1] == 1) {
	print &text('connect_cmd', "$config{'wvdial'} $sect"),"\n\n";
	}
elsif ($_[1] == 0) {
	print "<b>",&text('connect_cmd',
			     "<tt>$config{'wvdial'} $sect</tt>"),"</b><br>\n";
	print "<pre>";
	}
local ($connected, $failed);
while(1) {
	local $line = &wait_for_line();
	if ($_[1] == 1) {
		print $line;
		}
	elsif ($_[1] == 0) {
		print &html_escape($line);
		}
	if ($line =~ /IP\s+address\s+is\s+(\d+\.\d+\.\d+\.\d+)/i) {
		# Connected OK!
		$connected = $1 eq "0.0.0.0" ? "*" : $1;
		last;
		}
	elsif ($line =~ /starting\s+ppp/i) {
		# Connected in stupid mode
		$connected = "*";
		last;
		}
	elsif (!$line) {
		# Program terminated .. must have failed!
		$failed++;
		last;
		}
	}
print "</pre>\n" if ($_[1] == 0);

# If OK, save the PID for later
if ($connected) {
	if ($_[1] == 0) {
		print "<b>",$connected eq '*' ? $text{'connect_noip'} :
			&text('connect_ip', "<tt>$connected</tt>"),"</b><p>\n";
		}
	elsif ($_[1] == 1) {
		print $connected eq '*' ? $text{'connect_noip'} :
			&text('connect_ip', $connected),"\n";
		}
	&save_connect_details($connected, $pid, $_[0]);
	}
else {
	if ($_[1] == 0) {
		print "<b>$text{'connect_failed'}</b><p>\n";
		}
	elsif ($_[1] == 1) {
		print "$text{'connect_failed'}\n\n";
		}
	}
$config{'dialer'} = $_[0];
&lock_file("$module_config_directory/config");
&write_file("$module_config_directory/config", \%config);
&unlock_file("$module_config_directory/config");

if ($connected && $autodns) {
	# If the resolv.conf file has not been modified, and the PPP
	# resolv.conf has, copy it into place
	while(1) {
		sleep(3);
		local ($ip, $pid, $sect) = &get_connect_details();
		if (!$pid || !kill(0, $pid)) {
			# Connection is down .. DNS will never be updated
			if ($_[1] == 0) {
				print "<b>$text{'connect_dnsdown'}</b><p>\n";
				}
			elsif ($_[1] == 1) {
				print "$text{'connect_dnsdown'}\n\n";
				}
			last;
			}
		$now = time();
		if ($now > $stime+60) {
			# Took too long to update DNS
			if ($_[1] == 0) {
				print "<b>$text{'connect_dnsto'}</b><p>\n";
				}
			elsif ($_[1] == 1) {
				print "$text{'connect_dnsto'}\n\n";
				}
			last;
			}
		local @pst = stat($ppp_resolv_conf);
		local @ost = stat($resolv_conf);
		if ($ost[9] >= $stime) {
			# Something else has update the DNS config ..
			if ($_[1] == 0) {
				print "<b>$text{'connect_dns2'}</b><p>\n";
				}
			elsif ($_[1] == 1) {
				print "$text{'connect_dns2'}\n\n";
				}
			last;
			}
		if ($pst[9] >= $stime) {
			# A PPP DNS config has been created .. use it
			&system_logged("cp $resolv_conf $save_resolv_conf")
				if (!-l $resolv_conf);
			unlink($resolv_conf);
			&system_logged("cp $ppp_resolv_conf $resolv_conf");
			if ($_[1] == 0) {
				print "<b>$text{'connect_dns'}</b><p>\n";
				}
			elsif ($_[1] == 1) {
				print "$text{'connect_dns'}\n\n";
				}
			last;
			}
		}
	}
return $connected;
}

# wait_for_line()
# Reads a line from the temp file, or waits if there is no more to read. Only
# returns undef if the process has died
sub wait_for_line
{
local $line = <TEMP>;
return $line if ($line);
waitpid($pid, 1);
return undef if (!kill(0, $pid));
sleep(1);
return &wait_for_line();
}

# ppp_disconnect(mode, text-mode)
# Shuts down the active PPP connection
sub ppp_disconnect
{
local ($ip, $pid, $sect);
if ($_[0] == 0) {
	($ip, $pid, $sect) = &get_connect_details();
	}
else {
	$pid = &get_wvdial_pid();
	}
if ($pid && &kill_logged('TERM', $pid)) {
	# Tell the user that the connection is now down
	if ($ip) {
		if ($_[1] == 0) {
			print &text('disc_ok1', "<tt>$ip</tt>", &dialer_name($sect)),"<p>\n";
			}
		elsif ($_[1] == 1) {
			print &text('disc_ok1', $ip, &dialer_name($sect)),"\n\n";
			}
		}
	else {
		if ($_[1] == 0) {
			print $text{'disc_ok2'},"<p>\n";
			}
		elsif ($_[1] == 1) {
			print $text{'disc_ok2'},"\n\n";
			}
		}

	# Restore the saved DNS config file, if it hasn't been done
	sleep(3);
	local @ost = stat($resolv_conf);
	if (!-l $resolv_conf && $ost[9] < time()-5 && -r $save_resolv_conf) {
		&system_logged("mv $save_resolv_conf $resolv_conf");
		if ($_[1] == 0) {
			print "$text{'disc_dns'}<p>\n";
			}
		elsif ($_[1] == 1) {
			print "$text{'disc_dns'}\n\n";
			}
		}
	&system_logged("rm -f $ppp_resolv_conf");
	return 1;
	}
else {
	# Wasn't even active .. tell the user
	if ($_[1] == 0) {
		print "$text{'disc_edown'}<p>\n";
		}
	elsif ($_[1] == 1) {
		print "$text{'disc_edown'}\n\n";
		}
	return 0;
	}
}

1;

