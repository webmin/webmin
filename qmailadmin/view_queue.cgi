#!/usr/local/bin/perl
# view_queue.cgi
# Display some message from the mail queue

require './qmail-lib.pl';
&ReadParse();

$mail = &read_mail_file($in{'file'});
&parse_mail($mail);

$desc = &text('qview_desc', "<tt>$in{'file'}</tt>");
&ui_print_header($desc, $text{'qview_title'}, "");

print "<form action=delete_queue.cgi method=post>\n";
print "<input type=hidden name=file value='$in{'file'}'>\n";
print "<table width=100% border=1>\n";
print "<tr> <td $tb><b>$text{'qview_headers'}</b></td> </tr>\n";
print "<tr> <td $cb><table width=100%>\n";
print "<tr> <td><b>$text{'queue_from'}</b></td> ",
      "<td>",&html_escape($mail->{'header'}->{'from'}),"</td> </tr>\n";
print "<tr> <td><b>$text{'queue_to'}</b></td> ",
      "<td>",&html_escape($mail->{'header'}->{'to'}),"</td> </tr>\n";
print "<tr> <td><b>$text{'queue_cc'}</b></td> ",
      "<td>",&html_escape($mail->{'header'}->{'cc'}),"</td> </tr>\n"
	if ($mail->{'header'}->{'cc'});
print "<tr> <td><b>$text{'queue_date'}</b></td> ",
      "<td>",&html_escape($mail->{'header'}->{'date'}),"</td> </tr>\n";
print "<tr> <td><b>$text{'queue_subject'}</b></td> ",
      "<td>",&html_escape($mail->{'header'}->{'subject'}),"</td> </tr>\n";
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
	print "<tr> <td $tb><b>$text{'qview_attach'}</b></td> </tr>\n";
	print "<tr> <td $cb>\n";
	foreach $a (@attach) {
		push(@titles, $a->{'filename'} ? $a->{'filename'}
					       : $a->{'type'});
		push(@links, "detach_queue.cgi?file=$in{'file'}&attach=$a->{'idx'}");
		push(@icons, "images/boxes.gif");
		}
	&icons_table(\@links, \@titles, \@icons, 8);
	print "</td></tr></table><p>\n";
	}

print "<input type=submit value='$text{'delete'}'></form>\n";

&ui_print_footer("list_queue.cgi", $text{'queue_return'});

