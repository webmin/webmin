#!/usr/local/bin/perl
# Start a websocket server connected to a shell

use lib ("$ENV{'PERLLIB'}/xterm/lib");
use Net::WebSocket::Server;
use utf8;

require './xterm-lib.pl';

my ($port, $user, $dir) = @ARGV;

# Switch to the user we're running as
my @uinfo = getpwnam($user);
my ($uid, $gid);
if ($user ne "root" && !$<) {
	if (!@uinfo) {
		&cleanup_miniserv_websocket($port, $module_name);
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

# Set terminal
$ENV{'TERM'} = 'xterm-256color';
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
	&cleanup_miniserv_websocket($port, $module_name);
	die "Failed to run shell with $shcmd\n";
	}
else {
	print STDERR "Running shell $shcmd with pid $pid\n";
	}

# We have pid, save it to miniserv config now
&save_miniserv_websocket($port, $pid, $module_name);

# Detach from controlling terminal
if (fork()) {
	exit(0);
	}
untie(*STDIN);
close(STDIN);

$SIG{'ALRM'} = sub {
	&cleanup_miniserv_websocket($port, $module_name);
	die "timeout waiting for connection";
	};
alarm(60);
print STDERR "listening on port $port\n";
my ($wsconn, $shellbuf);
Net::WebSocket::Server->new(
	listen     => $port,
	on_connect => sub {
		my ($serv, $conn) = @_;
		print STDERR "got websockets connection\n";
		if ($wsconn) {
			print STDERR "Unexpected second connection to the same port\n";
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
				if ($key ne $dsess) {
					print STDERR "Key $key does not match session ID $dsess\n";
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
					print STDERR "got resize to $rows $cols\n";
					eval {
						$shellfh->set_winsize($rows, $cols);
						};
					kill('WINCH', $pid);
					return;
					}
				if (!syswrite($shellfh, $msg, length($msg))) {
					print STDERR "write to shell failed : $!\n";
					&cleanup_miniserv_websocket($port, $module_name);
					exit(1);
					}
				},
			disconnect => sub {
				print STDERR "websocket connection closed\n";
				&cleanup_miniserv_websocket($port, $module_name);
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
				print STDERR "end of output from shell\n";
				&cleanup_miniserv_websocket($port, $module_name);
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
print STDERR "exited websockets server\n";
&cleanup_miniserv_websocket($port, $module_name);
&cleanup_miniserv_websockets($module_name);

