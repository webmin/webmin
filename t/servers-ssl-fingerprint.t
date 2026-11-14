#!/usr/bin/perl
# Check certificate pins for linked pages, RPC and websocket connections
# without opening sockets on the workstation.
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/..";
use WebminCore;
use Test::More;
our (%access, %in);
# Load server helpers without reading installed Webmin configuration.
{
	no warnings qw(redefine once);
	# import([args...]) suppresses module initialization on the second load.
	local *WebminCore::import = sub { };
	# init_config([args...]) leaves this fixture's configuration in memory.
	local *main::init_config = sub { };
	# get_module_acl() grants access to the synthetic server records.
	local *main::get_module_acl = sub { (servers => '*', links => 1) };
	require "$Bin/../servers/servers-lib.pl";
}
require "$Bin/../miniserv-lib.pl";

my $pinned = 'ab' x 32;
my $other = 'cd' x 32;
# Net::SSLeay reports fingerprints as upper-case hex pairs joined by colons.
my $presented;
{
	no warnings qw(redefine once);
	# get_peer_certificate(ssl) returns a placeholder for the fixture peer.
	*Net::SSLeay::get_peer_certificate = sub { 'certificate' };
	# X509_free(cert) needs no cleanup for the placeholder certificate.
	*Net::SSLeay::X509_free = sub { };
	# X509_get_fingerprint(cert, digest) formats the fixture digest.
	*Net::SSLeay::X509_get_fingerprint = sub {
		# Require the production checker to request SHA-256.
		die "Unexpected digest\n" if ($_[1] ne 'sha256');
		return defined($presented)
			? join(':', map { uc } $presented =~ /(..)/g) : undef;
		};
	# X509_get_subject_name(cert) returns the fixture subject placeholder.
	*Net::SSLeay::X509_get_subject_name = sub { 'subject' };
	# X509_NAME_oneline(subject) supplies the HTTP checker's common name.
	*Net::SSLeay::X509_NAME_oneline = sub { '/CN=guest.test' };
	# X509_NAME_get_text_by_NID(subject, nid) supplies the websocket name.
	*Net::SSLeay::X509_NAME_get_text_by_NID = sub { 'guest.test' };
	# X509_get_subjectAltNames(cert) returns no alternative names.
	*Net::SSLeay::X509_get_subjectAltNames = sub { ( ) };
}

# Normalize stored pins while distinguishing optional and required values.
is(server_ssl_fingerprints({ }), '', 'a server without the field has no pin');
is(server_ssl_fingerprints({ sslfingerprint => ' ' }), '',
   'a blank field has no pin');
is(server_ssl_fingerprints({ sslfingerprint =>
	join(':', map { uc } $pinned =~ /(..)/g).", $other" }),
   "$pinned,$other", 'colons, case and spaces are normalized');
is(server_ssl_fingerprints({ sslfingerprint => 'zzz' }), 'invalid',
   'an unusable value still requires a match that cannot succeed');
unlike(server_ssl_fingerprints({ sslfingerprint => "$pinned user=root x=1" }),
       qr/[=\s]/, 'extra text cannot add websocket route options');
is(server_ssl_fingerprints({ cloudmin_uuid => 'fixture' }), 'invalid',
   'a Cloudmin guest without a saved pin cannot disable verification');
is(server_ssl_fingerprints({ cloudmin_uuid => 'fixture',
			    sslfingerprint => ' ' }), 'invalid',
   'a blank pin cannot disable verification for a Cloudmin guest');

# The page proxy passes the fingerprints with the hostname check turned off.
my $reqs = { host => 'other.test', nocheckhost => 1, fingerprint => $pinned };
$presented = $pinned;
is(validate_ssl_connection('ssl', 'other.test', $reqs), undef,
   'the pinned certificate is accepted without a hostname match');
$reqs->{'fingerprint'} = "$other,$pinned";
is(validate_ssl_connection('ssl', 'other.test', $reqs), undef,
   'any of several pinned certificates is accepted');
# A mismatch or missing digest must fail even when hostname checks are off.
$presented = $other;
$reqs->{'fingerprint'} = $pinned;
like(validate_ssl_connection('ssl', 'other.test', $reqs), qr/fingerprint/,
     'another certificate is rejected');
