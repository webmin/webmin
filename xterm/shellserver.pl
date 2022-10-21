#!/usr/local/bin/perl
# Start a websocket server connected to a shell

BEGIN { push(@INC, ".."); };
use WebminCore;
use Net::WebSocket::Server;
&init_config();

my ($port, $user) = @ARGV;
if ($user ne "root" && $<) {
	my @uinfo = getpwnam($user);
	@uinfo || die "User $user does not exist!";
	&switch_to_unix_user(@uinfo);
	}
 
$SIG{'ALRM'} = sub { die "timeout waiting for connection"; };
alarm(60);
print STDERR "listening on port $port\n";
Net::WebSocket::Server->new(
    listen => $port,
    on_connect => sub {
        my ($serv, $conn) = @_;
	print STDERR "got connection\n";
	alarm(0);
        $conn->on(
            utf8 => sub {
                my ($conn, $msg) = @_;
                $conn->send_utf8($msg);
            },
	    disconnect => sub {
		exit(0);
	    },
        );
    },
)->start;
