#!/usr/bin/perl
# Exercise real RPC calls and file transfers against an isolated miniserv.
use strict;
use warnings;
no warnings qw(once redefine);
use JSON::PP qw(decode_json encode_json);
use Digest::SHA;
# Arguments select the source tree, private JSON settings and test case.
my ($root, $settings, $mode) = @ARGV;
open(my $json, '<', $settings) or die $!;
my $case = decode_json(do { local $/; <$json> });
close($json);
# Load the selected client as a Webmin module using the fixture environment.
chdir("$root/webmin") or die $!;
$0 = "$root/webmin/rpc-tls-client.pl";
unshift(@INC, $root);
require WebminCore;
WebminCore->import();
init_config();
# Capture fatal RPC errors in the JSON result instead of printing HTML.
$main::error_must_die = 1;
$main::remote_error_handler = sub { die $_[0]."\n"; };
my $s = $mode eq 'local' ? '' : $case->{'server'};
my %result;
my $ok = eval {
	# Establish a session and verify both a simple call and a large reply.
	remote_foreign_require($s, 'webmin');
	$result{'call'} = remote_eval($s, undef, '21 * 2');
	$result{'large_reply'} = length(remote_eval($s, undef, q{'x' x 1048576}));
	my $sn = remote_session_name($s);
	# Read transport state from the package used by WebminCore.
	no strict 'refs';
	my $cache = \%WebminCore::fast_fh_cache;
	$result{'tls'} = $cache->{$sn} && $cache->{$sn}->[2] ? 1 : 0;
	$result{'https'} = $WebminCore::remote_rpc_https{$sn} ? 1 : 0;
	if ($mode eq 'local') {
		# Inspect the address the listener is bound to.
		$result{'bind'} = remote_eval($s, undef,
			'Socket::inet_ntoa((Socket::unpack_sockaddr_in(getsockname(MAIN)))[1])');
		# Programs started by the worker must not inherit the local marker.
		$result{'marker'} = remote_eval($s, undef,
			q{exists($ENV{'FASTRPC_RUN_LOCAL'}) ? 1 : 0});
		# File sockets must use loopback even when the hash names a host.
		my $path = $case->{'path'};
		my $named = { id => 0, host => '192.0.2.1' };
		open(my $fh, '>', "$path/local-input") or die $!;
		print $fh 'local transfer';
		close($fh) or die $!;
		remote_write($named, "$path/local-input", "$path/local-remote");
		remote_read($named, "$path/local-output", "$path/local-remote");
		open($fh, '<', "$path/local-output") or die $!;
		$result{'local_copy'} = do { local $/; <$fh> };
		close($fh);
		}
	elsif ($mode eq 'files') {
		# Hash a multi-chunk binary payload and compare it after a round trip.
		my $path = $case->{'path'};
		my $input = "$path/input";
		open(my $fh, '>', $input) or die $!;
		binmode($fh);
		my $block = pack('C*', 0..255) x 256;
		print $fh $block for (1..($case->{'blocks'} || 32));
		close($fh) or die $!;
		# Exercise both file directions before comparing their hashes.
		$result{'upload'} = remote_write($s, $input, "$path/remote");
		remote_read($s, "$path/output", "$path/remote");
		for my $file (qw(input output)) {
			open($fh, '<', "$path/$file") or die $!;
			binmode($fh);
			$result{$file} = Digest::SHA->new(256)->addfile($fh)->hexdigest;
			close($fh);
			}
		$result{'after_transfer'} = remote_eval($s, undef, '6 * 7');
		# Zero-length files still require a valid end marker and acknowledgement.
		open($fh, '>', "$path/empty") or die $!;
		close($fh);
		remote_write($s, "$path/empty", "$path/empty-remote");
		remote_read($s, "$path/empty-output", "$path/empty-remote");
		$result{'empty'} = -z "$path/empty-output" ? 1 : 0;
		# Check automatic and requested temporary filenames.
		my $temp = remote_write($s, "$path/empty");
		$result{'temporary_name'} = -f $temp ? 1 : 0;
		my $named = remote_write($s, "$path/empty", undef, 'rpc-fixture.dat');
		$result{'base_name'} = -f $named && $named =~ /rpc-fixture\.dat$/ ? 1 : 0;
		}
	elsif ($mode eq 'rpc_errors') {
		# Exercise the old HTTPS worker's exception handling and list context.
		eval { remote_eval($s, undef, q{die "eval failure\n"}); };
		$result{'eval_die'} = $@;
		remote_eval($s, 'webmin', q{
			# rpc_fixture_die(): raise a Perl exception.
			sub rpc_fixture_die { die "call failure\n"; }
			# rpc_fixture_error(): call Webmin's error handler.
			sub rpc_fixture_error { &error("module failure"); }
			# rpc_fixture_values(value): return undef, zero
			# and the argument.
			sub rpc_fixture_values { return (undef, 0, $_[0]); }
			# rpc_fixture_context(): report scalar or list context.
			sub rpc_fixture_context { wantarray ? 'list' : 'scalar'; }
			1;
			});
		# Both error paths must leave the session usable.
		for my $kind (qw(die error)) {
			eval { remote_foreign_call($s, 'webmin', "rpc_fixture_$kind"); };
			$result{"call_$kind"} = $@;
			}
		$result{'values'} = [ remote_foreign_call($s, 'webmin',
			'rpc_fixture_values', "quote'\\\n") ];
		$result{'context'} = remote_foreign_call($s, 'webmin', 'rpc_fixture_context');
		$result{'eval_context'} = remote_eval($s, undef, q{wantarray ? 'list' : 'scalar'});
		if ($result{'https'}) {
			# Catch module loading errors over HTTPS too.
			eval { remote_foreign_require($s, 'rpc-fixture-missing'); };
			$result{'require_error'} = $@;
			}
		$result{'after_rpc_errors'} = remote_eval($s, undef, '6 * 7');
		}
	elsif ($mode eq 'password_change') {
		# Existing sessions stay authenticated when the caller updates a password.
		$s->{'pass'} = 'changed-after-authentication';
		$result{'after_password_change'} = remote_eval($s, undef, '6 * 7');
		}
	elsif ($mode eq 'slow_write') {
		# A slow reader keeps making progress beyond one idle timeout.
		require IO::Socket::INET;
		my $socket = IO::Socket::INET->new(PeerAddr => '127.0.0.1',
			PeerPort => $s->{'throttle_port'}) or die $!;
		# Keep backpressure predictable across different kernel buffer sizes.
		setsockopt($socket, Socket::SOL_SOCKET(), Socket::SO_SNDBUF(),
			pack('i', 65536)) or die $!;
		my $ctx = WebminCore::rpc_tls_context();
		my $con = WebminCore::rpc_tls_start($socket, $ctx, 0, 5,
			$cache->{$sn}->[2]->{'peer'}, 'localhost');
		Net::SSLeay::CTX_free($ctx);
		# A progressing write may take longer than five seconds.
		WebminCore::write_ssl_connection($con, 'x' x (8 * 1024 * 1024));
		$con->{'timeout'} = 30;
		$result{'slow_reply'} = WebminCore::read_ssl_connection($con);
		WebminCore::rpc_tls_close($con);
		}
	elsif ($mode eq 'upgrade') {
		# Use Cluster Webmin's upload + remote setup sequence on a tar install.
		my $package = remote_write($s, $case->{'package'});
		my $extract = $case->{'extract'};
		my $boot = $case->{'boot'};
		# Install only into the fixture tree, without starting or
		# stopping Webmin.
		$result{'installer'} = remote_eval($s, undef, qq{
			mkdir('$extract', 0700) or die \$!;
			system('tar', '-xzf', '$package', '-C', '$extract') == 0 or die 'tar failed';
			\$ENV{'config_dir'} = \$config_directory;
			\$ENV{'webmin_upgrade'} = 1;
			\$ENV{'autothird'} = 1;
			\$ENV{'bootscript'} = '$boot';
			\$ENV{'nostop'} = \$ENV{'nostart'} = \$ENV{'nopostinstall'} = 1;
			\$ENV{'noperlpath'} = 1;
			\$ENV{'tempdir'} = '$extract/tmp';
			mkdir(\$ENV{'tempdir'}, 0700);
			my \$out = `cd '$extract/webmin-2.671.999' && sh setup.sh </dev/null 2>&1`;
			my \$exit = \$? >> 8;
			unlink('$package');
			[ \$exit, \$out ];
			});
		# Recheck the peer's capabilities after upgrading it.
		remote_finished();
		$result{'fallback_cleared'} = %WebminCore::remote_rpc_https ? 0 : 1;
		}
	elsif ($mode eq 'handshake') {
		# A peer accepting TCP but never speaking TLS must not hang a caller.
		require IO::Socket::INET;
		my $listener = IO::Socket::INET->new(LocalAddr => '127.0.0.1',
			LocalPort => 0, Listen => 1, ReuseAddr => 1) or die $!;
		my $port = $listener->sockport();
		my $pid = fork();
		die $! if (!defined($pid));
		if (!$pid) {
			# Accept TCP and leave the TLS handshake unanswered.
			my $accepted = $listener->accept();
			sleep(5);
			POSIX::_exit(0);
			}
		# Use a short handshake timeout, then stop the child.
		my $socket = IO::Socket::INET->new(PeerAddr => '127.0.0.1',
			PeerPort => $port) or die $!;
		my $ctx = WebminCore::rpc_tls_context();
		eval { WebminCore::rpc_tls_start($socket, $ctx, 0, 0.2, 'unused'); };
		$result{'handshake_timeout'} = $@;
		Net::SSLeay::CTX_free($ctx);
		close($listener);
		kill('TERM', $pid);
		waitpid($pid, 0);
		}
	elsif ($mode eq 'wrong_secondary') {
		# Only this RPC worker's new file sockets present a different cert.
		my ($key, $cert, $path) = @{$case}{qw(other_key other_cert path)};
		remote_eval($s, undef,
			"\$tls_ctx = WebminCore::rpc_tls_context(\\%miniserv, '$key', '$cert'); 1;");
		open(my $fh, '>', "$path/data") or die $!;
		print $fh 'must not be sent';
		close($fh);
		# Reject the certificate before creating the remote file.
		eval { remote_write($s, "$path/data", "$path/remote"); };
		$result{'certificate_error'} = $@;
		$result{'file_created'} = -e "$path/remote" ? 1 : 0;
		$result{'after_mismatch'} = remote_eval($s, undef, '6 * 7');
		}
	elsif ($mode eq 'interruptions') {
		# Break a transfer child after sending data, leaving the parent alive.
		my $path = $case->{'path'};
		open(my $fh, '>', "$path/data") or die $!;
		print $fh 'x' x 131072;
		close($fh);
		remote_eval($s, undef, q{
			$main::saved_sender = \&main::rpc_tls_send_file;
			# send_file(connection, file): send a chunk
			# without its end marker.
			*main::rpc_tls_send_file = sub {
				WebminCore::write_ssl_connection($_[0], "3\nabc");
				POSIX::_exit(0);
				}; 1;
			});
		eval { remote_read($s, "$path/output", "$path/data"); };
		$result{'truncated'} = $@;
		# Restore downloads, then suppress the upload's final reply.
		remote_eval($s, undef, q{
			*main::rpc_tls_send_file = $main::saved_sender;
			$main::saved_receiver = \&main::rpc_tls_receive_file;
			# receive_file(connection, file): finish the write,
			# then exit early.
			*main::rpc_tls_receive_file = sub {
				$main::saved_receiver->(@_);
				POSIX::_exit(0);
				}; 1;
			});
		eval { remote_write($s, "$path/data", "$path/remote"); };
		$result{'missing_ack'} = $@;
		# Restore the worker and check that control calls still work.
		remote_eval($s, undef,
			'*main::rpc_tls_receive_file = $main::saved_receiver; 1;');
		$result{'after_interruptions'} = remote_eval($s, undef, '6 * 7');
		}
	elsif ($mode eq 'timeout') {
		# A timed-out call must not be replayed after it has already run.
		my $marker = $case->{'path'}."/executions";
		eval {
			local $SIG{'ALRM'} = sub { die "RPC caller timed out\n"; };
			alarm(1);
			remote_eval($s, undef,
				"open(my \$fh, '>>', '$marker'); print \$fh qq(x); ".
				"close(\$fh); sleep(5); 1;");
			};
		$result{'timeout'} = $@;
		alarm(0);
		# One marker byte proves the timed-out request was not replayed.
		open(my $fh, '<', $marker) or die $!;
		$result{'executions'} = do { local $/; <$fh> };
		close($fh);
		}
	elsif ($mode eq 'errors') {
		# Both local and remote disk errors must reach the caller.
		my $path = $case->{'path'};
		open(my $fh, '>', "$path/data") or die $!;
		print $fh 'x' x 131072;
		close($fh);
		eval { remote_write($s, "$path/data", '/dev/full'); };
		$result{'remote_full'} = $@;
		eval { remote_write($s, "$path/data", "$path/missing/file"); };
		$result{'unwritable'} = $@;
		eval { remote_read($s, '/dev/full', "$path/data"); };
		$result{'local_full'} = $@;
		# A missing source must leave the local file intact.
		open(my $existing, '>', "$path/missing-output") or die $!;
		print $existing 'preserved';
		close($existing);
		eval { remote_read($s, "$path/missing-output", "$path/missing"); };
		$result{'missing'} = $@;
		open($existing, '<', "$path/missing-output") or die $!;
		$result{'preserved'} = do { local $/; <$existing> };
		close($existing);
		$result{'after_errors'} = remote_eval($s, undef, '6 * 7');
		}
	1;
	};
# Always attempt session cleanup, retaining the case's original error.
$result{'error'} = $@ if (!$ok);
eval { remote_finished(); };
print encode_json(\%result), "\n";
