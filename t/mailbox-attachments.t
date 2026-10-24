#!/usr/bin/perl
# Check MIME policy, HTML isolation, and byte-preserving attachment downloads.
use strict;
use warnings;
use Test::More;
use FindBin;
require "$FindBin::Bin/fixtures/mailbox-attachment-response.pl";

my $svg = '<svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)"/>';
my @plain = qw(text/plain text/xml text/css image/svg image/svg+xml
	application/xml application/xhtml+xml application/rss+xml image/example+xml
	message/delivery-status);
my @images = qw(image/gif image/jpeg image/png image/webp image/bmp image/avif
	image/x-icon image/vnd.microsoft.icon);
my @downloads = qw(application/octet-stream application/zip application/pdf
	application/unknown image/unknown image/png-extra application/xml-extra);

subtest 'MIME policy and raw data' => sub {
	my @cases = (
		(map { [ $_, 'text/plain', 0 ] } @plain),
		(map { [ $_, $_, 0 ] } @images),
		(map { [ $_, 'application/octet-stream', 1 ] } @downloads),
		[ 'Application/XML; charset=UTF-8', 'text/plain', 0 ],
		[ 'IMAGE/PNG; name=fixture.png', 'image/png', 0 ],
		);
	foreach my $case (@cases) {
		my ($type, $expected, $download) = @$case;
		my ($headers, $body) = split(/\n\n/,
			mailbox_attachment_response($type, $svg, 'fixture', {}), 2);
		like($headers, qr/^Content-type: \Q$expected\E$/m, "$type output type");
		like($headers, qr/^X-Content-Type-Options: nosniff$/m, "$type nosniff");
		is($headers =~ /^Content-Disposition: Attachment;/m ? 1 : 0,
			$download, "$type download policy");
		is($body, $svg, "$type body is emitted once and unchanged");
		}
	};

subtest 'HTML preview keeps formatting but is isolated' => sub {
	my $html = '<h1>Heading</h1><b>Bold</b><script>alert(1)</script>'.
		'<img onerror="alert(1)" src="missing">';
	my ($headers, $body) = split(/\n\n/,
		mailbox_attachment_response('text/html', $html, 'page.html', {}), 2);
	like($headers, qr/^Content-type: text\/html$/m, 'HTML preview retained');
	like($headers, qr/^Content-Security-Policy: sandbox; script-src 'none'; /m,
		'scripts and origin privileges disabled independently of filtering');
	unlike($headers, qr/allow-scripts|allow-same-origin/, 'sandbox has no unsafe exceptions');
	is($body, main::safe_urls(main::filter_javascript($html)), 'existing HTML filters retained');
	like($body, qr/<h1>Heading<\/h1><b>Bold<\/b>/, 'formatting retained');
	unlike($body, qr/<script>/, 'script element filtered');
	};

subtest 'overrides cannot enable active content or inject headers' => sub {
	foreach my $override ('text/plain', 'text/html', 'application/xml',
			     "text/html\r\nX-Injected: yes") {
		my ($headers, $body) = split(/\n\n/,
			mailbox_attachment_response('text/plain', $svg, 'file.txt',
				{ type => $override }), 2);
		like($headers, qr/^Content-type: text\/plain$/m, 'override is plain text');
		unlike($headers, qr/X-Injected/, 'override is not reflected into headers');
		is($body, $svg, 'override returns one unchanged copy');
		}
	foreach my $name ('drawing.svg', 'drawing.SVGZ') {
		my ($headers, $body) = split(/\n\n/,
			mailbox_attachment_response('image/png', $svg, $name, {}), 2);
		like($headers, qr/^Content-type: text\/plain$/m, 'SVG filename remains inert');
		is($body, $svg, 'SVG filename does not duplicate data');
		}
	};

subtest 'Save preserves original bytes and filename' => sub {
	foreach my $type ('text/html', 'application/xml', 'image/svg+xml', 'image/png',
			 'application/zip') {
		my $data = "<script>fixture</script>\0\xff\r\n";
		foreach my $override ('', 'text/plain', 'text/html') {
			my ($headers, $body) = split(/\n\n/,
				mailbox_attachment_response($type, $data, 'read me.dat',
					{ save => 1, type => $override }), 2);
			like($headers, qr/^Content-Disposition: Attachment; filename="read me.dat"$/m,
				'save forces download with its filename');
			like($headers, qr/^Content-type: application\/octet-stream$/m,
				'save does not render an active MIME type');
			is($body, $data, 'save returns exactly the original binary bytes');
			}
		}
	};

subtest 'mailbox access is still required' => sub {
	eval { mailbox_attachment_response('text/plain', 'private', 'file.txt', { deny => 1 }); };
	like($@, qr/Mailbox access denied/, 'unauthorized mailbox read rejected');
	};
done_testing();
