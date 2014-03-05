#!/usr/local/bin/perl
# index.cgi
# Display the vnc applet

BEGIN { push(@INC, ".."); };
use WebminCore;
use Socket;
&init_config();

&ui_print_header(undef, $text{'index_title'}, "", undef, &get_product_name() eq 'webmin', 1);

if ($config{'program'}) {
	# Check if Xvnc is installed
	if (!&has_command("Xvnc")) {
		&error_exit(&text('index_ecmd', "<tt>Xvnc</tt>"));
		}

	# Pick a free VNC number
	for($num=1; $num<1000; $num++) {
		$port = 5900+$num;
		last;
		# XXX need to test
		}

	# Generate a password using vncpasswd
	# XXX

	# Start Xvnc in a background process, and kill it after one client
	if (!fork()) {
		close(STDIN);
		close(STDOUT);
		local $pid = open(VNC, "Xvnc :$num 2>&1 |");
		while(<VNC>) {
			if (/Client\s+(\S+)\s+gone/i) {
				kill(TERM, $pid);
				last;
				}
			}
		close(VNC);
		exit;
		}

	# Run the specified program, using the selected display
	$ENV{'DISPLAY'} = "localhost:$num";
	system("$config{'program'} >/dev/null 2>&1 </dev/null &");

	# XXX what about security?
	# XXX how to ensure exit?	-rfbwait
	# XXX what about window manager? or none?
	# XXX what user to run program as? need option for current user
	# XXX need to generate random password, and pass to java
	}
else {
	$addr = $config{'host'} ? $config{'host'} :
		$ENV{'SERVER_NAME'} ? $ENV{'SERVER_NAME'} :
				      &to_ipaddress(&get_system_hostname());
	$SIG{ALRM} = "connect_timeout";
	alarm(10);
	&open_socket($addr, $config{'port'}, STEST, \$err);
	close(STEST);
	$err && &error_exit(&text('index_esocket', $addr, $config{'port'}));
	$port = $config{'port'};
	}

if ($ENV{'HTTPS'} eq 'ON') {
	print "<center><font color=#ff0000>$text{'index_warn'}",
	      "</font></center><br>\n";
	}

print "<center><applet archive=vncviewer.jar code=VncViewer.class ",
      "width=$config{'width'} height=$config{'height'}>\n";
print "<param name=port value='$port'>\n";
if ($config{'host'}) {
	print "<param name=host value='$config{'host'}'>\n";
	}
print "$text{'index_nojava'} <p>\n";
print "</applet><br>\n";
print "$text{'index_credits'}</center>\n";

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

