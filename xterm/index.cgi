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
	            'xterm-addon-attach.js?$wver',
	            'xterm-addon-fit.js?$wver'] };

# Pre-process options
my $conf_size_str = $config{'size'};
my $def_cols_n = 80;
my $def_rows_n = 24;
my $xmlhr = $ENV{'HTTP_X_REQUESTED_WITH'} eq "XMLHttpRequest";
my %term_opts;

# Parse module config
my ($conf_cols_n, $conf_rows_n) = ($conf_size_str =~ /([\d]+)X([\d]+)/i);
$conf_cols_n = int($conf_cols_n);
$conf_rows_n = int($conf_rows_n);

# Set columns and rows environment vars
my $env_cols = $ENV{'COLUMNS'} = $conf_cols_n || $def_cols_n;
my $env_rows = $ENV{'LINES'} = $conf_rows_n || $def_rows_n;

# Define columns and rows
$termjs_opts{'Options'} = "{ cols: $env_cols, rows: $env_rows }";

my $term_size = "
	min-width: ".($conf_cols_n ? "".($conf_cols_n * 9)."px" : "calc(100vw - 22px)").";
	max-width: ".($conf_cols_n ? "".($conf_cols_n * 9)."px" : "calc(100vw - 22px)").";
	min-height: ".($conf_rows_n ? "".($conf_rows_n * 18)."px" : "calc(100vh - 55px)").";
	max-height: ".($conf_rows_n ? "".($conf_rows_n * 18)."px" : "calc(100vh - 55px)").";";

# Tweak old themes inline
my $styles_inline = <<EOF;

body[style='height:100%'] {
	height: 97% !important; 
}
#headln2l a {
	white-space: nowrap;
}
#terminal {
	border: 1px solid #000;
	background-color: #000;
	padding: 2px;
	margin: 0 auto;
	$term_size
}
#terminal:empty:before {
    display: block;
    content: " ";
    overflow: hidden;
    
    width: 12px;
    height: 12px;
    
    margin-top: 4px;
    margin-left: 4px;
    
    border-radius: 50%;
    
    box-sizing: border-box;

    border: 1px solid transparent;
    border-top-color: rgba(255, 255, 255, 0.8);
    border-bottom-color: rgba(255, 255, 255, 0.8);
    animation: jumping-spinner 1s ease infinite;
}

#terminal:empty:after {

    display: block;
    content: attr(data-label);
    margin-left: 24px;
    margin-top: -16px;
    font-weight: 100;
    color: rgba(255, 255, 255, 0.8);
    font-family: "Lucida Console", Courier, monospace;
    font-size: 14px;
    text-transform: uppercase;
}
\@keyframes jumping-spinner {
    to {
        transform: rotate(360deg);
    }
}
#terminal + script ~ * {
	display: none
}
#terminal > .terminal {
	visibility: hidden;
	animation: .15s fadeIn;
	animation-fill-mode: forwards;
}
\@keyframes fadeIn {
  99% {
    visibility: hidden;
  }
  100% {
    visibility: visible;
  }
}

EOF

# Print header
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0, undef,
		 "<link rel=stylesheet href=\"$termlinks->{'css'}[0]\">\n".
		 "<script src=\"$termlinks->{'js'}[0]\"></script>\n".
		 "<script src=\"$termlinks->{'js'}[1]\"></script>\n".
		 "<script src=\"$termlinks->{'js'}[2]\"></script>\n".
		 "<style>$styles_inline</style>\n"
		);

# Print main container
print "<div data-label=\"$text{'index_connecting'}\" id=\"terminal\"></div>\n";

# Find ports already in use
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

# Check permissions for user to run as
my $user = $access{'user'};
if ($user eq "*") {
	$user = $remote_user;
	}

# Switch to given user
if ($user eq "root" && $in{'user'}) {
	defined(getpwnam($in{'user'})) ||
		&error(&text('index_euser', &html_escape($in{'user'})));
	$user = $in{'user'};
	}
my @uinfo = getpwnam($user);
@uinfo || &error(&text('index_euser', &html_escape($user)));

# Check for directory to start the shell in
my $dir = $in{'dir'};

# Launch the shell server on the allocated port
&foreign_require("cron");
my $shellserver_cmd = "$module_config_directory/shellserver.pl";
if (!-r $shellserver_cmd) {
	&cron::create_wrapper($shellserver_cmd, $module_name, "shellserver.pl");
	}
my $tmpdir = &tempname_dir();
$ENV{'SESSION_ID'} = $main::session_id;
&system_logged($shellserver_cmd." ".quotemeta($port)." ".quotemeta($user).
	       ($dir ? " ".quotemeta($dir) : "").
	       " >$tmpdir/ws-$port.out 2>&1 </dev/null");

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
		    fitAddon = new FitAddon.FitAddon();
		term.loadAddon(attachAddon);
		term.loadAddon(fitAddon);
		term.open(termcont);
		term.focus();
		
		// On resize event triggered by fit()
		term.onResize(function(e) {
			socket.send('\\\\033[8;('+e.rows+');('+e.cols+')t');
		});

		// Observe on terminal container change
		new ResizeObserver(function() {
			fitAddon.fit();
		}).observe(termcont);
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
            { 'conf'  => \%config,
              'files' => $termlinks,
              'socket_url' => $url,
              'port'  => $port,
              'cols'  => $env_cols,
              'rows'  => $env_rows,
              'uinfo'  => \@uinfo });
	}
else {
	print $term_script;
	}
print "</script>\n";
&ui_print_footer();
