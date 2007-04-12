#!/usr/local/bin/perl
# view_mailq.cgi
# Display some message from the mail queue

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
$mail = &mail_from_queue($qfile, "auto");
$mail || &error($text{'view_egone'});
&can_view_qfile($mail) || &error($text{'mailq_ecannot'});
&parse_mail($mail);
@sub = split(/\0/, $in{'sub'});
$subs = join("", map { "&sub=$_" } @sub);
foreach $s (@sub) {
        # We are looking at a mail within a mail ..
        local $amail = &extract_mail($mail->{'attach'}->[$s]->{'data'});
        &parse_mail($amail);
        $mail = $amail;
        }

($name = $in{'file'}) =~ s/^.*\///;
if (!@sub) {
	$desc = &text('view_qdesc', "<tt>$name</tt>");
	}
else {
	$desc = $text{'view_sub'};
	}
&ui_print_header($desc, $text{'view_title'}, "");

print "<form action=del_mailq.cgi>\n";
if (!@sub && $config{'top_buttons'} == 2) {
	print "<input type=submit value=\"$text{'view_delete'}\" name=delete>\n";
	print "<input type=submit value=\"$text{'view_flush'}\" name=flush>\n";
	print "<p>\n";
	}
print "<input type=hidden name=file value='$in{'file'}'>\n";
print "<table width=100% border=1>\n";
print "<tr> <td $tb><table width=100% cellpadding=0 cellspacing=0><tr>",
      "<td><b>$text{'view_headers'}</b></td>\n";
if ($in{'headers'}) {
	print "<td align=right><a href='view_mailq.cgi?file=$in{'file'}&headers=0$subs'>$text{'view_noheaders'}</a></td>\n";
	}
else {
	print "<td align=right><a href='view_mailq.cgi?file=$in{'file'}&headers=1$subs'>$text{'view_allheaders'}</a></td>\n";
	}
print "</tr></table></td> </tr>\n";

print "<tr> <td $cb><table width=100%>\n";
if ($in{'headers'}) {
	# Show all the headers
	if ($mail->{'fromline'}) {
		print "<tr> <td><b>$text{'mail_rfc'}</b></td>",
		      "<td>",&html_escape($mail->{'fromline'}),"</td> </tr>\n";
		}
	foreach $h (@{$mail->{'headers'}}) {
		print "<tr> <td><b>$h->[0]:</b></td> ",
		      "<td>",&html_escape(&decode_mimewords($h->[1])),
		      "</td> </tr>\n";
		}
	}
else {
	# Just show the most useful headers
	print "<tr> <td><b>$text{'mail_from'}</b></td> ",
	      "<td>",&html_escape($mail->{'header'}->{'from'}),"</td> </tr>\n";
	print "<tr> <td><b>$text{'mail_to'}</b></td> ",
	      "<td>",&html_escape($mail->{'header'}->{'to'}),"</td> </tr>\n";
	print "<tr> <td><b>$text{'mail_cc'}</b></td> ",
	      "<td>",&html_escape($mail->{'header'}->{'cc'}),"</td> </tr>\n"
		if ($mail->{'header'}->{'cc'});
	print "<tr> <td><b>$text{'mail_date'}</b></td> ",
	      "<td>",&html_escape($mail->{'header'}->{'date'}),"</td> </tr>\n";
	print "<tr> <td><b>$text{'mail_subject'}</b></td> ",
	      "<td>",&html_escape(
			$mail->{'header'}->{'subject'}),"</td> </tr>\n";
	}
print "</table></td></tr></table><p>\n";

# Find body attachment
@attach = @{$mail->{'attach'}};
foreach $a (@attach) {
	if ($a->{'type'} eq 'text/plain') {
		$body = $a;
		last;
		}
	}
if ($body) {
	print "<table width=100% border=1><tr><td $cb><pre>\n";
	foreach $l (&wrap_lines($body->{'data'}, $config{'wrap_width'})) {
		print &link_urls_and_escape($l),"\n";
		}
	print "</pre></td></tr></table><p>\n";
	}

# Display other attachments
@attach = grep { $_ ne $body } @attach;
@attach = grep { !$_->{'attach'} } @attach;
if (@attach) {
	print "<table width=100% border=1>\n";
	print "<tr> <td $tb><b>$text{'view_attach'}</b></td> </tr>\n";
	print "<tr> <td $cb>\n";
	foreach $a (@attach) {
		if ($a->{'type'} eq 'message/rfc822') {
			push(@titles, $text{'view_sub'});
			push(@links, "view_mailq.cgi?file=$qfile$subs&sub=$a->{'idx'}");
			}
		else {
			push(@titles, $a->{'filename'} ?
			    &decode_mimewords($a->{'filename'}) : $a->{'type'});
			push(@links, "qdetach.cgi?file=$qfile&attach=$a->{'idx'}$subs");
			}
		push(@icons, "images/boxes.gif");
		}
	&icons_table(\@links, \@titles, \@icons, 8);
	print "</td></tr></table><p>\n";
	}

# Display buttons
if (!@sub) {
	print "<input type=submit value=\"$text{'view_delete'}\" name=delete>\n";
	print "<input type=submit value=\"$text{'view_flush'}\" name=flush>\n";
	}
print "</form>\n";

&ui_print_footer(!@sub ? ( ) : ( "view_mailq.cgi?file=$qfile", $text{'view_return'} ),
	"list_mailq.cgi", $text{'mailq_return'},
	"", $text{'index_return'});

