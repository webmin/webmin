#!/usr/local/bin/perl
# Show a terminal that is connected to a Websockets server via Webmin proxying
# XXX clean up old proxy ports

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
my %access = &get_module_acl();

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0, undef,
		 "<link rel=stylesheet href=xterm.css>\n".
		 "<script src=xterm.js></script>\n".
		 "<script src=xterm-addon-attach.js></script>\n"
		);

# Check for needed modules
my $modname = "Net::WebSocket::Server";
eval "use ${modname};";
if ($@) {
	print &text('index_cpan', "<tt>$modname</tt>",
		    "../cpan/download.cgi?source=3&cpan=$modname&mode=2&return=/$module_name/&returndesc=".&urlize($module_info{'desc'})),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	return;
	}

# Pick a port and configure Webmin to proxy it
my $port = $config{'base_port'} || 555;
while(1) {
	&open_socket("127.0.0.1", $port, TEST, \$err);
	last if ($err);
	close(TEST);
	$port++;
	}
my %miniserv;
&get_miniserv_config(\%miniserv);
my $wspath = "/$module_name/ws-".$port;
$miniserv{'websockets_'.$wspath} = "host=127.0.0.1 port=$port wspath=/ user=$remote_user";
&put_miniserv_config(\%miniserv);
&reload_miniserv();

# Launch the shell server on that port
&foreign_require("cron");
my $shellserver_cmd = "$module_config_directory/shellserver.pl";
if (!-r $shellserver_cmd) {
	&cron::create_wrapper($shellserver_cmd, $module_name, "shellserver.pl");
	}
my $user = $access{'user'};
my $tmpdir = &tempname_dir();
$ENV{'SESSION_ID'} = $main::session_id;
&system_logged("$shellserver_cmd $port $user >$tmpdir/ws-$port.out 2>&1 </dev/null &");
sleep(2);

# Open the terminal
my $url = "wss://".$ENV{'HTTP_HOST'}.$wspath;
print <<EOF;
<div id="terminal"></div>
<script>
var term = new Terminal();
term.open(document.getElementById('terminal'));
var socket = new WebSocket('$url', 'binary');
var attachAddon = new AttachAddon.AttachAddon(socket);
term.loadAddon(attachAddon);
</script>
EOF

&ui_print_footer("/", $text{'index'});

