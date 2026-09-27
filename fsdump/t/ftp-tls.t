#!/usr/bin/perl
# Regression test for explicit FTP TLS servers that require login before
# accepting PBSZ and PROT, and TLS session reuse on the data connection.

use strict;
use warnings;
use Test::More;
use File::Copy qw(copy);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;
use IO::Socket::INET;
use IPC::Open3;
use Symbol qw(gensym);

BEGIN {
	eval {
		require IO::Socket::SSL;
		require IO::Socket::SSL::Utils;
		IO::Socket::SSL::Utils->import(
			qw(CERT_create CERT_free KEY_free
			   PEM_cert2file PEM_key2file));
		1;
		} or plan skip_all => 'IO::Socket::SSL test modules are unavailable';
}

my $tmp = tempdir(CLEANUP => 1);
my $client_script = File::Spec->catfile($tmp, 'ftp.pl');
copy(File::Spec->catfile($FindBin::Bin, '..', 'ftp.pl'), $client_script) or
	die "copy ftp.pl: $!";

# Supply only the socket and FTP response helpers needed by ftp.pl.
my $stub = File::Spec->catfile($tmp, 'fsdump-lib.pl');
open(my $STUB, '>', $stub) or die "open $stub: $!";
print $STUB <<'PERL';
use IO::Socket::INET;

sub open_socket
{
my ($host, $port, $name, $err) = @_;
my $socket = IO::Socket::INET->new(
	PeerAddr => $host,
	PeerPort => $port == 21 ? $ENV{'FSDUMP_TEST_FTP_PORT'} : $port,
	Proto => 'tcp');
if (!$socket) {
	$$err = $!;
	return undef;
	}
no strict 'refs';
*{'main::'.$name} = $socket;
return $host;
}

sub ftp_command
{
my ($command, $expected, $err, $name) = @_;
$name ||= 'SOCK';
no strict 'refs';
my $handle = \*{'main::'.$name};
print $handle "$command\r\n" if ($command ne '');
my $line = <$handle>;
if (!defined($line) || $line !~ /^(\d{3})[ -](.*?)(?:\r?\n)?$/) {
	$$err = 'Failed to read FTP reply';
	return undef;
	}
my ($code, $reply) = ($1, $2);
my @expected = ref($expected) ? @$expected : ($expected);
if (!grep { int($code / 100) == $_ } @expected) {
	$$err = "$command failed : $reply";
	return undef;
	}
return wantarray ? ($reply, $code) : $reply;
}

1;
PERL
close($STUB) or die "close $stub: $!";

# Create a temporary self-signed certificate for both TLS channels.
my ($cert, $key) = CERT_create(
	subject => { commonName => '127.0.0.1' },
	purpose => 'server');
my $cert_file = File::Spec->catfile($tmp, 'cert.pem');
my $key_file = File::Spec->catfile($tmp, 'key.pem');
PEM_cert2file($cert, $cert_file);
PEM_key2file($key, $key_file);
CERT_free($cert);
KEY_free($key);

# Use one TLS context for both server connections so session reuse can be
# required and observed on the data connection.
my $server_context = IO::Socket::SSL::SSL_Context->new(
	SSL_server => 1,
	SSL_version => 'TLSv1_2',
	SSL_cert_file => $cert_file,
	SSL_key_file => $key_file,
	SSL_session_id_context => 'fsdump-ftps-test') or
	die "server TLS context: ".IO::Socket::SSL::errstr()."\n";

my $listener = IO::Socket::INET->new(
	LocalAddr => '127.0.0.1',
	LocalPort => 0,
	Proto => 'tcp',
	Listen => 1,
	ReuseAddr => 1) or die "listen: $!";
