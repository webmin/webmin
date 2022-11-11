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
		&cleanup_miniserv();
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

# Terminal inbuilt flavors (envs)
my $ps1inblt;
if (
    # Always enable disregard of user shell
    $config{'flavors'} == 1 ||
    # Automatically enable only for users with bash
    $config{'flavors'} == 2 && $uinfo[8] =~ /\/bash$/) {

	# Set shell history controls
	$ENV{'HISTCONTROL'} = 'ignoredups:ignorespace';

	# Optionally add colors to the prompt depending on the user type
	if ($user eq "root") {
		# magenta@blue ~# (for root)
		$ps1inblt = '\[\033[1;35m\]\u\[\033[1;37m\]@'.
		            '\[\033[1;34m\]\h:\[\033[1;37m\]'.
		            '\w\[\033[1;37m\]$\[\033[0m\] ';
		}
	else {
		# green@blue ~$ (for regular users)
		$ps1inblt = '\[\033[1;32m\]\u\[\033[1;37m\]@'.
		            '\[\033[1;34m\]\h:\[\033[1;37m\]'.
		            '\w\[\033[1;37m\]$\[\033[0m\] ';
		}
	}

# Set terminal
$ENV{'TERM'} = 'xterm-256color';
chdir($dir || $uinfo[7] || "/");
my $shell = $uinfo[8];
$shell =~ s/^.*\///;
$shell = "-".$shell;
my ($shellfh, $pid) = &proc::pty_process_exec($uinfo[8], $uid, $gid, $shell);
&reset_environment();

# Check user current PS1 and set our default, if allowed
if ($ps1inblt) {
	my $ps1user;
	# Check user current PS1
	if ($config{'flavors'} == 2) {
		syswrite($shellfh, " echo \$PS1\r", length(" echo \$PS1\r"));
		&wait_for($shellfh, ".*\n.*\n.*\r"), &wait_for($shellfh, ".*\r");
		$ps1user = &trim($wait_for_input);
		}
	# Can we discard currently used PS1 and set our default?
	if (!$ps1user || $ps1user && (
		# Default Ubuntu and Debian (user)
		$ps1user eq '\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$' ||
		# Default Ubuntu
		$ps1user eq '\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\h:\w\$' ||
		# Default Debian
		$ps1user eq '${debian_chroot:+($debian_chroot)}\u@\h:\w\$' ||
		# Default RHEL
		$ps1user eq '[\u@\h \W]\$')) {
		syswrite($shellfh, " PS1='$ps1inblt'\r", length(" PS1='$ps1inblt'\r"));
		}
	}

if (!$pid) {
	&cleanup_miniserv();
	die "Failed to run shell $uinfo[8]";
	}
print STDERR "shell process is $pid\n";

# Detach from controlling terminal
if (fork()) {
	exit(0);
	}
untie(*STDIN);
close(STDIN);

$SIG{'ALRM'} = sub {
	&cleanup_miniserv();
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
					&cleanup_miniserv();
					exit(1);
					}
				},
			disconnect => sub {
				print STDERR "websocket connection closed\n";
				&cleanup_miniserv();
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
				&cleanup_miniserv();
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
&cleanup_miniserv();

sub cleanup_miniserv
{
my %miniserv;
if ($port) {
	&lock_file(&get_miniserv_config_file());
	&get_miniserv_config(\%miniserv);
	my $wspath = "/$module_name/ws-".$port;
	if ($miniserv{'websockets_'.$wspath}) {
		delete($miniserv{'websockets_'.$wspath});
		&put_miniserv_config(\%miniserv);
		&reload_miniserv();
		}
	&unlock_file(&get_miniserv_config_file());
	}
}
