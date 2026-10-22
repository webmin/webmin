#!/usr/local/bin/perl
# detach.cgi
# View one attachment from a message

require './sendmail-lib.pl';
require './boxes-lib.pl';

&ReadParse();
$access{'mailq'} || &error($text{'mailq_ecannot'});
$in{'file'} =~ /\.\./ && &error($text{'mailq_ecannot'});
$conf = &get_sendmailcf();
foreach $mqueue (&mailq_dir($conf)) {
	$ok++ if ($in{'file'} =~ /^$mqueue\//);
	}
$ok || &error($text{'mailq_ecannot'});

$qfile = $in{'file'};
($dfile = $qfile) =~ s/\/(qf|hf|Qf)/\/df/;
$mail = &mail_from_queue($qfile, $dfile);
&parse_mail($mail);
@sub = split(/\0/, $in{'sub'});
foreach $s (@sub) {
	# We are looking at a mail within a mail ..
	local $amail = &extract_mail($mail->{'attach'}->[$s]->{'data'});
	&parse_mail($amail);
	$mail = $amail;
	}
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

