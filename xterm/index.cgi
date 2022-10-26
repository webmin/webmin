#!/usr/local/bin/perl
# Show a terminal that is connected to a Websockets server via Webmin proxying
# XXX clean up old proxy ports
# XXX permissions page
# XXX don't grant to new users
# XXX ACL to run as remote user
# XXX Virtualmin integration?
# XXX how to launch a login shell?

require './xterm-lib.pl';
&ReadParse();

# Get Webmin current version for links serial
my $wver = &get_webmin_version();
$wver =~ s/\.//;

# Build Xterm dependency links
my $termlinks = 
	{ 'css' => ['xterm.css?$wver'],
	  'js'  => ['xterm.js?$wver',
	            'xterm-addon-attach.js?$wver'] };

# Pre-process options
my ($conf_size_str, $def_cols_n, $def_rows_n,
    $rcvd_cnt_w, $rcvd_cnt_h,
    $rcvd_or_def_col_w, $rcvd_or_def_row_h,
    $rcvd_or_def_col_o, $rcvd_or_def_row_o,
    $resize_call,
    $xmlhr,
    %termjs_opts
) = ($config{'size'}, 80, 24,
     int($ENV{'HTTP_X_AGENT_WIDTH'}) || int($in{'w'}), int($ENV{'HTTP_X_AGENT_HEIGHT'}) || int($in{'h'}),
     int($in{'f'}) || 9, int($in{'l'}) || 18,
     int($in{'g'}) || 1, int($in{'o'}) || 0,
     int($in{'r'}),
     $ENV{'HTTP_X_REQUESTED_WITH'} eq "XMLHttpRequest");

# Parse module config
my ($conf_cols_n, $conf_rows_n) = ($conf_size_str =~ /([\d]+)X([\d]+)/i);
$conf_cols_n = int($conf_cols_n);
$conf_rows_n = int($conf_rows_n);
if ($conf_cols_n && $conf_rows_n) {
	$termjs_opts{'ContainerStyle'} = "style='width: fit-content; margin: 0 auto;'";
	}
else {
	$termjs_opts{'ContainerStyle'} = "style='height: 97%;'";
	}

# Set default container size in fixel depending on the mode
my $calc_cols_abs = ($rcvd_cnt_w || int($conf_cols_n * $rcvd_or_def_col_w) || 720) . "px";
my $calc_rows_abs = ($rcvd_cnt_h || int($conf_rows_n * $rcvd_or_def_row_h) || 432) . "px";
$calc_cols_abs = "auto" if (!$conf_cols_n);
$calc_rows_abs = "88vh" if (!$conf_rows_n);

# Set pixel to columns conversion
my $cols_num_user = int($rcvd_cnt_w / $rcvd_or_def_col_w);

# Set pixel to rows (lines) conversion
my $rows_num_user = int($rcvd_cnt_h / $rcvd_or_def_row_h);

# Set columns and rows environment vars
my $env_cols = $ENV{'COLUMNS'} = $conf_cols_n || $cols_num_user || $def_cols_n;
my $env_rows = $ENV{'LINES'} = $conf_rows_n || $rows_num_user || $def_rows_n;

# Define columns and rows
$termjs_opts{'Options'} = "{ cols: $env_cols, rows: $env_rows }";

# Adjust columns and rows offset for env vars, which
# should be always a tiny bit smaller than Xterm.js
$ENV{'COLUMNS'} -= $rcvd_or_def_col_o;
$ENV{'LINES'} -= $rcvd_or_def_row_o;

# Tweak old themes inline
my $styles_inline = <<EOF;

body[style='height:100%'] {
	height: 97% !important; 
}
#terminal {
	border: 1px solid #000;
	background-color: #000;
	min-width: $calc_cols_abs;
	min-height: $calc_rows_abs;
	height: $calc_rows_abs;
	padding: 2px;
}
#terminal:empty:after {
	display: block;
	content: " ";
	overflow: hidden;
	
	width: 24px;
	height: 24px;
	margin: 2% auto;
	border-radius: 50%;
	box-sizing: border-box;
	border: 1px solid transparent;
	border-top-color: rgba(255, 255, 255, 0.8);
	border-bottom-color: rgba(255, 255, 255, 0.8);
	animation: jumping-spinner 1s ease infinite;
}
\@keyframes jumping-spinner {
    to {
        transform: rotate(360deg);
    }
}
#terminal + script ~ * {
	display: none
}

EOF

# Print header
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0, undef,
		 "<link rel=stylesheet href=\"$termlinks->{'css'}[0]\">\n".
		 "<script src=\"$termlinks->{'js'}[0]\"></script>\n".
		 "<script src=\"$termlinks->{'js'}[1]\"></script>\n".
		 "<style>$styles_inline</style>\n"
		);

# Print main container
print "<div id=\"terminal\" $termjs_opts{'ContainerStyle'}></div>\n";

# Set column size depending on the browser window
# size unless defined in config (non-auto mode)
if (!$conf_cols_n && !$conf_rows_n) {
	if ((!$rcvd_cnt_w ||
	     !$rcvd_cnt_h) || $resize_call) {
		print "<script>location.href = location.pathname + '?w=' + document.querySelector('#terminal').clientWidth + '&h=' + document.querySelector('#terminal').clientHeight;</script>";
		return;
		}
	}

# Clear URL to make sure resized and
# reloaded page will work properly
print "<script>history.replaceState(null, String(), location.pathname);</script>";

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
	&open_socket("127.0.0.1", $port, my $fh, \$err);
	last if ($err);
	close($fh);
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
if ($user eq "*") {
	$user = $remote_user;
	}
defined(getpwnam($user)) || &error(&text('index_euser', $user));
my $tmpdir = &tempname_dir();
$ENV{'SESSION_ID'} = $main::session_id;
&system_logged("$shellserver_cmd $port $user >$tmpdir/ws-$port.out 2>&1 </dev/null &");
sleep(1);

# Open the terminal
my $url = "wss://".$ENV{'HTTP_HOST'}.$wspath;
my $term_script = <<EOF;

var term = new Terminal($termjs_opts{'Options'}),
    termcont = document.getElementById('terminal'),
    socket = new WebSocket('$url', 'binary'),
    attachAddon = new AttachAddon.AttachAddon(socket);
termcont.focus();
term.loadAddon(attachAddon);
term.open(termcont);
term.focus();
EOF

# Return inline script data depending on type
my $term_script_data =
	$xmlhr ?
	"var xterm_argv = ".
		&convert_to_json(
			{ 'files' => $termlinks,
			  'cols' => $env_cols,
			  'rows' => $env_rows,
			  'socket_url' => $url }) :
	$term_script;
print <<EOF;
<script>
	$term_script_data
</script>
EOF

&ui_print_footer();

