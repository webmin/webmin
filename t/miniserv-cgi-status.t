#!/usr/bin/perl
# Exercise forked CGI responses through the real request handler, using only
# temporary scripts and a Unix socket pair. No host configuration is loaded.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use Socket;
require "$FindBin::Bin/../miniserv-lib.pl";

my $dir = tempdir(DIR => '/tmp', CLEANUP => 1);
my ($response, $logged);
# Force the forked CGI path using an ordinary IP-authenticated fixture user.
%miniserv::config = ( env_WEBMIN_CONFIG => $dir, maxconns => 1,
		     agents_nosession => 'Webmin', session => 0,
		     forkcgis => 1 );
@miniserv::roots = ( $dir );
$miniserv::host = 'test.invalid';
$miniserv::port = 10000;
$miniserv::perl_path = $^X;
%miniserv::ipaccess = ( '192.0.2.42' => 'fixture' );
%miniserv::users = ( fixture => { name => 'fixture', pass => '!' } );
%miniserv::mime = ( cgi => 'internal/cgi' );
# log_error(message): suppress fixture diagnostics without writing host logs.
*miniserv::log_error = sub { };
# log_request(host, user, request, code, bytes): capture the access-log status.
*miniserv::log_request = sub { $logged = $_[3]; };
# write_keep_alive(enabled): omit connection reuse headers from test output.
*miniserv::write_keep_alive = sub { };
# http_error(code, message, [body]): fail the test on unexpected server errors.
*miniserv::http_error = sub { die "HTTP error $_[0]: $_[1]\n"; };
# write_data(parts...): retain response bytes for status and body assertions.
*miniserv::write_data = sub { $response .= join('', @_); };
open(*miniserv::DEBUG, '>', \my $debug) or die $!;

# request(headers): execute a temporary CGI and return its HTTP response.
sub request
{
my ($headers) = @_;
# Emit the supplied CGI headers with a known content type and body.
open(my $script, '>', "$dir/fixture.cgi") or die $!;
print $script "#!$^X\nprint <<'RESPONSE';\n".
	$headers."\r\nContent-type: text/plain\r\n\r\nCGI_BODY\nRESPONSE\n";
close($script) or die $!;
chmod(0755, "$dir/fixture.cgi") or die $!;
# Reset request state so an earlier status cannot affect this response.
$response = '';
$logged = undef;
$miniserv::checked_timeout = 0;
$miniserv::buffer = '';
$miniserv::offset = 0;
# Supply a real request through a Unix socket pair without opening a TCP port.
socketpair(*miniserv::SOCK, my $client, AF_UNIX, SOCK_STREAM, PF_UNSPEC) ||
	die $!;
my $request = "GET /fixture.cgi HTTP/1.0\r\n".
	"Host: test.invalid\r\nUser-Agent: Webmin test\r\n\r\n";
syswrite($client, $request) == length($request) or die $!;
eval { miniserv::handle_request('192.0.2.42', '192.0.2.1', 0); };
my $error = $@;
# Close sockets and reap the CGI child before propagating a request error.
close($client);
close(miniserv::SOCK);
waitpid($miniserv::cgipid, 0) if ($miniserv::cgipid);
die $error if ($error);
return $response;
}

# Error and success codes must match in the HTTP response and access log.
foreach my $status ('403 Forbidden', '404 Not Found', '201 Created',
		   '200 OK') {
	my $output = request("Status: $status");
	like($output, qr/^HTTP\/1\.0 \Q$status\E\r\n/, "$status is honored");
	is($logged, substr($status, 0, 3), "$status is logged");
	unlike($output, qr/^Status:/mi, 'CGI Status header is not forwarded');
	like($output, qr/CGI_BODY/, 'CGI response body is retained');
	}

# An explicit redirect keeps its status and body, unlike Location alone.
my $output = request("status: 303 See Other\r\nLocation: /next.cgi");
like($output, qr/^HTTP\/1\.0 303 See Other/, 'explicit redirect is honored');
is($logged, 303, 'explicit redirect status is logged');
like($output, qr/Location: \/next.cgi\r\n/, 'redirect location is retained');
like($output, qr/CGI_BODY/, 'explicit redirect body is retained');
# Location without Status keeps the existing implicit redirect behavior.
$output = request('Location: /next.cgi');
like($output, qr/^HTTP\/1\.0 302 Moved Temporarily/, 'implicit redirect works');
is($logged, 302, 'implicit redirect status is logged');
unlike($output, qr/CGI_BODY/, 'implicit redirect omits the CGI body');

# Default and malformed statuses must not inherit the previous response code.
foreach my $headers ('X-Fixture: yes', 'Status: invalid', 'Status: 999 Invalid') {
	$output = request($headers);
	like($output, qr/^HTTP\/1\.0 200 /, 'ordinary response remains successful');
	is($logged, 200, 'ordinary response logs its own status');
	}
done_testing();
