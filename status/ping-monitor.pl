# ping-monitor.pl
# Ping some host
# Contains code ripped from Net::Ping by Russell Mosemann

use Socket;

sub get_ping_status
{
local $wait = defined($_[0]->{'wait'}) ? $_[0]->{'wait'} : 5;
local $ip = &to_ipaddress($_[0]->{'host'}) ||
	    &to_ip6address($_[0]->{'host'});
return { 'up' => 0 } if (!$ip);
local $ipv6 = &to_ip6address($_[0]->{'host'}) &&
	      !&to_ipaddress($_[0]->{'host'});
if ($config{'pinger'} || $ipv6) {
	# Call a ping command if configured, or if using IPv6 since the built-
	# in code doesn't support it yet
	local $cmd;
	local $auto_pinger = $config{'pinger'} eq "linux" || !$config{'pinger'};
	if ($auto_pinger && $gconfig{'os_type'} =~ /-linux$/) {
		# Use linux command
		$cmd = ($ipv6 ? "ping6" : "ping")." -c 1 -w $wait";
		}
	elsif ($auto_pinger && $gconfig{'os_type'} eq 'freebsd') {
		# Use FreeBSD command
		$cmd = ($ipv6 ? "ping6" : "ping")." -c 1 -W ".($wait * 1000);
		}
	elsif ($auto_pinger) {
		# Don't know command for this OS
		return { 'up' => - 1 };
		}
	else {
		$cmd = $config{'pinger'};
		}
	local $rv;
	eval {
		local $sig{'ALRM'} = sub { die "timeout" };
		alarm($wait + 1);
		$rv = system("$cmd ".quotemeta($_[0]->{'host'}).
			     " >/dev/null 2>&1 </dev/null");
		alarm(0);
		};
	if ($@) {
		return { 'up' => 0 };
		}
	else {
		return { 'up' => $rv ? 0 : 1 };
		}
	}
else {
	# Use builtin code
	local $rv = &ping_icmp(inet_aton($ip), $wait);
	return { 'up' => $rv ? 1 : 0 };
	}
}

sub show_ping_dialog
{
print &ui_table_row($text{'ping_host'},
	&ui_textbox("host", $_[0]->{'host'}, 50), 3);

print &ui_table_row($text{'ping_wait'},
	&ui_textbox("wait", defined($_[0]->{'wait'}) ? $_[0]->{'wait'} : 5, 6).
	" ".$text{'oldfile_secs'});
}

sub parse_ping_dialog
{
#$config{'ping_cmd'} || &error($text{'ping_econfig'});
&to_ipaddress($in{'host'}) || &to_ip6address($in{'host'}) ||
	&error($text{'ping_ehost'});
$in{'wait'} =~ /^(\d*\.)?\d+$/ || &error($text{'ping_ewait'});
$_[0]->{'host'} = $in{'host'};
$_[0]->{'wait'} = $in{'wait'};
}

sub ping_icmp
{
    my ($ip,                # Packed IP number of the host
        $timeout            # Seconds after which ping times out
        ) = @_;

    my $ICMP_ECHOREPLY = 0; # ICMP packet types
    my $ICMP_ECHO = 8;
    my $icmp_struct = "C2 S3 A";  # Structure of a minimal ICMP packet
    my $subcode = 0;        # No ICMP subcode for ECHO and ECHOREPLY
    my $flags = 0;          # No special flags when opening a socket
    my $port = 0;           # No port with ICMP

    my ($saddr,             # sockaddr_in with port and ip
        $checksum,          # Checksum of ICMP packet
        $msg,               # ICMP packet to send
        $len_msg,           # Length of $msg
        $rbits,             # Read bits, filehandles for reading
        $nfound,            # Number of ready filehandles found
        $finish_time,       # Time ping should be finished
        $done,              # set to 1 when we are done
        $ret,               # Return value
        $recv_msg,          # Received message including IP header
        $from_saddr,        # sockaddr_in of sender
        $from_port,         # Port packet was sent from
        $from_ip,           # Packed IP of sender
        $from_type,         # ICMP type
        $from_subcode,      # ICMP subcode
        $from_chk,          # ICMP packet checksum
        $from_pid,          # ICMP packet id
        $from_seq,          # ICMP packet sequence
        $from_msg,           # ICMP message
	$data,
	$cnt,
	$data_size
        );

    # Construct packet data string
    $data_size = 0;
    for ($cnt = 0; $cnt < $data_size; $cnt++)
    {
        $data .= chr($cnt % 256);
    }

    my $proto_num = (getprotobyname('icmp'))[2];
    socket(PSOCK, PF_INET, SOCK_RAW, $proto_num);

    $ping_seq = ($ping_seq + 1) % 65536; # Increment sequence
    $checksum = 0;                          # No checksum for starters
    $msg = pack($icmp_struct . $data_size, $ICMP_ECHO, $subcode,
                $checksum, $$, $ping_seq, $data);
    $checksum = checksum($msg);
    $msg = pack($icmp_struct . $data_size, $ICMP_ECHO, $subcode,
                $checksum, $$, $ping_seq, $data);
    $len_msg = length($msg);
    $saddr = pack_sockaddr_in($port, $ip);
    send(PSOCK, $msg, $flags, $saddr); # Send the message

    $rbits = "";
    vec($rbits, fileno(PSOCK), 1) = 1;
    $ret = 0;
    $done = 0;
    $finish_time = time() + $timeout;       # Must be done by this time
    while (!$done && $timeout > 0)          # Keep trying if we have time
    {
        $nfound = select($rbits, undef, undef, $timeout); # Wait for packet
        $timeout = $finish_time - time();   # Get remaining time
        if (!defined($nfound))              # Hmm, a strange error
        {
	    # Probably an interrupted system call, so try again
            $ret = undef;
            #$done = 1;
        }
        elsif ($nfound)                     # Got a packet from somewhere
        {
            $recv_msg = "";
            $from_saddr = recv(PSOCK, $recv_msg, 1500, $flags);
	    if ($from_saddr) {
		    ($from_port, $from_ip) = unpack_sockaddr_in($from_saddr);
		    ($from_type, $from_subcode, $from_chk,
		     $from_pid, $from_seq, $from_msg) =
			unpack($icmp_struct . $data_size,
			       substr($recv_msg, length($recv_msg) - $len_msg,
				      $len_msg));
		    if (($from_type == $ICMP_ECHOREPLY) &&
			($from_ip eq $ip) &&
			($from_pid == $$) && # Does the packet check out?
			($from_seq == $ping_seq))
		    {
			$ret = 1;                   # It's a winner
			$done = 1;
		    }
	     } else {
		    # Packet not actually received
		    $ret = undef;
	     }
        }
        else                                # Oops, timed out
        {
            $done = 1;
        }
    }
    close(PSOCK);
    return($ret)
}

# Description:  Do a checksum on the message.  Basically sum all of
# the short words and fold the high order bits into the low order bits.

sub checksum
{
    my ($msg            # The message to checksum
        ) = @_;
    my ($len_msg,       # Length of the message
        $num_short,     # The number of short words in the message
        $short,         # One short word
        $chk            # The checksum
        );

    $len_msg = length($msg);
    $num_short = $len_msg / 2;
    $chk = 0;
    foreach $short (unpack("S$num_short", $msg))
    {
        $chk += $short;
    }                                           # Add the odd byte in
    $chk += unpack("C", substr($msg, $len_msg - 1, 1)) if $len_msg % 2;
    $chk = ($chk >> 16) + ($chk & 0xffff);      # Fold high into low
    return(~(($chk >> 16) + $chk) & 0xffff);    # Again and complement
}


