# TLS transport shared by the fast RPC client and server.
package WebminRPC;
use strict;
use warnings;
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use Errno qw(EINTR);
# Use subsecond deadlines when Time::HiRes is available.
BEGIN { eval 'use Time::HiRes qw(time)'; }
use bytes;

# context([miniserv-config], [keyfile], [certfile])
# Create a client context, or a server context when miniserv-config is given.
# A server requires keyfile; certfile defaults to that same PEM file.
sub context
{
my ($config, $key, $cert) = @_;
eval { require Net::SSLeay; };
die "TLS RPC requires the Net::SSLeay Perl module\n" if ($@);
my $ctx = Net::SSLeay::CTX_new() or die "Cannot create RPC TLS context\n";
if ($config) {
	# Reject missing or mismatched files selected for the HTTPS connection.
	if (!$key ||
	    !Net::SSLeay::CTX_use_PrivateKey_file($ctx, $key, 1) ||
	    !Net::SSLeay::CTX_use_certificate_file($ctx, $cert || $key, 1) ||
	    !Net::SSLeay::CTX_check_private_key($ctx)) {
		Net::SSLeay::CTX_free($ctx);
		die "Cannot load the Webmin TLS certificate and key for RPC\n";
		}
	# Honor miniserv's protocol restrictions on the secondary listener.
	foreach my $option (qw(no_ssl2 no_ssl3 no_tls1 no_tls1_1 no_tls1_2)) {
		next if (!$config->{$option});
		my %names = ( no_ssl2 => 'OP_NO_SSLv2',
			      no_ssl3 => 'OP_NO_SSLv3',
			      no_tls1 => 'OP_NO_TLSv1',
			      no_tls1_1 => 'OP_NO_TLSv1_1',
			      no_tls1_2 => 'OP_NO_TLSv1_2' );
		my $constant = eval 'Net::SSLeay::'.$names{$option}.'()';
		# Older OpenSSL versions may not define every protocol option.
		Net::SSLeay::CTX_set_options($ctx, $constant)
			if (defined($constant));
		}
	# Apply the same cipher list to RPC and file connections as to HTTPS.
	if ($config->{'ssl_cipher_list'} &&
	    !Net::SSLeay::CTX_set_cipher_list($ctx, $config->{'ssl_cipher_list'})) {
		Net::SSLeay::CTX_free($ctx);
		die "Cannot apply the Webmin TLS cipher list to RPC\n";
		}
	}
return $ctx;
}

# fingerprint(ssl)
# Return the peer certificate's SHA-256 digest for comparison.
sub fingerprint
{
my ($ssl) = @_;
my $cert = Net::SSLeay::get_peer_certificate($ssl) or
	die "RPC TLS peer did not present a certificate\n";
my $digest = Net::SSLeay::X509_get_fingerprint($cert, "sha256");
Net::SSLeay::X509_free($cert);
die "Cannot fingerprint RPC TLS certificate\n" if (!$digest);
return $digest;
}

# retry(connection, result, [deadline])
# Wait for the I/O requested by the last SSL result. The deadline is an
# absolute time in seconds. Omitting it allows an unlimited wait.
sub retry
{
my ($con, $result, $deadline) = @_;
my $err = Net::SSLeay::get_error($con->{'ssl'}, $result);
die "RPC TLS connection closed or failed (SSL error $err)\n"
	if ($err != Net::SSLeay::ERROR_WANT_READ() &&
	    $err != Net::SSLeay::ERROR_WANT_WRITE());
while(1) {
	my $left = defined($deadline) ? $deadline - time() : undef;
	die "RPC TLS connection timed out\n"
		if (defined($left) && $left <= 0);
	my ($read, $write) = ('', '');
	if ($err == Net::SSLeay::ERROR_WANT_READ()) {
		# OpenSSL needs input, even if the caller was sending data.
		vec($read, fileno($con->{'fh'}), 1) = 1;
		}
	else {
		# OpenSSL needs output space, even if the caller was reading.
		vec($write, fileno($con->{'fh'}), 1) = 1;
		}
	# Retry signals without extending the original deadline.
	my $ready = select($read, $write, undef, $left);
	next if ($ready < 0 && $! == EINTR);
	die "RPC TLS connection timed out\n" if (!$ready);
	die "RPC TLS select failed : $!\n" if ($ready < 0);
	return;
	}
}

# start(socket, context, server, timeout, [peer-fingerprint], [hostname])
# Complete TLS before sending any RPC authentication or application data.
# server selects accept rather than connect. A zero or unset timeout uses 60s.
# Clients require the HTTPS peer fingerprint. hostname sets TLS SNI if given.
sub start
{
my ($fh, $ctx, $server, $timeout, $peer, $host) = @_;
my $con = { fh => $fh, timeout => $timeout || 60 };
$con->{'ssl'} = Net::SSLeay::new($ctx) or die "Cannot create RPC TLS session\n";
my $ok = eval {
	# Nonblocking I/O lets the handshake and later reads enforce deadlines.
	my $flags = fcntl($fh, F_GETFL, 0);
	defined($flags) && fcntl($fh, F_SETFL, $flags | O_NONBLOCK) or
		die "Cannot make RPC TLS socket nonblocking : $!\n";
	Net::SSLeay::set_fd($con->{'ssl'}, fileno($fh));
	Net::SSLeay::set_tlsext_host_name($con->{'ssl'}, $host) if ($host);
	# Both handshake directions share one deadline.
	my $deadline = time() + $con->{'timeout'};
	while(1) {
		Net::SSLeay::ERR_clear_error();
		my $rv = $server ? Net::SSLeay::accept($con->{'ssl'})
				 : Net::SSLeay::connect($con->{'ssl'});
		last if ($rv == 1);
		&retry($con, $rv, $deadline);
		}
	if (!$server && (!$peer || &fingerprint($con->{'ssl'}) ne $peer)) {
		# The secondary connection must present the HTTPS certificate.
		die "RPC TLS certificate differs from the HTTPS certificate\n";
		}
	1;
	};
if (!$ok) {
	# Release a failed handshake's socket and preserve its original error.
	my $err = $@;
	&close($con);
	die $err;
	}
return $con;
}

