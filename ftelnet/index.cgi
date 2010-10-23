#!/usr/local/bin/perl
# Starts the flash policy server on port 843, then outputs an HTML page that
# references the flash object

BEGIN { push(@INC, ".."); };
use WebminCore;
use Socket;
&init_config();

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
$rows = $config{'rows'} || 25;
$cols = $config{'cols'} || 80;
$headhtml = <<EOF;
<script type="text/javascript">
var flashvars = {};
flashvars.AutoConnect = 1;
flashvars.BitsPerSecond = 115200;
flashvars.Blink = 1;
flashvars.BorderStyle = "Ubuntu1004";
flashvars.CodePage = "437";
flashvars.Enter = "\\r";
flashvars.FontHeight = 16;
flashvars.FontWidth = 9;
flashvars.ScreenColumns = $cols;
flashvars.ScreenRows = $rows;
flashvars.SendOnConnect = "";
flashvars.ServerHostName = "$host";
flashvars.ServerName = "Webmin";
flashvars.ServerPort = $telnetport;
flashvars.SocketPolicyPort = $port;
</script>
<script type="text/javascript" src="swfobject.js"></script>
<script type="text/javascript" src="fTelnet.js"></script>
EOF

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0, undef, $headhtml);

print <<EOF;
<div id="divfTelnet">
    <p>fTelnet is loading.  If you don't see it in a few seconds, you may need Adobe Flash Player version 10.0.0 or greater installed.</p>
    <a href="http://get.adobe.com/flashplayer/"><img src="http://www.adobe.com/images/shared/download_buttons/get_flash_player.gif" alt="Get Adobe Flash player" border="0" /></a> 
</div>
EOF

&ui_print_footer("/", $text{'index'});
