#!/usr/bin/perl
# Test transfer child failures without opening network connections.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;

our ($port, $use_ipv6, $sid, %xfer_kids);
my $config_rpc_timeout = 1;
my ($tls_ctx, $tls_con);
my ($failure, $events);

# accept(socket, listener): skip the network accept in the loaded function.
use subs qw(accept);
sub accept { return 1; }

# allocate_socket(handle, ipv6_handle, port_ref): supply a readable handle
# so the child reaches the mocked handshake without a network listener.
sub allocate_socket
{
open($_[0], '<', __FILE__) or die $!;
return undef;
}

# rpc_tls_start(socket, context, server, timeout): fail before a connection
# exists, or return a fake transfer connection.
sub rpc_tls_start
{
die "Handshake failed\n" if ($failure eq 'handshake');
return { transfer => 1 };
}

# read_ssl_connection(connection): accept the fixture's session token.
sub read_ssl_connection { return "$sid\n"; }

# write_ssl_connection(connection, data): record replies or fail while
# reporting the original transfer error.
sub write_ssl_connection
{
my ($con, $data) = @_;
if ($data =~ /^ERROR / && $failure eq 'reply') {
	die "Error reply failed\n";
	}
print $events $data;
return 1;
}

# rpc_tls_receive_file(connection, file): close the destination and simulate
# a completed transfer or a file error.
sub rpc_tls_receive_file
{
close($_[1]) or die $!;
die "File transfer failed\nSecond line\n" if ($failure);
}

# rpc_tls_send_file(connection, file): use the same cases for downloads.
sub rpc_tls_send_file { return rpc_tls_receive_file(@_); }

# rpc_tls_close(connection): record cleanup of the transfer connection.
sub rpc_tls_close
{
print $events "CLOSED\n" if ($_[0] && $_[0]->{'transfer'});
}

# Load the actual function, leaving the CGI startup and worker loop untouched.
open(my $script, '<', "$FindBin::Bin/../fastrpc.cgi") or die $!;
my $source = do { local $/; <$script> };
close($script);
my ($transfer) = $source =~ /^(sub tls_transfer\n\{.*?^\})/ms;
die 'Cannot find tls_transfer' if (!$transfer);
eval $transfer;
die $@ if ($@);

my $dir = tempdir(CLEANUP => 1);
$sid = 'fixture-session';
$port = 10000;
$use_ipv6 = 0;
for my $action ('tcpwrite', 'tcpread') {
	for my $case ('success', 'file', 'reply', 'handshake') {
		subtest "$action / $case" => sub {
			# Give each child its own output, log and cleanup trace.
			$failure = $case eq 'success' ? '' : $case;
			%xfer_kids = ();
			my $file = "$dir/data";
			open(my $data, '>', $file) or die $!;
			print $data 'fixture';
			close($data);
			open($events, '>', "$dir/events") or die $!;
			my ($result, $pid, $status);
			{
				# Capture the child's STDERR and exit status.
				local *STDERR;
				open(STDERR, '>', "$dir/errors") or die $!;
				$result = tls_transfer({ action => $action,
							 file => $file });
				($pid) = keys %xfer_kids;
				die 'Transfer child did not start' if (!$pid);
				waitpid($pid, 0) == $pid or die $!;
				$status = $?;
			}
			close($events);
			open(my $log, '<', "$dir/errors") or die $!;
			my $errors = do { local $/; <$log> };
			close($log);
			open(my $trace, '<', "$dir/events") or die $!;
			my $output = do { local $/; <$trace> };
			close($trace);
			is($result->{'status'}, 1, 'parent starts transfer');
			is($status, $failure ? 256 : 0, 'child exit status');
			if (!$failure) {
				# Success stays quiet and confirms completion.
				is($errors, '', 'no error is logged');
				my $expected = $action eq 'tcpwrite'
					? "OK\nOK\nCLOSED\n" : "OK\nCLOSED\n";
				is($output, $expected, 'reply and cleanup');
				}
			elsif ($failure eq 'handshake') {
				# Also log errors from TLS setup.
				like($errors,
					qr/TLS file transfer failed: Handshake failed\n/,
					'handshake error is logged');
				is($output, '', 'no reply without connection');
				}
			else {
				# Retain both errors if the reply also fails.
				like($errors,
					qr/TLS file transfer failed: File transfer failed\nSecond line\n/,
					'original error is logged');
				if ($failure eq 'reply') {
					like($errors,
						qr/Error reply failed: Error reply failed\n/,
						'logs the failed error reply');
					}
				else {
					like($output,
						qr/^ERROR File transfer failed Second line \n/m,
						'one error line for the client');
					unlike($errors, qr/Error reply failed/,
						'no error from a sent reply');
					}
				like($output, qr/CLOSED\n\z/,
					'connection is cleaned up');
				}
			};
		}
	}

done_testing();
