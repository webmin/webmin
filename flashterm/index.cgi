#!/usr/local/bin/perl
# Starts the flash policy server on port 843, then outputs an HTML page that
# references the flash object

BEGIN { push(@INC, ".."); };
use WebminCore;
use Socket;
&init_config();

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

# Work out host and port
$host = $ENV{'HTTP_HOST'};
$host =~ s/\:\d+$//;
$telnetport = $config{'telnetport'} || 23;

# Check for telnet
&open_socket($host, $telnetport, TEST, \$err);
$err && &error(&text('index_etelnet', $telnetport));
close(TEST);

# Start the policy file server on port 843
$port = 843;
$proto = getprotobyname('tcp');
socket(MAIN, PF_INET, SOCK_STREAM, $proto) ||
	&error(&text('index_esocket', "$!"));
setsockopt(MAIN, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
bind(MAIN, sockaddr_in($port, INADDR_ANY)) ||
	&error(&text('index_eport', $port));
listen(MAIN, SOMAXCONN);

# Fork the process that will accept the connection
$pid = fork();
if (!$pid) {
	$rmask = undef;
	vec($rmask, fileno(MAIN), 1) = 1;
	$sel = select($rmask, undef, undef, 10);
	exit(1) if ($sel <= 0);
	accept(SOCK, MAIN);
	close(MAIN);
	select(SOCK); $| = 1;
	$header = "<policy-file-request/>\000";
	read(SOCK, $buf, length($header));
	$buf eq $header || die "Invalid message $buf";
	print SOCK <<EOF;
<?xml version="1.0"?>
<!DOCTYPE cross-domain-policy SYSTEM "/xml/dtds/cross-domain-policy.dtd">
<cross-domain-policy>
<site-control permitted-cross-domain-policies="master-only"/>
<allow-access-from domain="$host" to-ports="$telnetport" />
</cross-domain-policy>
EOF
	close(SOCK);
	exit(0);
	}
close(MAIN);

# Output HTML for the flash object
print <<EOF;
<script type="text/javascript" src="swfobject.js"></script> 
<script type="text/javascript" src="js/global.js"></script> 
<script type="text/javascript"> 
	var flashvars = {};
	var params = {};
	params.menu = "false";
	params.bgcolor = "000000";
	var attributes = {};
	flashvars.settings = 'settings.cgi';
	swfobject.embedSWF("flashterm.swf", "flash", "650", "440", "9.0.0", "expressInstall.swf", flashvars, params, attributes);
	function setFocusOnFlash() {
		var fl = document.getElementById("flash");
		fl.focus();
	}
swfobject.addLoadEvent(setFocusOnFlash);
</script> 
<div id="flashcontainer"><div id="flash"></div></div> 
EOF

&ui_print_footer("/", $text{'index'});
