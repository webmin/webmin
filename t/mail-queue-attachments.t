#!/usr/bin/perl
# Exercise the queue attachment CGIs without a mail server or Webmin setup.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";
require "$root/mailboxes/boxes-lib.pl";

# Keep the real MIME parser, but replace module initialization and queue reads.
for my $lib (qw(postfix-lib.pl qmail-lib.pl sendmail-lib.pl boxes-lib.pl)) {
	$INC{"./$lib"} = 1;
	}
local *main::ReadParse = sub { };
local *main::error = sub { die join(' ', @_)."\n"; };
local *main::get_sendmailcf = sub { return []; };
local *main::mailq_dir = sub { return '/fixture/queue'; };

# attachment_response(cgi, mime_type, data)
# Render one MIME attachment through a real CGI with an in-memory queue entry.
sub attachment_response
{
my ($cgi, $type, $data) = @_;
my $message = {
	'header' => { 'content-type' => 'multipart/mixed; boundary=fixture' },
	'body' => "--fixture\nContent-Type: $type\n".
		  "Content-Transfer-Encoding: base64\n\n".
		  &main::encode_base64($data)."--fixture--\n",
	};
local *main::parse_queue_file = sub { return $message; };
local *main::read_mail_file = sub { return $message; };
local *main::mail_from_queue = sub { return $message; };
local %main::access = ( 'mailq' => 1 );
local %main::in = ( 'id' => 'fixture', 'file' => '/fixture/queue/qffixture',
		   'attach' => 0 );
local $main::ok;
my $response = '';
open(my $out, '>', \$response) or die "open scalar: $!";
{
	local *STDOUT = $out;
	do "$root/$cgi";
	die $@ if ($@);
	}
close($out);
return split(/\n\n/, $response, 2);
}

my $svg = '<svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)"/>';
my @text_types = qw(text/plain text/html text/xml text/css image/svg
	image/svg+xml application/xml application/xhtml+xml application/rss+xml
	application/atom+xml image/example+xml message/delivery-status);
my @image_types = qw(image/gif image/jpeg image/png image/webp image/bmp
	image/avif image/x-icon image/vnd.microsoft.icon);
my @download_types = qw(application/octet-stream application/zip application/pdf
	application/json application/unknown image/unknown image/png-extra
	application/xml-extra image/svgz);

for my $cgi (qw(postfix/detach_queue.cgi qmailadmin/detach_queue.cgi
	       sendmail/qdetach.cgi)) {
	subtest $cgi => sub {
		# MIME parameters and mixed case must not bypass the output policy.
		my @cases = (
			(map { [ $_, 'text/plain', 0 ] } @text_types),
			(map { [ $_, $_, 0 ] } @image_types),
			(map { [ $_, 'application/octet-stream', 1 ] } @download_types),
			[ 'Application/XML; charset=UTF-8', 'text/plain', 0 ],
			[ 'IMAGE/PNG; name=fixture.png', 'image/png', 0 ],
			);
		for my $case (@cases) {
			my ($type, $expected, $download) = @$case;
			my ($headers, $body) = attachment_response($cgi, $type, $svg);
			like($headers, qr/^Content-type: \Q$expected\E$/m,
				"$type has a safe response type");
			like($headers, qr/^X-Content-Type-Options: nosniff$/m,
				"$type disables MIME sniffing");
			is($headers =~ /^Content-Disposition: Attachment$/m ? 1 : 0,
				$download, "$type has the expected download behavior");
			is($body, $svg, "$type preserves attachment data");
			}

		# Binary downloads must also preserve every byte after MIME decoding.
		my $binary = "PK\x03\x04\0\xff\r\nfixture";
		my (undef, $body) = attachment_response($cgi, 'application/zip', $binary);
		is($body, $binary, 'binary attachment is unchanged');
		};
	}

done_testing();
