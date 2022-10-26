#!/usr/local/bin/perl
# Start a websocket server connected to a shell

require './xterm-lib.pl';

use Net::WebSocket::Server;
my ($port, $user) = @ARGV;

# Switch to the user we're running as
my @uinfo = getpwnam($user);
my ($uid, $gid);
if ($user ne "root" && !$<) {
	@uinfo || die "User $user does not exist!";
	$uid = $uinfo[2];
	$gid = $uinfo[3];
	}
else {
	$uid = $gid = 0;
	}

# Run the user's shell in a sub-process
&foreign_require("proc");
$ENV{'TERM'} = 'xterm-256color';
chdir($uinfo[7] || "/");
our ($shellfh, $pid) = &proc::pty_process_exec($uinfo[8], $uid, $gid);
$pid || die "Failed to run shell $uinfo[8]";
print STDERR "shell process is $pid\n";

$SIG{'ALRM'} = sub { die "timeout waiting for connection"; };
alarm(60);
print STDERR "listening on port $port\n";
our $wsconn;
our $shellbuf = "";
Net::WebSocket::Server->new(
    listen     => $port,
    on_connect => sub {
        my ($serv, $conn) = @_;
        print STDERR "got websockets connection\n";
        if ($wsconn) {
            print STDERR "Too many connections to the same port!\n";
            &cleanup_miniserv();
            kill('KILL', $pid) if ($pid);
            exit(1);
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
                if (!syswrite($shellfh, $msg, length($msg))) {
                    print STDERR "write to shell failed : $!\n";
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
            my $ok = sysread($shellfh, $buf, 1);
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

sub cleanup_miniserv
{
my %miniserv;
&get_miniserv_config(\%miniserv);
my $wspath = "/$module_name/ws-".$port;
delete($miniserv{'websockets_'.$wspath});
&put_miniserv_config(\%miniserv);
&reload_miniserv();
}
