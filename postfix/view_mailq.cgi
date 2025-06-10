#!/usr/local/bin/perl
# view_mailq.cgi
# Display some message from the mail queue

require './postfix-lib.pl';
require './boxes-lib.pl';
&ReadParse();
$access{'mailq'} || &error($text{'mailq_ecannot'});

$mail = &parse_queue_file($in{'id'});
$mail || &error($text{'mailq_egone'});
&parse_mail($mail);
@sub = split(/\0/, $in{'sub'});
$subs = join("", map { "&sub=$_" } @sub);
foreach $s (@sub) {
        # We are looking at a mail within a mail ..
        local $amail = &extract_mail($mail->{'attach'}->[$s]->{'data'});
        &parse_mail($amail);
        $mail = $amail;
        }

if (!@sub) {
	$desc = &text('view_qdesc',"<tt>$in{'id'}</tt>");
	}
else {
	$desc = $text{'view_sub'};
	}
&ui_print_header($desc, $text{'view_title'}, "");

print &ui_form_start("delete_queues.cgi");
if (!@sub && $config{'top_buttons'} == 2) {
	print &ui_submit($text{'view_delete'}, "delete");
	print "<p>\n";
	}
print &ui_hidden("file", $in{'id'});

# Start of headers section
if ($in{'headers'}) {
	$rlink = &ui_link("view_mailq.cgi?id=$in{'id'}&headers=0$subs",$text{'view_noheaders'});
	}
else {
	$rlink = &ui_link("view_mailq.cgi?id=$in{'id'}&headers=1$subs",$text{'view_allheaders'});
	}
print &ui_table_start($text{'view_headers'}, "width=100%", 2, undef, $rlink);

if ($in{'headers'}) {
	# Show all the headers
	if ($mail->{'fromline'}) {
		print &ui_table_row($text{'mail_rfc'},
				    &html_escape($mail->{'fromline'}));
		}
	foreach $h (@{$mail->{'headers'}}) {
		print &ui_table_row($h->[0],
			&html_escape(&decode_mimewords($h->[1])), 1, [ "nowrap" ]);
		}
	if ($mail->{'file'}) {
		print &ui_table_row($text{'mail_qfile'},
			"<tt>".&html_escape($mail->{'file'})."</tt>");
		}
	}
else {
	# Just show the most useful headers
	print &ui_table_row($text{'mail_from'},
		&html_escape($mail->{'header'}->{'from'}));
	print &ui_table_row($text{'mail_to'},
		&html_escape($mail->{'header'}->{'to'}));
	print &ui_table_row($text{'mail_cc'},
		&html_escape($mail->{'header'}->{'cc'}))
		if ($mail->{'header'}->{'cc'});
	print &ui_table_row($text{'mail_date'},
		&html_escape($mail->{'header'}->{'date'}));
	print &ui_table_row($text{'mail_subject'},
		&html_escape($mail->{'header'}->{'subject'}));
	}
if ($mail->{'last_retry'}) {
	print &ui_table_row($text{'mail_qlast'},
		&make_date($mail->{'last_retry'}));
	}
if ($mail->{'dir'}) {
	print &ui_table_row($text{'mail_qdir'},
		$text{'mailq_'.$mail->{'dir'}} || $mail->{'dir'});
	}
print &ui_table_end();

# Find body attachment
@attach = @{$mail->{'attach'}};
foreach $a (@attach) {
	if ($a->{'type'} eq 'text/plain') {
		$body = $a;
		last;
		}
	}
if ($body) {
	print &ui_table_start($text{'view_body'}, "width=100%", 2);
	$bodyhtml = "";
	foreach $l (&wrap_lines($body->{'data'}, $config{'wrap_width'})) {
		$bodyhtml .= &link_urls_and_escape($l)."\n";
		}
	print &ui_table_row(undef, "<pre>".$bodyhtml."</pre>", 2);
	print &ui_table_end();
	}

# Display other attachments
@attach = grep { $_ ne $body } @attach;
@attach = grep { !$_->{'attach'} } @attach;
if (@attach) {
	print &ui_columns_start([ $text{'view_afile'}, $text{'view_atype'},
				  $text{'view_asize'} ], 100, 0);
	my $attachment_id;
	foreach $a (@attach) {
		$attachment_id++;
		if ($a->{'type'} eq 'message/rfc822') {
			print &ui_columns_row([
				&ui_link("view_mailq.cgi?id=$in{'id'}$subs&sub=$a->{'idx'}",$text{'view_sub'}),
				undef,
				&nice_size(length($a->{'data'})),
				]);
			}
		else {
			print &ui_columns_row([
				&ui_link("detach_queue.cgi/$a->{'filename'}?id=$in{'id'}&attach=$a->{'idx'}$subs",$a->{'filename'} || $text{'view_aname'}.' #'.$attachment_id),
				$a->{'type'},
				&nice_size(length($a->{'data'})),
				]);
			}
		}
	print &ui_columns_end();
	}

# Display buttons
if (!@sub) {
	print &ui_submit($text{'view_delete'}, "delete");
	}
print &ui_form_end();

&ui_print_footer(!@sub ? ( ) : ( "view_mailq.cgi?id=$in{'id'}", $text{'view_return'} ),
	"mailq.cgi", $text{'mailq_return'},
	"", $text{'index_return'});

