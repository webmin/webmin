#!/usr/bin/perl
# Test CGI status headers without starting a server or loading Webmin config.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;
require "$FindBin::Bin/../miniserv-lib.pl";

# response(headers): capture the real in-process CGI HTTP response writer.
sub response {
    my ($headers) = @_;
    my $output = '';
    local *miniserv::write_data = sub { $output .= join('', @_); };
    local *miniserv::write_keep_alive = sub {};
    local *miniserv::reset_byte_count = sub {};
    local *miniserv::server_info = sub { return 'fixture'; };
    local %miniserv::cgiheader;
    local @miniserv::cgiheader;
    local $miniserv::headers = '';
    local $miniserv::doneheaders;
    local $miniserv::ok_code = 200;
    local $miniserv::ok_message = 'Document follows';
    miniserv::write_to_sock($headers."\r\nbody");
    return $output;
}
my $denial = response("Status: 403 Forbidden\r\nContent-type: text/plain\r\n");
like($denial, qr/^HTTP\/1\.0 403 Forbidden\r\n/, 'CGI denial sets the HTTP status');
unlike($denial, qr/^Status:/m, 'CGI Status is not forwarded as an HTTP header');
like(response("Location: /next\r\n"), qr/^HTTP\/1\.0 302 /,
     'ordinary redirects keep their default status');
like(response("Status: 307 Temporary Redirect\r\nLocation: /next\r\n"),
     qr/^HTTP\/1\.0 307 /, 'explicit redirect status is respected');
like(response("Status: invalid\r\nLocation: /next\r\n"), qr/^HTTP\/1\.0 302 /,
     'invalid CGI status does not suppress the default redirect');

# Ordinary pages retain the default status; other valid CGI codes also work.
like(response("Content-type: text/plain\r\n"), qr/^HTTP\/1\.0 200 /,
     'ordinary CGI response remains successful');
like(response("Status: 201 Created\r\nContent-type: text/plain\r\n"),
     qr/^HTTP\/1\.0 201 Created\r\n/, 'CGI creation response sets its status');
like(response("Status: invalid\r\nContent-type: text/plain\r\n"),
     qr/^HTTP\/1\.0 200 /, 'invalid CGI status leaves the default unchanged');
done_testing();
