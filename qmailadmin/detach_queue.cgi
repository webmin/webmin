#!/usr/local/bin/perl
# detach_queue.cgi
# View one attachment from a queued message

require './qmail-lib.pl';

&ReadParse();
$mail = &read_mail_file($in{'file'});
&parse_mail($mail);
$attach = $mail->{'attach'}->[$in{'attach'}];

print "X-no-links: 1\n";
if ($attach->{'type'} =~ /^text\/html/i ||
    $attach->{'type'} =~ /^image\/svg(?:\+xml)?/i ||
    $attach->{'type'} =~ /^application\/xhtml\+xml/i) {
	print "Content-type: text/plain\n\n";
	}
else {
	print "Content-type: $attach->{'type'}\n\n";
	}
print $attach->{'data'};

