#!/usr/local/bin/perl
# index.cgi
# Display the telnet applet

BEGIN { push(@INC, ".."); };
use WebminCore;
use Socket;

&init_config();
$theme_no_table = 1 if ($config{'sizemode'} == 1);
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

if ($ENV{'HTTPS'} eq 'ON' && !$config{'mode'}) {
	print "<center><font color=#ff0000>$text{'index_warn'}",
	      "</font></center><br>\n";
	}

# Work out SSH server port
$default_ssh_port = 22;
if (&foreign_installed("sshd")) {
	&foreign_require("sshd");
	$conf = &sshd::get_sshd_config();
	@ports = map { $_->{'values'}->[0] } &sshd::find("Port", $conf);
	$default_ssh_port = $ports[0] if (@ports && $ports[0]);
	}

# Work out real host and port
$addr = $config{'host'} || $ENV{'SERVER_NAME'} ||
	&to_ipaddress(&get_system_hostname());
$port = $config{'port'} ? $config{'port'} :
	$config{'mode'} ? $default_ssh_port : 23;

if ($config{'no_test'}) {
	# Just assume that the telnet server is running
	$rv = 1;
	}
else {
	# Check if the telnet server is running
	$ip = &to_ipaddress($addr) || &to_ip6address($addr);
	if ($ip) {
		$SIG{ALRM} = "connect_timeout";
		alarm(10);
		&open_socket($ip, $port, STEST, \$err);
		close(STEST);
		$rv = !$err;
		}
	}
if (!$rv) {
	# Not running! Show an error
	if ($ip) {
		print "<p>",&text(
			$config{'mode'} ? 'index_esocket2' : 'index_esocket',
			$addr, $port),"<p>\n";
		}
	else {
		print "<p>",&text('index_elookup', $addr),"<p>\n";
		}
	}
else {
	# If the host is not local, start up a proxy sub-process
	if ($config{'proxy'}) {
		# Allocate a free port
		&get_miniserv_config(\%miniserv);
		$proxyport = $miniserv{'port'} + 1;
		$err = &allocate_socket(MAIN, \$proxyport);
		&error($err) if ($err);

		# Connect to the destination
		&open_socket($addr, $port, CONN);

		# Forward traffic in sub-process
		if (!($pid = fork())) {
			# Accept the connection (for up to 60 secs)
			$rmask = undef;
			vec($rmask, fileno(MAIN), 1) = 1;
			$sel = select($rmask, undef, undef, 60);
			$sel >= 0 || die "no connection after 60 seconds";
			$acptaddr = accept(SOCK, MAIN);
			$acptaddr || die "accept failed?!";
			close(MAIN);

			untie(*STDIN);
			untie(*STDOUT);
			#untie(*STDERR);
			close(STDIN);
			close(STDOUT);
			#close(STDERR);

			# Forward traffic in and out
			select(CONN); $| = 1;
			select(SOCK); $| = 1;
			while(1) {
				$rmask = undef;
				vec($rmask, fileno(SOCK), 1) = 1;
				vec($rmask, fileno(CONN), 1) = 1;
				$sel = select($rmask, undef, undef, undef);

				if (vec($rmask, fileno(SOCK), 1)) {
					# Read from applet, send to server
					$got = sysread(SOCK, $buf, 1024);
					$got > 0 || last;
					syswrite(CONN, $buf, $got);
					}

				if (vec($rmask, fileno(CONN), 1)) {
					# Read from applet, send to server
					$got = sysread(CONN, $buf, 1024);
					$got > 0 || last;
					syswrite(SOCK, $buf, $got);
					}
				}
			print STDERR "exited read loop\n";
			exit(0);
			}

		$SIG{'CHLD'} = \&child_reaper;
		close(CONN);
		close(MAIN);

		# Force applet to connect to proxy
		$config{'port'} = $proxyport;
		delete($config{'host'});
		}

	# Output the applet
	print "<center>\n";
	if ($config{'detach'}) {
		$w = 100; $h = 50;
		}
	elsif ($config{'sizemode'} == 2 &&
	    $config{'size'} =~ /^(\d+)\s*x\s*(\d+)$/) {
		$w = $1; $h = $2;
		}
	elsif ($config{'sizemode'} == 1) {
		$w = "100%"; $h = "80%";
		}
	else {
		$w = 590; $h = 360;
		}
	$jar = "jta26.jar";
	print "<applet archive=\"$jar\" code=de.mud.jta.Applet ",
	      "width=$w height=$h>\n";
	printf "<param name=config value=%s>\n",
		$config{'mode'} ? "ssh.conf" : "telnet.conf";
	if ($config{'port'}) {
		print "<param name=Socket.port value=$config{'port'}>\n";
		}
	if ($config{'host'}) {
		print "<param name=Socket.host value=$config{'host'}>\n";
		}
	else {
		print "<param name=Socket.host value=$ENV{'SERVER_NAME'}>\n";
		}
	if ($config{'script'}) {
		print "<param name=Script.script value='$config{'script'}'>\n";
		}
	if ($config{'sizemode'}) {
		print "<param name=Terminal.resize value='screen'>\n";
		}
	if ($config{'fontsize'}) {
		print "<param name=Terminal.fontSize value='$config{'fontsize'}'>\n";
		}
	if ($config{'detach'}) {
		print "<param name=Applet.detach value='true'>\n";
		print "<param name=Applet.detach.stopText value='Disconnect'>\n";
		}
	print "$text{'index_nojava'} <p>\n";
	print "</applet><br>\n";

	print &text('index_credits',
		    "http://javassh.org/space/start"),"<br>\n";
	if ($config{'mode'}) {
		print &text('index_sshcredits',
			    "http://www.cryptix.org/"),"<br>\n";
		}
	print "</center>\n";
	}

&ui_print_footer("/", $text{'index'});

sub connect_timeout
{
}

# allocate_socket(handle, &port)
sub allocate_socket
{
local ($fh, $port) = @_;
local $proto = getprotobyname('tcp');
if (!socket($fh, PF_INET, SOCK_STREAM, $proto)) {
	return "socket failed : $!";
	}
setsockopt($fh, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
while(1) {
	$$port++;
	last if (bind($fh, sockaddr_in($$port, INADDR_ANY)));
	}
listen($fh, SOMAXCONN);
return undef;
}

sub child_reaper
{
local $xp;
do {
	$xp = waitpid(-1, WNOHANG);
	} while($xp > 0);
}


