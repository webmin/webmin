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
my ($shinit);

# Try to enable shell flavors
if ($config{'flavors'}) {

	# Bash
	if ($uinfo[8] =~ /\/bash$/) {
		# Optionally add colors to the prompt depending on the user type
		my $ps1inblt;
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
		# Set shell flavors stuff
		$shinit = { 'envs'  => [ { 'histcontrol' => 'ignoredups:ignorespace' } ],
		            'cmds'  => [ { 'ps1'         => $ps1inblt } ],
		            'files' => [ '.bashrc', '.profile', '.bash_profile' ] }
		}
	# Other shell opts here?
	}

# Check user current PS1 and set our default, if allowed
if ($shinit) {
	my ($shfiles, $shcmds) = ($shinit->{'files'},
	                          $shinit->{'cmds'});
	# Check user current PS1
	my $shparse_opt = sub {
		my ($line) = @_;
		my $cmt = index($line, "#");
		my $eq = index($line, "=");
		if ($cmt != 0 && $eq >= 0) {
			my $n = substr($line, 0, $eq);
			my $v = substr($line, $eq+1);
			chomp($v);
			return {$n => $v}
			}
		};
	SHFILES:
	foreach my $shfile (@{$shfiles}) {
		my $shfile_path = 
			$shfile !~ /^\// ? "$uinfo[7]/$shfile" : $shfile;
		if (-r $shfile_path) {
			my $shfile_ref = &read_file_lines($shfile_path, 1);
			foreach my $shfile_line (@$shfile_ref) {
				my $shfile_line_opt = &$shparse_opt($shfile_line);
				# Check for an active PS1 option
				if ($shfile_line_opt && $shfile_line_opt->{'PS1'}) {
					map { $_->{'ps1'} && delete($_->{'ps1'}) } @{$shcmds};
					last SHFILES;
					}
				# Check for other sourced files
				else {
					if ($shfile_line =~ /\s*^(?!#)\s*(\.|source)(?<sourced_file>.*)/) {
						my $sourced_file = "$+{sourced_file}";
						$sourced_file =~ s/^\s+//;
						$sourced_file =~ s/\s+$//;
						$sourced_file =~ s/^\~\///;
						push(@{$shfiles}, $sourced_file)
							if (!grep(/^$sourced_file$/, @{$shfiles}));
						}
					}
				}
			}
		}
	}

# User config enviromental variables
if ($config{'flavors_envs'}) {
	my @flavors_envs = split(/\t+/, $config{'flavors_envs'});
	foreach my $flavors_env (@flavors_envs) {
		my ($k, $v) = split(/=/, $flavors_env, 2);
		$ENV{$k} = $v;
		}
	}

# Add additional shell envs
if ($shinit && $shinit->{'envs'}) {
	foreach my $env (@{$shinit->{'envs'}}) {
		foreach my $shopt (keys %{$env}) {
			if ($shopt) {
				$ENV{uc($shopt)} = $env->{$shopt};
				}
			}
		}
	}

# Set terminal
$ENV{'TERM'} = 'xterm-256color';
$ENV{'HOME'} = $uinfo[7];
chdir($dir || $uinfo[7] || "/");
my $shell = $uinfo[8];
$shell =~ s/^.*\///;
$shell = "-".$shell;
my ($shellfh, $pid) = &proc::pty_process_exec($uinfo[8], $uid, $gid, $shell);
&reset_environment();
if (!$pid) {
	&cleanup_miniserv();
	die "Failed to run shell $uinfo[8]";
	}
print STDERR "shell process is $pid\n";

# User config commands to run on shell login
if ($config{'flavors_cmds'}) {
	my @flavors_cmds = split(/\t+/, $config{'flavors_cmds'});
	foreach my $flavors_cmd (@flavors_cmds) {
		my $cmd = " $flavors_cmd\r";
		syswrite($shellfh, $cmd, length($cmd));
		}
	}

# Add additional shell init commands
if ($shinit && $shinit->{'cmds'}) {
	foreach my $cmd (@{$shinit->{'cmds'}}) {
		foreach my $shopt (keys %{$cmd}) {
			if ($shopt) {
				my $cmdopt = " @{[uc($shopt)]}='$cmd->{$shopt}'\r";
				syswrite($shellfh, $cmdopt, length($cmdopt));
				}
			}
		}
	}

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
