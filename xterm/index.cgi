#!/usr/local/bin/perl
# Show a terminal that is connected to a Websockets server via Webmin proxying
# XXX clean up old proxy ports
# XXX permissions page
# XXX don't grant to new users
# XXX ACL to run as remote user
# XXX Virtualmin integration?

require './xterm-lib.pl';
&ReadParse();

my $wver = &get_webmin_version();
$wver =~ s/\.//;
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0, undef,
		 "<link rel=stylesheet href=xterm.css?$wver>\n".
		 "<script src=xterm.js?$wver></script>\n".
		 "<script src=xterm-addon-attach.js?$wver></script>\n".
		 "<script src=xterm-addon-fit.js?$wver></script>\n"
		);

# Set column size depending on the browser window size
my $screen_width = int($in{'w'});
my $screen_height = int($in{'h'});
if (!$screen_width ||
    !$screen_height) {
	print "<script>location.href = location.pathname + '?w=' + window.innerWidth + '&h=' + window.innerHeight;</script>";
	return;
}

# Set pixel to columns conversion
my $cols_num_user = int($screen_width / (int($in{'f'}) || 9));

# Set pixel to rows (lines) conversion
my $rows_num_user = int($screen_height / (int($in{'l'}) || 18));

# Process options
my ($size, $colsdef, $rowsdef, $termopts) = ($config{'size'}, 80, 24);
if ($size && $size =~ /([\d]+)X([\d]+)/i) {
	$termopts =
	  {'ContainerStyle' => "style='width: fit-content; margin: 0 auto;'",
	   'Options' => "{ cols: $1, rows: $2 }"};
	$ENV{'COLUMNS'} = int($1) || $colsdef;
	$ENV{'LINES'} = int($2) || $rowsdef;
	}
else {
	$termopts =
	  {'FitAddonLoad' => 'var fitAddon = new FitAddon.FitAddon(); term.loadAddon(fitAddon);',
	   'FitAddonAdjust' => 'fitAddon.fit();',
	   'ContainerStyle' => "style='height: 95%;'"};
	$ENV{'COLUMNS'} = int($cols_num_user) || $colsdef;
	$ENV{'LINES'} = int($rows_num_user) || $rowsdef;
	}

# Columns and rows size sanity check and adjustments
$ENV{'COLUMNS'} = 86 if ($ENV{'COLUMNS'} < 86);
$ENV{'COLUMNS'} -= 6;
$ENV{'LINES'} = 28 if ($ENV{'COLUMNS'} < 28);
$ENV{'LINES'} -= 4;

# Make sure container isn't scrolled in older themes
print "<style>body[style='height:100%'] { height: 99% !important; } #terminal + script ~ * { display: none }</style>\n";

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
sleep(1);

# Open the terminal
my $url = "wss://".$ENV{'HTTP_HOST'}.$wspath;
print "<div id=\"terminal\" $termopts->{'ContainerStyle'}></div>";
print <<EOF;
<script>
	var term = new Terminal($termopts->{'Options'}),
		socket = new WebSocket('$url', 'binary'),
		attachAddon = new AttachAddon.AttachAddon(socket);
	term.loadAddon(attachAddon);
	$termopts->{'FitAddonLoad'}
	term.open(document.getElementById('terminal'));
	$termopts->{'FitAddonAdjust'}
	term.focus();
</script>
EOF

&ui_print_footer();

