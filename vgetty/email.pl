#!/usr/local/bin/perl
# email.pl
# Email a received message in WAV format to some address

$no_acl_check++;
require './vgetty-lib.pl';
&foreign_check("mailboxes") || die "Read User Mail module not installed";
&foreign_require("mailboxes", "mailboxes-lib.pl");

# Get the WAV format message and construct the email
open(OUT, "rmdtopvf $ARGV[0] 2>/dev/null | pvftowav 2>/dev/null |");
while(read(OUT, $buf, 1024)) {
	$wav .= $buf;
	}
close(OUT);
$now = localtime(time());
$host = &get_system_hostname();
$body = &text('email_body', $now, $host);
$mail = { 'headers' => [ [ 'From', &mailboxes::get_from_address() ],
		         [ 'To', $config{'email_to'} ],
		         [ 'Subject', $text{'email_subject'} ] ],
	  'attach' => [ { 'headers' => [ [ 'Content-Type', 'text/plain' ] ],
			  'data' => $body },
		        { 'headers' => [ [ 'Content-Transfer-Encoding',
					 'base64' ],
					 [ 'Content-Type',
					   'audio/wav; name="voicemail.wav"' ]],
			  'data' => $wav } ]
	};

# Send the email
&mailboxes::send_mail($mail);

