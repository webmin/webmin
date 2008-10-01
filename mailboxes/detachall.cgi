#!/usr/local/bin/perl
# Download all attachments in a ZIP file

require './mailboxes-lib.pl';
&ReadParse();
&error_setup($text{'detachall_err'});
&can_user($in{'user'}) || &error($text{'mail_ecannot'});

@folders = &list_user_folders($in{'user'});
$folder = $folders[$in{'folder'}];
@mail = &mailbox_list_mails($in{'idx'}, $in{'idx'}, $folder);
$mail = $mail[$in{'idx'}];
&parse_mail($mail);
@sub = split(/\0/, $in{'sub'});
foreach $s (@sub) {
        # We are looking at a mail within a mail ..
        local $amail = &extract_mail($mail->{'attach'}->[$s]->{'data'});
        &parse_mail($amail);
        $mail = $amail;
        }

# Save each attachment to a temporary directory
@attach = @{$mail->{'attach'}};
@attach = &remove_body_attachments($mail, \@attach);
@attach = &remove_cid_attachments($mail, \@attach);
$temp = &transname();
&make_dir($temp, 0755) || &error(&text('detachall_emkdir', $!));
$n = 0;
foreach $a (@attach) {
	# Work out a filename
	if (!$a->{'type'} || $a->{'type'} eq 'message/rfc822') {
		$fn = "mail".(++$n).".txt";
		}
	elsif ($a->{'filename'}) {
		$fn = &decode_mimewords($a->{'filename'});
		}
	else {
		$fn = "file".(++$n).".".&type_to_extension($a->{'type'});
		}

	# Write the file
	&open_tempfile(FILE, ">$temp/$fn", 0, 1);
	&print_tempfile(FILE, $a->{'data'});
	&close_tempfile(FILE);
	}

# Make and output the zip
$zip = &transname("$$.zip");
$out = &backquote_command(
	"cd ".quotemeta($temp)." && zip ".quotemeta($zip)." * 2>&1");
if ($?) {
	&error(&text('detachall_ezip', "<tt>".&html_escape($out)."</tt>"));
	}

# Output the ZIP
print "Content-type: application/zip\n\n";
open(ZIP, $zip);
while(read(ZIP, $buf, 1024) > 0) {
	print $buf;
	}
close(ZIP);
&unlink_file($zip);
&unlink_file($temp);

