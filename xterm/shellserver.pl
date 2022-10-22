#!/usr/local/bin/perl
# Start a websocket server connected to a shell

BEGIN { push(@INC, ".."); };
use WebminCore;
use Net::WebSocket::Server;
&init_config();
my ($port, $user) = @ARGV;

# Switch to the user we're running as
my @uinfo = getpwnam($user);
if ($user ne "root" && $<) {
	@uinfo || die "User $user does not exist!";
	&switch_to_unix_user(@uinfo);
	}

# Run the user's shell in a sub-process
&foreign_require("proc");
our ($shellfh, $pid) = &proc::pty_process_exec($uinfo[8]);
$pid || die "Failed to run shell $uinfo[8]";
print STDERR "shell process is $pid\n";
 
$SIG{'ALRM'} = sub { die "timeout waiting for connection"; };
alarm(60);
print STDERR "listening on port $port\n";
our $wsconn;
our $shellbuf = "";
Net::WebSocket::Server->new(
    listen => $port,
    on_connect => sub {
        my ($serv, $conn) = @_;
	print STDERR "got websockets connection\n";
	$wsconn = $conn;
	alarm(0);
        $conn->on(
	    ready => sub {
                my ($conn) = @_;
		$conn->send_utf8($shellbuf) if ($shellbuf);
	    },
            utf8 => sub {
                my ($conn, $msg) = @_;
		if (!syswrite($shellfh, $msg, length($msg))) {
		  print STDERR "write to shell failed : $!\n";
		}
            },
	    disconnect => sub {
		print STDERR "websocket connection closed\n";
		kill('KILL', $pid) if ($pid);
		exit(0);
	    },
        );
    },
    watch_readable => [
	$shellfh => sub {
	  # Got something from the shell
	  my $buf;
	  my $ok = sysread($shellfh, $buf, 1);
	  exit(0) if ($ok <= 0);
	  if ($wsconn) {
	    $wsconn->send_utf8($buf);
	  } else {
	    $shellbuf .= $buf;
	  }
        },
    ],
)->start;
