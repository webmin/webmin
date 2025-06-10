#!/usr/local/bin/perl
# Show a page containing all image attachments

require './mailboxes-lib.pl';

# Get the mail
&ReadParse();
&can_user($in{'user'}) || &error($text{'mail_ecannot'});
@folders = &list_user_folders($in{'user'});
$folder = $folders[$in{'folder'}];
@mail = &mailbox_list_mails($in{'idx'}, $in{'idx'}, $folder);
$mail = $mail[$in{'idx'}];
&parse_mail($mail);
@sub = split(/\0/, $in{'sub'});
$subs = join("", map { "&sub=".&urlize($_) } @sub);
foreach $s (@sub) {
        # We are looking at a mail within a mail ..
        local $amail = &extract_mail($mail->{'attach'}->[$s]->{'data'});
        &parse_mail($amail);
        $mail = $amail;
        }

# Find image attachments
@attach = @{$mail->{'attach'}};
@attach = &remove_body_attachments($mail, \@attach);
@attach = &remove_cid_attachments($mail, \@attach);
@iattach = grep { $_->{'type'} =~ /^image\// } @attach;

&popup_header($text{'slide_title'});

$n = 0;
foreach $a (@iattach) {
	# Navigation links
	print "<hr>" if ($n > 0);
	print "<a name=image$n></a>\n";
	@links = ( );
	if ($a eq $iattach[0]) {
		push(@links, $text{'slide_prev'});
		}
	else {
		push(@links, "<a href='#image".($n-1)."'>".
			     "$text{'slide_prev'}</a>");
		}
	if ($a eq $iattach[$#iattach]) {
		push(@links, $text{'slide_next'});
		}
	else {
		push(@links, "<a href='#image".($n+1)."'>".
			     "$text{'slide_next'}</a>");
		}
	push(@links, "<b>$a->{'filename'}</b>") if ($a->{'filename'});
	print &ui_links_row(\@links),"<br>\n";

	# Actual image
	print "<img src='detach.cgi?idx=$in{'idx'}".
	      "&folder=$in{'folder'}&attach=$a->{'idx'}&user=".
	      &urlize($in{'user'})."$subs'><br>\n";
	$n++;
	}

&popup_footer();

