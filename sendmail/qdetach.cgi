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

print "X-no-links: 1\n";
if ($attach->{'type'} eq 'message/delivery-status' ||
    $attach->{'type'} =~ /^text\/html/i ||
    $attach->{'type'} =~ /^image\/svg(?:\+xml)?/i ||
    $attach->{'type'} =~ /^application\/xhtml\+xml/i) {
	print "Content-type: text/plain\n\n";
	}
else {
	print "Content-type: $attach->{'type'}\n\n";
	}
print $attach->{'data'};

