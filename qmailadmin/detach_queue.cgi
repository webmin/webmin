#!/usr/local/bin/perl
# detach_queue.cgi
# View one attachment from a queued message

require './qmail-lib.pl';

&ReadParse();
$mail = &read_mail_file($in{'file'});
&parse_mail($mail);
$attach = $mail->{'attach'}->[$in{'attach'}];

print "X-no-links: 1\n";
print "Content-type: $attach->{'type'}\n\n";
if ($attach->{'type'} =~ /^text\/html/i) {
	print &filter_javascript($attach->{'data'});
	}
else {
	print $attach->{'data'};
	}

