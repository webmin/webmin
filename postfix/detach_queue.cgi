#!/usr/local/bin/perl
# detach_queue.cgi
# View one attachment from a queued message

require './postfix-lib.pl';
require './boxes-lib.pl';
&ReadParse();
$access{'mailq'} || &error($text{'mailq_ecannot'});

$mail = &parse_queue_file($in{'id'});
$mail || &error($text{'mailq_egone'});
&parse_mail($mail);
$attach = $mail->{'attach'}->[$in{'attach'}];

print "X-no-links: 1\n";
if ($attach->{'type'} eq 'message/delivery-status') {
	print "Content-type: text/plain\n\n";
	}
else {
	print "Content-type: $attach->{'type'}\n\n";
	}
if ($attach->{'type'} =~ /^text\/html/i) {
	print &filter_javascript($attach->{'data'});
	}
else {
	print $attach->{'data'};
	}