$presented = undef;
like(validate_ssl_connection('ssl', 'other.test', { %$reqs, fingerprint => ',' }),
     qr/fingerprint/, 'a certificate with no fingerprint never matches');

# A requested hostname check still applies to a pinned certificate.
$presented = $pinned;
like(validate_ssl_connection('ssl', 'other.test',
			     { host => 'other.test', fingerprint => $pinned }),
     qr/not other\.test/, 'the hostname check is kept when requested');
is(validate_ssl_connection('ssl', 'other.test',
			   { host => 'other.test', nocheckhost => 1 }),
   undef, 'no pin and no hostname check accepts any certificate as before');

# The websocket proxy applies the same comparison to its own connection.
is(miniserv::check_websocket_backend_ssl('ssl', undef, "$other,$pinned"), undef,
   'websocket backend with a pinned certificate is accepted');
like(miniserv::check_websocket_backend_ssl('ssl', undef, $other), qr/fingerprint/,
   'websocket backend with another certificate is rejected');
# Websocket hostname checks remain independent of the pin result.
is(miniserv::check_websocket_backend_ssl('ssl', 'guest.test', $pinned), undef,
   'websocket backend can satisfy both hostname and pin checks');
like(miniserv::check_websocket_backend_ssl('ssl', 'other.test', $pinned),
     qr/not other\.test/, 'a matching websocket pin cannot bypass a hostname check');
$presented = undef;
like(miniserv::check_websocket_backend_ssl('ssl', undef, ','), qr/fingerprint/,
   'websocket backend with no fingerprint never matches');

# A required pin must reject plain HTTP before any connection is opened.
{
	no warnings qw(redefine once);
	# open_socket(args...) fails if refusal happens after opening a socket.
	local *WebminCore::open_socket = sub { die "Unexpected connection\n" };
	like(make_http_connection('guest.test', 10000, 0, 'GET', '/',
		undef, undef, { fingerprint => $pinned }), qr/SSL is required/,
	     'a pinned HTTP connection cannot bypass TLS');
	}

# RPC must pass the same pin and keep pinned sessions off the plain fast port.
{
	no warnings qw(redefine once);
	local *servers::server_ssl_fingerprints = \&server_ssl_fingerprints;
	# foreign_require(module, [file]) skips helpers already loaded here.
	local *WebminCore::foreign_require = sub { };
	# foreign_config(module) supplies the configured CA path for assertions.
	local *WebminCore::foreign_config = sub { (capath => '/fixture/ca') };
	# remote_error_handler(message) returns the expected fixture refusal.
	local $main::remote_error_handler = sub { $_[0] };
	my @connection;
	# make_http_connection(args...) records the transport and TLS options.
	local *WebminCore::make_http_connection = sub {
		@connection = @_;
		return 'fixture connection stopped';
		};
	# Exercise pin requirements, fast RPC selection and explicit CA checks.
	for my $case (
		[ 'pinned', { sslfingerprint => $pinned }, '/rpc.cgi', $pinned ],
		[ 'pinned fast', { sslfingerprint => $pinned, fast => 1 },
		  '/rpc.cgi', $pinned ],
		[ 'unverified guest', { cloudmin_uuid => 'fixture', fast => 1 },
		  '/rpc.cgi', 'invalid' ],
		[ 'ordinary fast', { fast => 1 }, '/fastrpc.cgi', undef ],
		[ 'pinned with CA checks', { sslfingerprint => $pinned,
					    checkssl => 1 }, '/rpc.cgi', $pinned ]) {
		# Stop at connection setup so no fixture request opens a socket.
		my ($name, $fields, $path, $pin) = @$case;
		@connection = ( );
		remote_rpc_call({ id => 123, host => 'guest.test',
			port => 10000, ssl => 1, user => 'fixture',
			pass => 'synthetic-secret', %$fields }, { action => 'ping' });
		# Verify the selected endpoint and the required certificate pin.
		is($connection[4], $path, "$name uses the expected RPC transport");
		is(($connection[7] || { })->{'fingerprint'}, $pin,
		   "$name passes the required certificate pin");
		if ($fields->{'checkssl'}) {
			# Pinning adds to explicitly requested CA verification.
			is_deeply($connection[7], { host => 'guest.test', self => 1,
				capath => '/fixture/ca', fingerprint => $pinned },
				'RPC preserves existing CA checks');
			}
		}
	}

