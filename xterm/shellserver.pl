#!/usr/local/bin/perl
# Start a websocket server connected to a shell

use lib ("$ENV{'PERLLIB'}/vendor_perl");
use Net::WebSocket::Server;
use IO::Socket::INET;
use utf8;

require './xterm-lib.pl';

my ($port, $user, $dir) = @ARGV;

# Switch to the user we're running as
my @uinfo = getpwnam($user);
my ($uid, $gid);
if ($user ne "root" && !$<) {
	if (!@uinfo) {
		&remove_miniserv_websocket($port, $module_name);
		die "User $user does not exist!";
		}
	$uid = $uinfo[2];
	$gid = $uinfo[3];
	}
else {
	$uid = $gid = 0;
	}

# Run the user's shell in a sub-process
&foreign_require("proc");
&clean_environment();

# Set locale
my $lang = $config{'locale'};
if ($lang) {
	my @opts = ('LC_ALL', 'LANG', 'LANGUAGE');
	$lang = 'en_US.UTF-8' if ($lang == 1);
	foreach my $opt (@opts) {
		$ENV{$opt} = &trim($lang);
		}
	}

# Set terminal
$ENV{'USER'} = $user;
my $config_xterm = $config{'xterm'};
$config_xterm = 'xterm-256color'
	if (!$config_xterm);
$config_xterm =~ s/\+/-/;
$ENV{'TERM'} = $config_xterm;
$ENV{'HOME'} = $uinfo[7];
chdir($dir || $uinfo[7] || "/");
my $shellcmd = $uinfo[8];
my $shellname = $shellcmd;
$shellname =~ s/^.*\///;
my $shellexec = $shellcmd;
my $shelllogin = "-".$shellname;

# Check for initialization file
if ($config{'rcfile'} ne '0') {
	# Load shell init default file from module root directory or custom file
	my $rcdir  = "$module_root_directory/rc";
	my $rcfile = $config{'rcfile'} eq '1' ?
	               "$rcdir/.".$shellname."rc" :
	               $config{'rcfile'};
	if ($rcfile =~ /^\~\//) {
		$rcfile =~ s/^\~\///;
		$rcfile = "$uinfo[7]/$rcfile";
		}
	if (-r $rcfile) {
		if ($shellname eq 'bash') {
			# Bash
			$shellexec = "$shellcmd --rcfile $rcfile";
			}
		elsif ($shellname eq 'zsh') {
			# Zsh
			$ENV{'ZDOTDIR'} = $rcdir;
			}

		# Cannot use login shell while passing other parameters,
		# and it is not necessary as we already add init files
		$shelllogin = undef;
		}
	}
my ($shellfh, $pid) = &proc::pty_process_exec($shellexec, $uid, $gid, $shelllogin);
&reset_environment();
my $shcmd = "'$shellexec".($shelllogin ? " $shelllogin" : "")."'";
if (!$pid) {
	&remove_miniserv_websocket($port, $module_name);
	die "Failed to run shell with $shcmd\n";
	}
else {
	&error_stderr("Running shell $shcmd for user $user with pid $pid");
	}

# Detach from controlling terminal
if (fork()) {
	exit(0);
	}
untie(*STDIN);
close(STDIN);

# Clean up when socket is terminated
$SIG{'ALRM'} = sub {
	&remove_miniserv_websocket($port, $module_name);
	die "timeout waiting for connection";
	};
alarm(60);
&error_stderr("Listening on port $port");
my ($wsconn, $shellbuf);
my $server_socket = IO::Socket::INET->new(
    Listen    => 5,
    LocalAddr => '127.0.0.1',
    LocalPort => $port,
    Proto     => 'tcp',
    ReuseAddr => 1,
);
$server_socket || die "failed to listen on port $port";
Net::WebSocket::Server->new(
	listen     => $server_socket,
	on_connect => sub {
		my ($serv, $conn) = @_;
		&error_stderr("WebSocket connection established");
		if ($wsconn) {
			&error_stderr("Unexpected second connection to the same port");
			$conn->disconnect();
			return;
			}
		$wsconn = $conn;
		alarm(0);
		$conn->on(
			handshake => sub {
				# Is the key valid for this Webmin session?
				my ($conn, $handshake) = @_;
				my $key   = $handshake->req->fields->{'sec-websocket-key'};
				my $dsess = &encode_base64($main::session_id);
				$key   =~ s/\s//g;
				$dsess =~ s/\s//g;
				if (!$key || !$dsess || $key ne $dsess) {
					&error_stderr("Key $key does not match session ID $dsess");
					$conn->disconnect();
					}
				},
			ready => sub {
				my ($conn) = @_;
				$conn->send_binary($shellbuf) if ($shellbuf);
				},
			utf8 => sub {
				my ($conn, $msg) = @_;
				utf8::encode($msg) if (utf8::is_utf8($msg));
				# Check for resize escape sequence explicitly
				if ($msg =~ /^\\033\[8;\((\d+)\);\((\d+)\)t$/) {
					my ($rows, $cols) = ($1, $2);
					&error_stderr("Got resize to $rows $cols");
					eval {
						$shellfh->set_winsize($rows, $cols);
						};
					# If failed make ioctl directly (TIOCSWINSZ)
					# https://manpages.ubuntu.com/manpages/man2/ioctl_list.2.html
					if ($@) {
						ioctl($shellfh, 0x00005414, pack("s2", $rows, $cols));
						}
					kill('WINCH', $pid);
					return;
					}
				if (!syswrite($shellfh, $msg, length($msg))) {
					&error_stderr("Write to shell failed : $!");
					&remove_miniserv_websocket($port, $module_name);
					exit(1);
					}
				},
			disconnect => sub {
				&error_stderr("WebSocket connection closed");
				&remove_miniserv_websocket($port, $module_name);
				kill('KILL', $pid) if ($pid);
				exit(0);
				}
			);
	},
	watch_readable => [
		$shellfh => sub {
			# Got something from the shell
			my $buf;
			my $ok = sysread($shellfh, $buf, 1024);
			if ($ok <= 0) {
				&error_stderr("End of output from shell");
				&remove_miniserv_websocket($port, $module_name);
				exit(0);
				}
			if ($wsconn) {
				$wsconn->send_binary($buf);
				}
			else {
				$shellbuf .= $buf;
				}
		},
	],
)->start;
&error_stderr("Exited WebSocket server");
&remove_miniserv_websocket($port, $module_name);
&cleanup_miniserv_websockets([$port], $module_name);