# read_data(connection, bytes)
# Read exactly this many bytes without consuming the following frame.
# Reset the connection's idle deadline whenever data arrives.
sub read_data
{
my ($con, $want) = @_;
my $deadline = time() + $con->{'timeout'};
my $buffer = '';
while(length($buffer) < $want) {
	Net::SSLeay::ERR_clear_error();
	my $size = $want - length($buffer);
	$size = 65536 if ($size > 65536);
	my ($data, $rv) = Net::SSLeay::read($con->{'ssl'}, $size);
	if (defined($data) && length($data)) {
		# Steady progress may take longer than one timeout in total.
		$buffer .= $data;
		$deadline = time() + $con->{'timeout'};
		}
	else {
		# Wait for more TLS data or report a closed connection.
		&retry($con, $rv, $deadline);
		}
	}
return $buffer;
}

# read_line(connection, [wait-for-command])
# Read a newline-terminated header of at most 4096 bytes. By default the
# timeout starts immediately. wait-for-command delays it until the first byte.
sub read_line
{
my ($con, $command) = @_;
my $line = '';
my $deadline = $command ? undef : time() + $con->{'timeout'};
while(length($line) < 4096) {
	# One-byte reads leave any following record in OpenSSL's pending buffer.
	Net::SSLeay::ERR_clear_error();
	my ($data, $rv) = Net::SSLeay::read($con->{'ssl'}, 1);
	if (defined($data) && length($data)) {
		# Keep one fixed deadline for the remaining header bytes.
		$deadline = time() + $con->{'timeout'} if (!defined($deadline));
		$line .= $data;
		return $line if ($data eq "\n");
		}
	else {
		# Wait without consuming any bytes from the next frame.
		&retry($con, $rv, $deadline);
		}
	}
die "RPC TLS header is too long\n";
}

# write_data(connection, data)
# Send the complete byte string, including after partial TLS writes.
sub write_data
{
my ($con, $data) = @_;
my $deadline = time() + $con->{'timeout'};
local $SIG{'PIPE'} = 'IGNORE';
my $chunk = '';
while(length($data)) {
	# Bound each write so steady progress can renew the idle deadline.
	# Keep the same buffer while OpenSSL asks us to retry it.
	$chunk = substr($data, 0, 65536) if (!length($chunk));
	Net::SSLeay::ERR_clear_error();
	my $rv = Net::SSLeay::write($con->{'ssl'}, $chunk);
	if (defined($rv) && $rv > 0) {
		# Remove only confirmed bytes and renew the idle deadline.
		substr($data, 0, $rv, '');
		substr($chunk, 0, $rv, '');
		$deadline = time() + $con->{'timeout'};
		}
	else {
		# Retry the unchanged chunk when OpenSSL is ready.
		&retry($con, $rv, $deadline);
		}
	}
}

# send_file(connection, filehandle, [&progress])
# Send chunks of up to 64 KiB, then close the source and send an end marker.
# Call progress with no arguments after each chunk, if supplied.
sub send_file
{
my ($con, $file, $progress) = @_;
while(1) {
	my $n = read($file, my $buf, 65536);
	die "RPC file read failed : $!\n" if (!defined($n));
	last if (!$n);
	&write_data($con, "$n\n".$buf);
	&$progress() if ($progress);
	}
# An end marker confirms that reading and closing the source both succeeded.
CORE::close($file) or die "RPC file close failed : $!\n";
&write_data($con, "0\n");
}

# receive_file(connection, filehandle, [&progress])
# Receive framed chunks into filehandle and close it at the end marker.
# Call progress with no arguments after each chunk, if supplied.
sub receive_file
{
my ($con, $file, $progress) = @_;
my $error;
while(1) {
	# Reject malformed, oversized or truncated chunks before accepting data.
	my $line = &read_line($con);
	die "RPC file transfer failed : $1\n" if ($line =~ /^ERROR (.*)/);
	die "Invalid RPC file chunk\n"
		if ($line !~ /^\d+\n$/ || $line > 65536);
	last if ($line == 0);
	my $buf = &read_data($con, int($line));
	# After a disk error, drain the data before reporting the failure.
	if (!$error && !print($file $buf)) {
		$error = "RPC file write failed : $!\n";
		}
	&$progress() if ($progress);
	}
# Closing can report buffered write errors. Preserve any earlier error.
CORE::close($file) or $error ||= "RPC file close failed : $!\n";
die $error if ($error);
}

# close(connection)
# Free only this process's TLS state. Never shut down an inherited socket.
sub close
{
my ($con) = @_;
Net::SSLeay::free(delete($con->{'ssl'})) if ($con->{'ssl'});
CORE::close($con->{'fh'}) if (defined(fileno($con->{'fh'})));
}

1;