my $port = $listener->sockport();
my $log_file = File::Spec->catfile($tmp, 'server.log');
my $data_file = File::Spec->catfile($tmp, 'backup.tar');
my $server_pid = fork();
defined($server_pid) or die "fork: $!";
if (!$server_pid) {
	eval {
		local $SIG{'ALRM'} = sub { die "server timeout\n" };
		alarm(15);
		my $socket = $listener->accept() or die "accept: $!";
		$socket->autoflush(1);
		my @commands;
		print $socket "220 test server\r\n";
		my $line = <$socket>;
		$line =~ s/\r?\n$//;
		push(@commands, $line);
		$line eq 'AUTH TLS' or die "expected AUTH TLS, got $line\n";
		print $socket "234 start TLS\r\n";
		$socket = IO::Socket::SSL->start_SSL(
			$socket,
			SSL_server => 1,
			SSL_reuse_ctx => $server_context) or
			die "server TLS: ".IO::Socket::SSL::errstr()."\n";
		$socket->autoflush(1);

		# Rejecting PBSZ here models servers that require authentication
		# first; the client must send USER and PASS before protection setup.
		foreach my $step (
			[ qr/^USER /, "331 password required\r\n" ],
			[ qr/^PASS /, "230 logged in\r\n" ],
			[ qr/^PBSZ 0$/, "200 buffer size set\r\n" ],
			[ qr/^PROT P$/, "200 private data channel\r\n" ],
			[ qr/^TYPE I$/, "200 binary mode\r\n" ]) {
			$line = <$socket>;
			defined($line) or die "connection closed early\n";
			$line =~ s/\r?\n$//;
			push(@commands, $line);
			$line =~ $step->[0] or
					die "unexpected command $line\n";
			print $socket $step->[1];
			}

		# Accept a protected passive upload and require it to reuse the
		# control connection's TLS session, as strict FTPS servers do.
		my $data_listener = IO::Socket::INET->new(
			LocalAddr => '127.0.0.1',
			LocalPort => 0,
			Proto => 'tcp',
			Listen => 1,
			ReuseAddr => 1) or die "data listen: $!";
		my $data_port = $data_listener->sockport();
		$line = <$socket>;
		defined($line) or die "connection closed before PASV\n";
		$line =~ s/\r?\n$//;
		push(@commands, $line);
		$line eq 'PASV' or die "expected PASV, got $line\n";
		print $socket "227 Entering Passive Mode (127,0,0,1,".
			int($data_port / 256).",".($data_port % 256).")\r\n";
		my $data_socket = $data_listener->accept() or die "data accept: $!";
		close($data_listener);

		$line = <$socket>;
		defined($line) or die "connection closed before STOR\n";
		$line =~ s/\r?\n$//;
		push(@commands, $line);
		$line eq 'STOR /backup.tar' or die "expected STOR, got $line\n";
		print $socket "150 opening data connection\r\n";
		$data_socket = IO::Socket::SSL->start_SSL(
			$data_socket,
			SSL_server => 1,
			SSL_reuse_ctx => $server_context) or
			die "server data TLS: ".IO::Socket::SSL::errstr()."\n";
		$data_socket->get_session_reused() or
			die "data TLS session was not reused\n";
		push(@commands, 'DATA SESSION REUSED');

		my $received = '';
		while(1) {
			my $read = read($data_socket, my $chunk, 8192);
			defined($read) or die "data read: $!";
			last if (!$read);
			$received .= $chunk;
			}
		close($data_socket);
		open(my $DATA, '>', $data_file) or die "open data: $!";
		print $DATA $received;
		close($DATA) or die "close data: $!";
		print $socket "226 transfer complete\r\n";

		$line = <$socket>;
		defined($line) or die "connection closed before QUIT\n";
		$line =~ s/\r?\n$//;
		push(@commands, $line);
		$line eq 'QUIT' or die "expected QUIT, got $line\n";
		print $socket "221 goodbye\r\n";
		open(my $LOG, '>', $log_file) or die "open log: $!";
		print $LOG join("\n", @commands), "\n";
		close($LOG) or die "close log: $!";
		alarm(0);
		1;
		} or do {
		my $error = $@ || 'unknown server error';
		open(my $LOG, '>', $log_file) or exit(2);
		print $LOG "ERROR: $error";
		close($LOG);
		exit(1);
		};
	exit(0);
	}
close($listener);

local $ENV{'DUMP_PASSWORD'} = 'test-password';
local $ENV{'FSDUMP_TEST_FTP_PORT'} = $port;
my $stderr = gensym();
my $old_cwd = File::Spec->rel2abs('.');
chdir($tmp) or die "chdir $tmp: $!";
my $client_pid = open3(my $input, my $output, $stderr, $^X,
	$client_script, '127.0.0.1', 'unused', 'test-user', 'touch');
my $payload = "protected backup data\n";
print $input "O/backup.tar\n64\nW".length($payload)."\n$payload"."C\n";
close($input);
my $client_output = do { local $/; <$output> };
my $client_error = do { local $/; <$stderr> };
waitpid($client_pid, 0);
my $client_status = $?;
chdir($old_cwd) or die "chdir $old_cwd: $!";

waitpid($server_pid, 0);
my $server_status = $?;
open(my $LOG, '<', $log_file) or die "open $log_file: $!";
my $server_log = do { local $/; <$LOG> };
close($LOG);

is($client_status, 0, 'FTP helper completes the protected control session') or
	diag($client_error);
is($server_status, 0, 'mock FTPS server accepts the command sequence') or
	diag($server_log);
is($server_log,
	"AUTH TLS\nUSER test-user\nPASS test-password\nPBSZ 0\n".
	"PROT P\nTYPE I\nPASV\nSTOR /backup.tar\n".
	"DATA SESSION REUSED\nQUIT\n",
	'login precedes protection and the data TLS session is reused');
is($client_output, "A0\nA".length($payload)."\nA0\n",
	'rmt protocol receives open, write and close success');
open(my $DATA, '<', $data_file) or die "open received data: $!";
my $received = do { local $/; <$DATA> };
close($DATA);
is($received, $payload, 'protected data reaches the FTP server intact');

done_testing();