# Saving pinned entries cannot send their login through the unverified probe.
{
	no warnings qw(redefine once);
	local $INC{'./servers-lib.pl'} = 1;
	local %access = ( edit => 1, servers => '*' );
	# ReadParse() preserves the input hash supplied by each test case.
	local *main::ReadParse = sub { };
	# error_setup(message) suppresses CGI error-page configuration.
	local *main::error_setup = sub { };
	# error(message) turns a CGI refusal into a test failure.
	local *main::error = sub { die "$_[0]\n" };
	# to_ipaddress(host) resolves the fixture without contacting DNS.
	local *main::to_ipaddress = sub { '192.0.2.1' };
	# webmin_log(args...) suppresses writes to the installed audit log.
	local *main::webmin_log = sub { };
	# redirect(url) lets the CGI finish without emitting response headers.
	local *main::redirect = sub { };
	my ($record, $saved, $probes);
	# get_server(id) returns a copy so saves can be checked separately.
	local *main::get_server = sub { +{ %$record } };
	# save_server(record) captures the record without writing a file.
	local *main::save_server = sub { $saved = { %{$_[0]} } };
	# make_http_connection(args...) counts probes without opening sockets.
	local *main::make_http_connection = sub {
		$probes++;
		return 'fixture connection stopped';
		};
	# Cover both automatic detection and an explicit request for fast RPC.
	for my $case (
		[ 'pinned automatic', { sslfingerprint => $pinned }, 2, 0, 0 ],
		[ 'pinned explicit fast', { sslfingerprint => $pinned }, 1, 0, 0 ],
		[ 'unverified guest', { cloudmin_uuid => 'fixture' }, 2, 0, 0 ],
		[ 'ordinary automatic', { }, 2, 1, 0 ],
		[ 'ordinary explicit fast', { }, 1, 0, 1 ]) {
		# Reset the stored record and CGI input for each save operation.
		my ($name, $fields, $fast, $expected_probes, $saved_fast) = @$case;
		$record = { id => 123, %$fields };
		$saved = undef;
		$probes = 0;
		local %in = ( id => 123, host => 'guest.test', port => 10000,
			ssl => 1, mode => 1, fast => $fast,
			wuser => 'fixture', wpass => 'synthetic-secret' );
		# Run the save handler and surface any unexpected CGI failure.
		do "$Bin/../servers/save_serv.cgi";
		die $@ if ($@);
		# Check allowed probes, the transport and preservation of pins.
		is($probes, $expected_probes, "$name uses only allowed probes");
		is($saved->{'fast'}, $saved_fast, "$name saves a safe RPC transport");
		is($saved->{'sslfingerprint'}, $fields->{'sslfingerprint'},
		   "$name preserves the saved pin");
		}
	}

# A websocket route must not ignore its pin when TLS is disabled.
{
	no warnings qw(redefine once);
	local %miniserv::header = ( origin => 'https://host.test',
		'sec-websocket-key' => 'fixture' );
	# get_websocket_allowed_origins() permits the synthetic browser origin.
	local *miniserv::get_websocket_allowed_origins =
		sub { 'https://host.test' };
	# open_socket(args...) fails if a plaintext backend is contacted.
	local *miniserv::open_socket = sub { die "Unexpected connection\n" };
	# http_error(status, message) exposes the refusal as an exception.
	local *miniserv::http_error = sub { die "$_[1]\n" };
	my $cleaned;
	# cleanup_websocket_route(&wsconfig) counts credential route removals.
	local *miniserv::cleanup_websocket_route = sub { $cleaned++ };
	# Keep debug output in memory while exercising the real request handler.
	my $debug;
	local *miniserv::DEBUG;
	open(miniserv::DEBUG, '>', \$debug) or die $!;
	eval { miniserv::handle_websocket_request({ host => 'guest.test',
		port => 10000, ssl => 0, sslfingerprint => $pinned }, '/ws-123') };
	# Refusal must also remove the route that holds the backend login.
	like($@, qr/SSL is required/, 'a pinned websocket cannot bypass TLS');
	is($cleaned, 1, 'a refused websocket removes its credential route');
	}

done_testing();
