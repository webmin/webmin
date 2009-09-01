#!/usr/local/bin/perl
# Start the Ajaxterm webserver on a random port, then print an iframe for
# a URL that proxies to it

BEGIN { push(@INC, ".."); };
use WebminCore;
use Socket;
&init_config();

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

# Check for python
if (!&has_command("python")) {
	&ui_print_endpage(&text('index_epython', "<tt>python</tt>"));
	}

# Pick a free port
&get_miniserv_config(\%miniserv);
$port = $miniserv{'port'} + 1;
$proto = getprotobyname('tcp');
socket(TEST, PF_INET, SOCK_STREAM, $proto) ||
	&error("Socket failed : $!");
setsockopt(TEST, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
while(1) {
	last if (bind(TEST, sockaddr_in($port, INADDR_ANY)));
	$port++;
	}
close(TEST);

# Run the Ajaxterm webserver
system("cd $module_root_directory/ajaxterm ; python ajaxterm.py --port $port --log >/tmp/ajaxterm.out 2>&1 </dev/null &");

# Wait for it to come up
$try = 0;
while(1) {
	my $err;
	&open_socket("localhost", $port, TEST2, \$err);
	last if ($err);
	$try++;
	if ($try > 30) {
		&error(&text('index_estart', 30, $port));
		}
	sleep(1);
	}
close(TEST2);

# Show the iframe
print "<iframe src=$gconfig{'webprefix'}/$module_name/proxy.cgi/$port/ ",
      "width=100% height=90%></iframe>\n";

&ui_print_footer("/", $text{'index'});

