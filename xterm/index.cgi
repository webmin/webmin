#!/usr/local/bin/perl
# Show a terminal that is connected to a Websockets server via Webmin proxying

use lib ("$ENV{'DOCUMENT_ROOT'}/xterm/lib");

require './xterm-lib.pl';
&ReadParse();

# Get Webmin current version for links serial
my $wver = &get_webmin_version();
$wver =~ s/\.//;

# Check for needed modules
my $modname = "Net::WebSocket::Server";
eval "use ${modname};";
if ($@) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0);
	print &text('index_cpan', "<tt>$modname</tt>",
		    "../cpan/download.cgi?source=3&cpan=$modname&mode=2&return=/$module_name/&returndesc=".&urlize($module_info{'desc'})),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	return;
	}

# Build Xterm dependency links
my $termlinks = 
	{ 'css' => ['xterm.css?$wver'],
	  'js'  => ['xterm.js?$wver',
	            'xterm-addon-attach.js?$wver'] };

# Pre-process options
my $conf_size_str = $config{'size'};
my $def_cols_n = 80;
my $def_rows_n = 24;
my $rcvd_cnt_w = int($ENV{'HTTP_X_AGENT_WIDTH'}) || int($in{'w'});
my $rcvd_cnt_h = int($ENV{'HTTP_X_AGENT_HEIGHT'}) || int($in{'h'});
my $rcvd_or_def_col_w = &is_float($in{'f'}) ? $in{'f'} : 9;
my $rcvd_or_def_row_h = &is_float($in{'l'}) ? $in{'l'} : 18;
my $rcvd_or_def_col_o = int($in{'g'}) || 1;
my $rcvd_or_def_row_o = int($in{'o'}) || 0;
my $resize_call = $in{'r'};
my $xmlhr = $ENV{'HTTP_X_REQUESTED_WITH'} eq "XMLHttpRequest";
my %term_opts;

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

# Detect terminal width and height for regular themes 
if (!$xmlhr) {
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
	}

# Find ports already in use
&lock_file(&get_miniserv_config_file());
my %miniserv;
&get_miniserv_config(\%miniserv);
my %inuse;
foreach my $k (keys %miniserv) {
	if ($k =~ /^websockets_/ && $miniserv{$k} =~ /port=(\d+)/) {
		$inuse{$1} = 1;
		}
	}

# Pick a port and configure Webmin to proxy it
my $port = $config{'base_port'} || 555;
while(1) {
	if (!$inuse{$port}) {
		&open_socket("127.0.0.1", $port, my $fh, \$err);
		last if ($err);
		close($fh);
		}
	$port++;
	}
my $wspath = "/$module_name/ws-".$port;
$miniserv{'websockets_'.$wspath} = "host=127.0.0.1 port=$port wspath=/ user=$remote_user";
&put_miniserv_config(\%miniserv);
&unlock_file(&get_miniserv_config_file());
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

# Switch to given user
if ($user eq "root") {
	my $username = $in{'user'};
	if ($username) {
	my @uinfo = getpwnam($username);
		if (@uinfo) {
			$user = $username;
			}
		else {
			&error(&text('index_euser', $username));
			}
		}
	}

defined(getpwnam($user)) || &error(&text('index_euser', $user));
my $tmpdir = &tempname_dir();
$ENV{'SESSION_ID'} = $main::session_id;
&system_logged("$shellserver_cmd $port $user >$tmpdir/ws-$port.out 2>&1 </dev/null");

# Open the terminal
my $url = "wss://".$ENV{'HTTP_HOST'}.$wspath;
my $term_script = <<EOF;

(function() {
	var socket = new WebSocket('$url', 'binary'),
	    termcont = document.getElementById('terminal'),
	    err_conn_cannot = 'Cannot connect to the socket $url',
	    err_conn_lost = 'Connection to the socket $url lost';
	socket.onopen = function() {
		var term = new Terminal($termjs_opts{'Options'}),
		    attachAddon = new AttachAddon.AttachAddon(this);
		term.loadAddon(attachAddon);
		term.open(termcont);
		term.focus();
		socket.send('clear\\r');
	};
	socket.onerror = function() {
		termcont.innerHTML = '<tt style="color: \#ff0000">Error: ' +
			err_conn_cannot + '</tt>';
	};
	socket.onclose = function() {
		termcont.innerHTML = '<tt style="color: \#ff0000">Error: ' +
			err_conn_lost + '</tt>';
	};
})();

EOF

# Return inline script data depending on type
print "<script>\n";
if ($xmlhr) {
	print "var xterm_argv = ".
	      &convert_to_json(
			{ 'files' => $termlinks,
			  'cols' => $env_cols,
			  'rows' => $env_rows,
			  'port' => $port,
			  'socket_url' => $url });
	}
else {
	print $term_script;
	}
print "</script>\n";
&ui_print_footer();

