#!/usr/bin/perl
# Preserve the HTTP contract while extracting reusable TLS helpers.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use FindBin;
use Errno qw(EBADF EINVAL);

# An alternate source lets the same checks run against the original code.
require($ENV{'WEBMIN_SSL_SOURCE'} || "$FindBin::Bin/../web-lib-funcs.pl");

# Replace TLS and socket I/O so these checks need no workstation connections.
my ($context, $session, $connected) = (11, 22, 1);
my ($sni, $verification, $callback, @cas, @sent);
my @freed;
my $available = 1;
my $certificate_error;
local %main::gconfig;
local %main::text = ( link_essl => 'TLS module unavailable' );
local *main::is_readonly_mode = sub { 0 };
local *main::can_use_http_ssl = sub { $available };
local *main::open_socket = sub {
	# Use an in-memory handle without contacting the supplied address.
	no strict 'refs';
	open($_[2], '<', \my $empty) or die $!;
	return '192.0.2.1';
	};
local *Net::SSLeay::SSLeay_add_ssl_algorithms = sub { };
local *Net::SSLeay::OpenSSL_add_all_algorithms = sub { };
local *Net::SSLeay::load_error_strings = sub { };
local *Net::SSLeay::CTX_new = sub { $context };
local *Net::SSLeay::new = sub { $session };
# These test functions change $! and return false to check that TLS cleanup
# does not overwrite the filehandle's close result or error.
# Net::SSLeay::free(session): track requests to free a TLS session.
local *Net::SSLeay::free = sub {
	push(@freed, [ session => $_[0] ]);
	$! = EINVAL;
	return 0;
	};
# Net::SSLeay::CTX_free(context): track requests to free a TLS context.
local *Net::SSLeay::CTX_free = sub {
	push(@freed, [ context => $_[0] ]);
	$! = EINVAL;
	return 0;
	};
local *Net::SSLeay::CTX_load_verify_locations = sub { push(@cas, [ @_ ]); };
local *Net::SSLeay::VERIFY_PEER = sub { 1 };
local *Net::SSLeay::CTX_set_verify = sub { $callback = $_[2]; };
local *Net::SSLeay::set_fd = sub { };
local *Net::SSLeay::set_tlsext_host_name = sub { $sni = $_[1]; };
local *Net::SSLeay::connect = sub { $connected };
local *Net::SSLeay::write = sub {
	push(@sent, $_[1]);
	return bytes::length($_[1]);
	};
local *main::validate_ssl_connection = sub {
	$verification = [ @_ ];
	return $certificate_error;
	};

# request([requirements]): establish a synthetic HTTPS request and close it.
sub request
{
my ($requirements) = @_;
($sni, $verification, $callback, @cas, @sent) = ();
my $result = main::make_http_connection('remote.example', 443, 1,
	'GET', '/fixture', [ [ 'Host', 'remote.example' ] ], undef,
	$requirements);
if (ref($result)) {
	# The returned transport remains usable by existing HTTP callers.
	main::close_http_connection($result);
	}
return $result;
}

subtest 'HTTPS setup preserves hostname and request handling' => sub {
	my $result = request();
	is(ref($result), 'HASH', 'returns the existing connection hash');
	is($result->{'ip'}, '192.0.2.1', 'retains the connected address');
	is($sni, 'remote.example', 'SNI defaults to the connection hostname');
	ok(!defined($verification), 'no extra certificate checks by default');
	is_deeply(\@sent,
		[ "GET /fixture HTTP/1.0\r\nHost: remote.example\r\n\r\n" ],
		'the initial HTTP request is unchanged');
	my $reqs = { host => 'sni.example', checkhost => 'cert.example' };
	request($reqs);
	is($sni, 'sni.example', 'certificate host overrides SNI');
	is_deeply($verification, [ 22, 'cert.example', $reqs ],
		'certificate checks use the requested hostname');
	request({ host => 'sni.example', nocheckhost => 1 });
	ok(!defined($verification), 'nocheckhost still skips validation');
	};

subtest 'HTTPS setup failures preserve their original results' => sub {
	for my $case (
		[ \$available, 0, 'TLS module unavailable' ],
		[ \$context, 0, 'Failed to create SSL context' ],
		[ \$session, 0, 'Failed to create SSL connection' ],
		[ \$connected, 0, 'SSL connect() failed' ],
		[ \$certificate_error, 'fixture rejection',
		  'Invalid SSL certificate : fixture rejection' ]) {
		# Each failure must stop before HTTP application data is sent.
		my ($setting, $value, $expected) = @$case;
		my $original = $$setting;
		$$setting = $value;
		is(request({ host => 'remote.example' }), $expected,
			'original failure is returned');
		is_deeply(\@sent, [ ], 'no HTTP request follows a TLS failure');
		$$setting = $original;
		}
	# Bare library users may not have loaded the translated error message.
	local $main::text{'link_essl'};
	$available = 0;
	is(request(), undef, 'missing translated error still stops setup');
	$available = 1;
	};

