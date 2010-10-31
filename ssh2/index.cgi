#!/usr/local/bin/perl
# Show the SSH 2 applet

BEGIN { push(@INC, ".."); };
use WebminCore;
use Socket;

&init_config();
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
	$ip = &to_ipaddress($addr) || &to_ip6address($addr);
	$port = $config{'port'} ? $config{'port'} : 22;
	if ($ip) {
		$SIG{ALRM} = "connect_timeout";
		alarm(10);
		&open_socket($ip, $port, STEST, \$err);
		close(STEST);
		$rv = !$err;
		}
	}
if (!$rv) {
	if ($ip) {
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
		$w = 800; $h = 420;
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
	if ($config{'foreground'}) {
		print "<param name=fg-color ",
		      "value='$config{'foreground'}'>\n";
		}
	if ($config{'background'}) {
		print "<param name=bg-color ",
		      "value='$config{'background'}'>\n";
		}
	if ($config{'term'}) {
		print "<param name=term-type value='$config{'term'}'>\n";
		}
	if ($config{'encoding'}) {
		print "<param name=encoding ",
		      "value='$config{'encoding'}'>\n";
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

