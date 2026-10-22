#!/usr/local/bin/perl
# detach_queue.cgi
# View one attachment from a queued message

require './qmail-lib.pl';

&ReadParse();
$mail = &read_mail_file($in{'file'});
&parse_mail($mail);
$attach = $mail->{'attach'}->[$in{'attach'}];

my $type = lc($attach->{'type'} || 'application/octet-stream');
print "X-no-links: 1\n";
print "X-Content-Type-Options: nosniff\n";
if ($type =~ /^text\// || $type =~ /(?:\/|\+)xml\z/ ||
    $type eq 'image/svg' || $type eq 'message/delivery-status') {
	# Display text and XML as plain text, never as active documents.
	print "Content-type: text/plain\n\n";
	}
elsif ($type =~ /\Aimage\/(?:gif|jpeg|png|webp|bmp|avif|x-icon|vnd\.microsoft\.icon)\z/) {
	# Only known raster image types may be rendered inline.
	print "Content-type: $type\n\n";
	}
else {
	# Download other formats without trusting the sender's MIME type.
	print "Content-Disposition: Attachment\n";
	print "Content-type: application/octet-stream\n\n";
	}
print $attach->{'data'};