# Check plain handles, complete TLS connections and partial TLS setup.
subtest 'HTTP close frees TLS state and preserves close results' => sub {
	for my $fields ({ }, { ssl_con => 22, ssl_ctx => 11 },
			{ ssl_ctx => 11 }) {
		open(my $fh, '<', \my $empty) or die $!;
		my $h = { fh => $fh, %$fields };
		@freed = ();
		# Expect cleanup only for TLS fields present in the handle.
		my @expected;
		push(@expected, [ session => 22 ]) if ($fields->{'ssl_con'});
		push(@expected, [ context => 11 ]) if ($fields->{'ssl_ctx'});
		ok(main::close_http_connection($h), 'returns successful close');
		ok(!defined(fileno($fh)), 'filehandle is closed');
		is_deeply(\@freed, \@expected, 'frees only the allocated TLS objects');
		ok(!exists($h->{'ssl_con'}) && !exists($h->{'ssl_ctx'}),
			'removes freed objects from the handle');
		# Repeated closes must not free the same objects again.
		ok(!main::close_http_connection($h), 'returns failed repeated close');
		is_deeply(\@freed, \@expected, 'TLS objects are freed only once');
		}
	# TLS cleanup must still run if the filehandle was already closed.
	open(my $fh, '<', \my $empty) or die $!;
	close($fh) or die $!;
	@freed = ();
	my $rv = main::close_http_connection(
		{ fh => $fh, ssl_con => 22, ssl_ctx => 11 });
	my $error = 0 + $!;
	ok(!$rv, 'TLS cleanup does not hide a close failure');
	is($error, EBADF, 'cleanup preserves the close error');
	is_deeply(\@freed, [ [ session => 22 ], [ context => 11 ] ],
		'close failure still releases the TLS objects');
	};

subtest 'CA settings and callback errors are preserved' => sub {
	my $reqs = { host => 'remote.example',
		capath => "$FindBin::Bin /fixture/ca.pem" };
	request($reqs);
	is_deeply(\@cas,
		[ [ 11, '', $FindBin::Bin ], [ 11, '/fixture/ca.pem', '' ] ],
		'loads CA directories and files');
	ok($callback, 'registers the certificate verification callback');
	my ($cert, $errnum, $message) = (33, 20, 'unknown issuer');
	local *Net::SSLeay::X509_STORE_CTX_get_current_cert = sub { $cert };
	local *Net::SSLeay::X509_STORE_CTX_get_error = sub { $errnum };
	local *Net::SSLeay::X509_verify_cert_error_string = sub { $message };
	local *Net::SSLeay::X509_get_issuer_name = sub { 44 };
	local *Net::SSLeay::X509_NAME_oneline = sub { 'fixture CA' };
	is($callback->(0, 55), 1, 'validation remains deferred to the caller');
	is($main::last_set_verify_err, ' unknown issuer',
		'preserves the OpenSSL error text');
	$message = '';
	$callback->(0, 55);
	is($main::last_set_verify_err,
		'Certificate is signed by an unknown CA : fixture CA (code 20)',
		'preserves the fallback issuer error');
	$errnum = 0;
	$callback->(1, 55);
	is($main::last_set_verify_err, undef,
		'verified certificate clears error');
	$cert = 0;
	$callback->(0, 55);
	is($main::last_set_verify_err,
		'Could not fetch CA certificate from server',
		'preserves the missing-certificate error');
	};

subtest 'TLS line and byte reads keep their existing buffer contract' => sub {
	my @input = ("fir", "st\nsecond\nbody", 'xy', '');
	my $reads = 0;
	local *Net::SSLeay::read = sub { $reads++; shift(@input) };
	my $h = { ssl_con => 22 };
	is(main::read_http_connection($h), "first\n", 'joins split lines');
	is(main::read_http_connection($h), "second\n", 'retains the next line');
	is($reads, 2, 'buffered lines need no further TLS read');
	is(main::read_http_connection($h, 2), 'body',
		'byte reads still return the whole existing buffer');
	is(main::read_http_connection($h, 10), 'xy',
		'unbuffered byte reads may return fewer bytes');
	is(main::read_http_connection($h, 10), undef, 'byte EOF returns undef');
	for my $buffer (undef, '', 'unfinished') {
		# Line EOF preserves the remaining buffer's value.
		my $eof = { ssl_con => 22, buffer => $buffer };
		local *Net::SSLeay::read = sub { '' };
		is(main::read_http_connection($eof), $buffer,
			'line EOF preserves the remaining buffered value');
		ok(!exists($eof->{'buffer'}), 'EOF consumes the buffer');
		}
	};

done_testing();
