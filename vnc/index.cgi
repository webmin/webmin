#!/usr/local/bin/perl
# index.cgi
# Display the vnc applet

BEGIN { push(@INC, ".."); };
use WebminCore;
use Socket;
&init_config();

&ui_print_header(undef, $text{'index_title'}, "", undef, &get_product_name() eq 'webmin', 1);

if ($config{'program'}) {
	if (!&has_command($config{'program'})) {
                &error_exit(&text('index_ecmd', "<tt>$config{'program'}</tt>"));
	}
	
} else {
	# Check if Xvnc is installed
	if (!&has_command("Xvnc")) {
		&error_exit(&text('index_ecmd', "<tt>Xvnc</tt>"));
        }
}

	# Pick a free VNC number
#	for($num=1; $num<1000; $num++) {
#		$port = 5900+$num;
#		last;
		# XXX need to test
#		}

	# Generate a password using vncpasswd
	# XXX

	# Start Xvnc in a background process, and kill it after one client
#	if (!fork()) {
#		close(STDIN);
#		close(STDOUT);
#		local $pid = open(VNC, "Xvnc :$num 2>&1 |");
#		while(<VNC>) {
#			if (/Client\s+(\S+)\s+gone/i) {
#				kill(TERM, $pid);
#				last;
#				}
#			}
#		close(VNC);
#		exit;
#		}

	# Run the specified program, using the selected display
#	$ENV{'DISPLAY'} = "localhost:$num";
#	system("$config{'program'} >/dev/null 2>&1 </dev/null &");

	# XXX what about security?
	# XXX how to ensure exit?	-rfbwait
	# XXX what about window manager? or none?
	# XXX what user to run program as? need option for current user
	# XXX need to generate random password, and pass to java
#	}
#else {
	$addr = $config{'host'} ? $config{'host'} :
		$ENV{'SERVER_NAME'} ? $ENV{'SERVER_NAME'} :
				      &to_ipaddress(&get_system_hostname());
	$SIG{ALRM} = "connect_timeout";
	alarm(10);
	#&open_socket($addr, 5900, STEST, \$err);
	&open_socket("127.0.0.1", 5900, STEST, \$err);
	close(STEST);
	# If a VNC server not listening on localhost and port 5900
	# create an xinetd service for one.
	if ($err) {
	#	system("./createxvnc.sh \"$addr\" -X509Cert /etc/webmin/miniserv.pem -X509Key /etc/webmin/miniserv.pem -noreset -inetd -once -query localhost -geometry $config{'width'}x$config{'height'} -depth 16 -SecurityTypes TLSNone,None");
		system("./createxvnc.sh \"127.0.0.1\" -X509Cert /etc/webmin/miniserv.pem -X509Key /etc/webmin/miniserv.pem -noreset -inetd -once -query localhost -geometry $config{'width'}x$config{'height'} -depth 16 -SecurityTypes TLSNone,None");
		system("systemctl restart xinetd");
	}
	# If a VNC server not listening on specified address and port 5900
	# report an error
	#$err && &error_exit(&text('index_esocket', $addr, 5900));
	# If a VNC server not listening on specified address and port 5900 start one
	#if ($err) {
	# no password but queries XDMCP for login
	#	system("Xvnc -query localhost -geometry $config{'width'}x$config{'height'} -interface $addr -rfbauth /etc/webmin/vnc/vncpass :0 >/dev/null 2>&1 &");
	# password and queries XDMCP for login
	#	system("Xvnc -query localhost -geometry $config{'width'}x$config{'height'} -interface $addr -SecurityTypes TLSNone,None :0 >/dev/null 2>&1 &");
	#}
	$port = $config{'port'};
	$addr = $config{'host'} ? $config{'host'} :
		$ENV{'SERVER_NAME'} ? $ENV{'SERVER_NAME'} :
				      &to_ipaddress(&get_system_hostname());
	$SIG{ALRM} = "connect_timeout";
	alarm(10);
	&open_socket($addr, $port, STEST, \$err);
	close(STEST);
	# Proxy server not listening on the specfied address and port
	# Need to run ./utils/novnc_proxy --vnc $addr:5900 --ssl-only --listen $addr:$port
	if ($err) {
		system("./utils/novnc_proxy --cert /etc/webmin/miniserv.pem --vnc 127.0.0.1:5900 --ssl-only --file-only --listen $addr:$port --web empty >/dev/null 2>&1 &");
	}

print "<center>";
print "<iframe width=$config{'width'} height=$config{'height'} style=\"height: 100vh; border: none\" frameBorder=0 src='vnc.html?host=$addr&port=$port'>";
print "</iframe>";
print "<br>\n";
print "$text{'index_credits'}</center>\n";
print "</center>\n";

&ui_print_footer("/", $text{'index'});

sub connect_timeout
{
}

sub error_exit
{
print "<p>",@_,"<p>\n";
&ui_print_footer("/", $text{'index'});
exit;
}

