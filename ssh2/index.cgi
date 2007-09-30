#!/usr/local/bin/perl
# Show the SSH 2 applet
# XXX SSH1 vs 2 mode

require '../web-lib.pl';
use Socket;
&init_config();
require '../ui-lib.pl';
$theme_no_table = 1 if ($config{'sizemode'} == 1);
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

if ($config{'no_test'}) {
	# Just assume that the telnet server is running
	$rv = 1;
	}
else {
	# Check if the telnet server is running
	$addr = $config{'host'} ? $config{'host'} :
		$ENV{'SERVER_NAME'} ? $ENV{'SERVER_NAME'} :
				      &to_ipaddress(&get_system_hostname());
	$port = $config{'port'} ? $config{'port'} : 22;
	if (inet_aton($addr)) {
		socket(STEST, PF_INET, SOCK_STREAM, getprotobyname("tcp"));
		$SIG{ALRM} = "connect_timeout";
		alarm(10);
		$rv = connect(STEST, pack_sockaddr_in($port, inet_aton($addr)));
		close(STEST);
		}
	}
if (!$rv) {
	if (inet_aton($addr)) {
		print "<p>",&text('index_esocket2', $addr, $port),"<p>\n";
		}
	else {
		print "<p>",&text('index_elookup', $addr),"<p>\n";
		}
	}
else {
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
	print "<applet archive=\"mindterm.jar\" code=com.mindbright.application.MindTerm.class ",
	      "width=$w height=$h>\n";
	if ($config{'port'}) {
		print "<param name=port value=$config{'port'}>\n";
		}
	if ($config{'sizemode'}) {
		print "<param name=Terminal.resize value='screen'>\n";
		}
	if ($config{'fontsize'}) {
		print "<param name=Terminal.fontSize value='$config{'fontsize'}'>\n";
		}
	if ($config{'detach'}) {
		print "<param name=sepframe value='true'>\n";
		}
	print "$text{'index_nojava'} <p>\n";
	print "</applet><br>\n";

	print &text('index_credits',
		    "http://www.appgate.com/products/80_MindTerm/"),"<br>\n";
	print "</center>\n";
	}

&ui_print_footer("/", $text{'index'});

sub connect_timeout
{
}

