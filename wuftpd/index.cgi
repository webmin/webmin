#!/usr/local/bin/perl
# index.cgi
# Display the wuFTPd main menu

require './wuftpd-lib.pl';
use Socket;
$| = 1;

# Check if wuftpd is installed
if (!-x $config{'ftpd_path'}) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		&help_search_link("wu-ftpd", "man", "doc", "google"));
	print &text('index_eftpd', "<tt>$config{'ftpd_path'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if the ftpaccess file exists
if (!-r $config{'ftpaccess'}) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		&help_search_link("wu-ftpd", "man", "doc", "google"));
	print &text('index_eftpaccess', "<tt>$config{'ftpaccess'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

@st = stat($config{'ftpd_path'});
&read_file("$module_config_directory/ftpd", \%ftpd);
if ($ftpd{'size'} != $st[7] || $ftpd{'mtime'} != $st[9]) {
	# Run the ftpd to check if it is really wuftpd, by starting it
	# in a separate TCP server process
	$proto = getprotobyname('tcp');
	socket(MAIN, PF_INET, SOCK_STREAM, $proto) ||
		&error("socket failed : $!");
	setsockopt(MAIN, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
	$port = 10000;
	while(1) {
		$port++;
		last if (bind(MAIN, pack_sockaddr_in($port, INADDR_ANY)));
		}
	listen(MAIN, SOMAXCONN);
	if (!($pid = fork())) {
		accept(SOCK, MAIN) || exit(1);
		untie(*STDIN);
		untie(*STDOUT);
		untie(*STDERR);
		open(STDIN, "<&SOCK");
		open(STDOUT, ">&SOCK");
		open(STDERR, ">&SOCK");
		exec("$config{'ftpd_path'} -A");
		print "Exec failed : $!\n";
		exit;
		}
	close(MAIN);
	&open_socket("localhost", $port, CONN);
	select(CONN); $| = 1; select(STDOUT);
	print CONN "quit\n";
	local $out;
	while(<CONN>) {
		$version = $1 if (/Version\s+wu-(\d+\.\d+)/i);
		$out .= $_;
		}
	close(CONN);
	waitpid($pid, 0);
	if (!$version) {
		&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
			&help_search_link("wu-ftpd", "man", "doc", "google"));
		print &text('index_eversion',
			  "<tt>$config{'ftpd_path'}</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name",
			  "<pre>$out</pre>"),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}

	# Save version information
	$ftpd{'size'} = $st[7];
	$ftpd{'mtime'} = $st[9];
	$ftpd{'version'} = $version;
	&write_file("$module_config_directory/ftpd", \%ftpd);
	}

&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link("wu-ftpd", "man", "doc", "google"), undef, undef,
	&text('index_version', $ftpd{'version'}));

# Display table of icons
@names = ( 'class', 'message', 'acl', 'net', 'log',
	   'alias', 'anon', 'perm', 'misc' );
@links = map { "edit_${_}.cgi" } @names;
@titles = map { $text{"${_}_title"} } @names;
@icons = map { "images/${_}.gif" } @names;
&icons_table(\@links, \@titles, \@icons, 5);

($inet, $inet_mod) = &running_under_inetd();
if (!$inet) {
	# Get the FTP server pid
	$pid = &check_pid_file($config{'pid_file'});
	}

if (!$inet && $pid) {
	print &ui_hr();
	print "<form action=restart.cgi>\n";
	print "<input type=hidden name=pid value='$pid'>\n";
	print "<table width=100%><tr>\n";
	print "<td><input type=submit value=\"$text{'index_apply'}\"></td>\n";
	print "<td>$text{'index_applymsg'}</td>\n";
	print "</tr></table></form>\n";
	}
elsif (!$inet && !$pid) {
	print &ui_hr();
	print "<form action=start.cgi>\n";
	print "<table width=100%><tr>\n";
	print "<td><input type=submit value=\"$text{'index_start'}\"></td>\n";
	if ($inet_mod) {
		print "<td>",&text('index_startmsg', "/$inet_mod/"),"</td>\n";
		}
	else {
		print "<td>$text{'index_startmsg2'}</td>\n";
		}
	print "</tr></table></form>\n";
	}

&ui_print_footer("/", $text{'index'});

