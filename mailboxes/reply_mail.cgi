#!/usr/local/bin/perl
# Display a form for replying to or composing an email

require './mailboxes-lib.pl';
&ReadParse();
&can_user($in{'user'}) || &error($text{'mail_ecannot'});
@uinfo = &get_mail_user($in{'user'});
@uinfo || &error($text{'view_eugone'});

@folders = &list_user_folders($in{'user'});
$folder = $folders[$in{'folder'}];
if ($in{'new'}) {
	# Composing a new email
	$html_edit = 1 if ($config{'html_edit'} == 2);
	$sig = &get_signature($in{'user'});
	if ($html_edit) {
		$sig =~ s/\n/<br>\n/g;
		$quote = "<html><body></body></html>";
		}
	else {
		$quote = "\n\n$sig" if ($sig);
		}
	$to = $in{'to'};
	&mail_page_header($text{'compose_title'}, undef,
			  $html_edit ? "onload='initEditor()'" : "",
			  &folder_link($in{'user'}, $folder));
	}
else {
	# Replying or forwarding
	if ($in{'mailforward'} ne '') {
		# Replying to multiple
		@mailforward = sort { $a <=> $b }
				    split(/\0/, $in{'mailforward'});
		@mails = &mailbox_list_mails(
			     $mailforward[0], $mailforward[@mailforward-1],
			     $folder);
		$mail = $mails[$mailforward[0]];
		}
	else {
		# Replying to one
		@mails = &mailbox_list_mails($in{'idx'}, $in{'idx'},
					     $folder);
		$mail = $mails[$in{'idx'}];
		&decode_and_sub();
		}
	&check_modification($folder) if ($in{'delete'});
	$mail || &error($text{'mail_eexists'});

	if ($in{'delete'}) {
		# Just delete the email
		if (!$in{'confirm'} && &need_delete_warn($folder)) {
			# Need to ask for confirmation before deleting
			&mail_page_header($text{'confirm_title'}, undef, undef,
					  &folder_link($in{'user'}, $folder));
			print &check_clicks_function();

			print "<form action=reply_mail.cgi>\n";
			foreach $i (keys %in) {
				foreach $v (split(/\0/, $in{$i})) {
					print "<input type=hidden name=$i ",
					      "value='",&html_escape($v),"'>\n";
					}
				}
			print "<center><b>$text{'confirm_warn3'}<br>\n";
			if ($config{'delete_warn'} ne 'y') {
				print "$text{'confirm_warn2'}<p>\n"
				}
			else {
				print "$text{'confirm_warn4'}<p>\n"
				}
			print "</b><p><input type=submit name=confirm ",
			      "value='$text{'confirm_ok'}' ",
			      "onClick='return check_clicks(form)'></center></form>\n";
			
			&mail_page_footer("view_mail.cgi?idx=$in{'idx'}&folder=$in{'folder'}&user=$in{'user'}",
				$text{'view_return'},
				"list_mail.cgi?folder=$in{'folder'}&user=$in{'user'}",
				$text{'mail_return'},
				"", $text{'index_return'});
			exit;
			}
		&lock_folder($folder);
		&mailbox_delete_mail($folder, $mail);
		&unlock_folder($folder);
		&webmin_log("delmail", undef, undef,
			    { 'from' => $folder->{'file'},
			      'count' => 1 } );
		&redirect("list_mail.cgi?folder=$in{'folder'}&user=$in{'user'}");
		exit;
		}
	elsif ($in{'print'}) {
		# Extract the mail body
		&decode_and_sub();
		($textbody, $htmlbody, $body) =
			&find_body($mail, $config{'view_html'});

		# Output HTML header
		&PrintHeader();
		print "<html><head>\n";
		print "<title>",&html_escape(&decode_mimewords(
			$mail->{'header'}->{'subject'})),"</title></head>\n";
		print "<body bgcolor=#ffffff onLoad='window.print()'>\n";

		# Display the headers
		print "<table width=100% border=1>\n";
		print "<tr $tb> <td><b>$text{'view_headers'}</b></td> </tr>\n";
		print "<tr $cb> <td><table width=100%>\n";
		print "<tr> <td><b>$text{'mail_from'}</b></td> ",
		      "<td>",&eucconv_and_escape($mail->{'header'}->{'from'}),"</td> </tr>\n";
		print "<tr> <td><b>$text{'mail_to'}</b></td> ",
		      "<td>",&eucconv_and_escape($mail->{'header'}->{'to'}),"</td> </tr>\n";
		print "<tr> <td><b>$text{'mail_cc'}</b></td> ",
		      "<td>",&eucconv_and_escape($mail->{'header'}->{'cc'}),"</td> </tr>\n"
			if ($mail->{'header'}->{'cc'});
		print "<tr> <td><b>$text{'mail_date'}</b></td> ",
		      "<td>",&eucconv_and_escape(&html_escape($mail->{'header'}->{'date'})),
		      "</td> </tr>\n";
		print "<tr> <td><b>$text{'mail_subject'}</b></td> ",
		      "<td>",&eucconv_and_escape(&decode_mimewords(
			$mail->{'header'}->{'subject'})),"</td> </tr>\n";
		print "</table></td></tr></table><p>\n";

		# Just display the mail body for printing
		if ($body eq $textbody) {
			print "<table border width=100%><tr $cb><td><pre>";
			foreach $l (&wrap_lines($body->{'data'},
						$config{'wrap_width'})) {
				print &eucconv_and_escape($l),"\n";
				}
			print "</pre></td></tr></table>\n";
			}
		elsif ($body eq $htmlbody) {
			print "<table border width=100%><tr><td>\n";
			print &safe_html($body->{'data'});
			print "</td></tr></table>\n";
			}

		print "</body></html>\n";
		exit;
		}
	elsif ($in{'mark1'} || $in{'mark2'}) {
		# Just mark the message
		dbmopen(%read, "$module_config_directory/$in{'user'}.read", 0600);
		$mode = $in{'mark1'} ? $in{'mode1'} : $in{'mode2'};
		if ($mode) {
			$read{$mail->{'header'}->{'message-id'}} = $mode;
			}
		else {
			delete($read{$mail->{'header'}->{'message-id'}});
			}
		$perpage = $folder->{'perpage'} || $config{'perpage'};
		$s = int((@mails - $in{'idx'} - 1) / $perpage) * $perpage;
		&redirect("list_mail.cgi?start=$s&folder=$in{'folder'}&user=$in{'user'}");
		exit;
		}
	elsif ($in{'detach'}) {
		# Detach some attachment to a directory on the server
		&error_setup($text{'detach_err'});
		$in{'dir'} || &error($text{'detach_edir'});
		$in{'dir'} = "$uinfo[7]/$in{'dir'}"
			if ($in{'dir'} !~ /^\//);
		&decode_and_sub();

		if ($in{'attach'} eq '*') {
			# Detaching all attachments, under their filenames
			@dattach = grep { $_->{'idx'} ne $in{'bindex'} }
					@{$mail->{'attach'}};
			}
		else {
			# Just one attachment
			@dattach = ( $mail->{'attach'}->[$in{'attach'}] );
			}

		local @paths;
		foreach $attach (@dattach) {
			local $path;
			if (-d $in{'dir'}) {
				# Just write to the filename in the directory
				local $fn;
				if ($attach->{'filename'}) {
					$fn = &decode_mimewords(
						$attach->{'filename'});
					}
				else {
					$attach->{'type'} =~ /\/(\S+)$/;
					$fn = "file.$1";
					}
				$path = "$in{'dir'}/$fn";
				}
			else {
				# Assume a full path was given
				$path = $in{'dir'};
				}
			push(@paths, $path);
			}

		&switch_to_user($in{'user'});
		for($i=0; $i<@dattach; $i++) {
			# Try to write the files
			&open_tempfile(FILE, ">$paths[$i]", 1, 1) ||
				&error(&text('detach_eopen',
					     "<tt>$paths[$i]</tt>", $!));
			(print FILE $dattach[$i]->{'data'}) ||
				&error(&text('detach_ewrite',
					     "<tt>$paths[$i]</tt>", $!));
			close(FILE) ||
				&error(&text('detach_ewrite',
					     "<tt>$paths[$i]</tt>", $!));
			}
		&switch_user_back();

		# Show a message about the new files
		&mail_page_header($text{'detach_title'}, undef, undef,
				  &folder_link($in{'user'}, $folder));

		for($i=0; $i<@dattach; $i++) {
			local $sz = (int(length($dattach[$i]->{'data'}) /
					 1000)+1)." Kb";
			print "<p>",&text('detach_ok',
					  "<tt>$paths[$i]</tt>", $sz),"<p>\n";
			}

		&mail_page_footer("view_mail.cgi?idx=$in{'idx'}&folder=$in{'folder'}&user=$in{'user'}", $text{'view_return'},
			"list_mail.cgi?folder=$in{'folder'}&user=$in{'user'}", $text{'mail_return'},
			"", $text{'index_return'});
		exit;
		}
	elsif ($in{'black'}) {
		# Add sender to global SpamAssassin blacklist, and tell user
		&mail_page_header($text{'black_title'});

		&foreign_require("spam", "spam-lib.pl");
		local $conf = &spam::get_config();
		local @from = map { @{$_->{'words'}} }
			    	  &spam::find("blacklist_from", $conf);
		local %already = map { $_, 1 } @from;
		local ($spamfrom) = &address_parts($mail->{'header'}->{'from'});
		if ($already{$spamfrom}) {
			print "<b>",&text('black_already',
					  "<tt>$spamfrom</tt>"),"</b><p>\n";
			}
		else {
			push(@from, $spamfrom);
			&spam::save_directives($conf, 'blacklist_from',
					       \@from, 1);
			&flush_file_lines();
			print "<b>",&text('black_done',
					  "<tt>$spamfrom</tt>"),"</b><p>\n";
			}

		&mail_page_footer("list_mail.cgi?folder=$in{'folder'}&user=$in{'user'}", $text{'mail_return'}, "", $text{'index_return'});
		exit;
		}
	elsif ($in{'razor'}) {
		# Report message to Razor and tell user
		&mail_page_header($text{'razor_title'});

		print "<b>$text{'razor_report'}</b>\n";
		print "<pre>";
		local $cmd = &spam_report_cmd($in{'user'});
		local $temp = &transname();
		&send_mail($mail, $temp, 0, 1);
		&open_execute_command(OUT, "$cmd <$temp 2>&1", 1);
		local $error;
		while(<OUT>) {
			print &html_escape($_);
			$error++ if (/failed/i);
			}
		close(OUT);
		unlink($temp);
		print "</pre>\n";
		if ($? || $error) {
			print "<b>$text{'razor_err'}</b><p>\n";
			}
		else {
			if ($config{'spam_del'}) {
				# Delete message too
				&lock_folder($folder);
				&mailbox_delete_mail($folder, $mail);
				&unlock_folder($folder);
				print "<b>$text{'razor_deleted'}</b><p>\n";
				}
			else {
				print "<b>$text{'razor_done'}</b><p>\n";
				}
			}

		&mail_page_footer("list_mail.cgi?folder=$in{'folder'}&user=$in{'user'}", $text{'mail_return'}, "", $text{'index_return'});
		exit;
		}

	if (!@mailforward) {
		&parse_mail($mail);
		@attach = @{$mail->{'attach'}};
		}

	if ($in{'strip'}) {
		# Remove all non-body attachments
		local $newmail = { 'headers' => $mail->{'headers'},
				   'header' => $mail->{'header'},
				   'fromline' => $mail->{'fromline'} };
		foreach $a (@attach) {
			if ($a->{'type'} eq 'text/plain' ||
			    $a->{'type'} eq 'text') {
				$newmail->{'attach'} = [ $a ];
				last;
				}
			}
		&lock_folder($folder);
		&mailbox_modify_mail($mail, $newmail, $folder);
		&unlock_folder($folder);
		&redirect("list_mail.cgi?user=$in{'user'}&folder=$in{'folder'}");
		exit;
		}

	if ($in{'enew'}) {
		# Editing an existing message, so keep same fields
		$to = $mail->{'header'}->{'to'};
		$rto = $mail->{'header'}->{'reply-to'};
		$from = $mail->{'header'}->{'from'};
		$cc = $mail->{'header'}->{'cc'};
		$ouser = $1 if ($from =~ /^(\S+)\@/);
		}
	else {
		if (!$in{'forward'} && !@mailforward) {
			# Replying to a message, so set To: field
			$to = $mail->{'header'}->{'reply-to'};
			$to = $mail->{'header'}->{'from'} if (!$to);
			}
		if ($in{'rall'}) {
			# If replying to all, add any addresses in the original
			# To: or Cc: to our new Cc: address.
			# XXX should strip own addresses
			$cc = $mail->{'header'}->{'to'};
			$cc .= ", ".$mail->{'header'}->{'cc'}
				if ($mail->{'header'}->{'cc'});
			}
		}

	# Work out new subject, depending on whether we are replying
	# our forwarding a message (or neither)
	local $qu = !$in{'enew'} &&
		    (!$in{'forward'} || !$config{'fwd_mode'});
	$subject = &html_escape(&decode_mimewords(
				$mail->{'header'}->{'subject'}));
	$subject = "Re: ".$subject if ($subject !~ /^Re/i && !$in{'forward'} &&
				       !@mailforward && !$in{'enew'});
	$subject = "Fwd: ".$subject if ($subject !~ /^Fwd/i &&
					($in{'forward'} || @mailforward));

	# Construct the initial mail text
	$sig = &get_signature($in{'user'});
	($quote, $html_edit, $body) = &quoted_message($mail, $qu, $sig);
	if ($in{'forward'} || $in{'enew'}) {
		@attach = grep { $_ ne $body } @attach;
		}
	else {
		undef(@attach);
		}

	# Show header
	&mail_page_header(
		$in{'forward'} || @mailforward ? $text{'forward_title'} :
		$in{'enew'} ? $text{'enew_title'} :
			      $text{'reply_title'}, undef,
		$html_edit ? "onload='initEditor()'" : "",
		&folder_link($in{'user'}, $folder));
	}

print "<form action=send_mail.cgi method=post enctype=multipart/form-data>\n";

# Output various hidden fields
print "<input type=hidden name=user value='$in{'user'}'>\n";
print "<input type=hidden name=ouser value='$ouser'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=folder value='$in{'folder'}'>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=enew value='$in{'enew'}'>\n";
foreach $s (@sub) {
	print "<input type=hidden name=sub value='$s'>\n";
	}

print "<table width=100% border=1>\n";
print "<tr> <td $tb><b>$text{'reply_headers'}</b></td> </tr>\n";
print "<tr> <td $cb><table width=100%>\n";

# Work out and show the From: address
print "<tr> <td><b>$text{'mail_from'}</b></td>\n";
$from ||= &get_user_from_address(\@uinfo);
if ($access{'fmode'} == 0) {
	# Any email addresss
	print "<td><input name=from size=40 value='$from'></td>\n";
	}
elsif ($access{'fmode'} == 1) {
	# User's name in selected domains
	local $u = $from || $ouser || $in{'user'};
	$u =~ s/\@.*$//;
	print "<td><select name=from>\n";
	foreach $f (split(/\s+/, $access{'from'})) {
		printf "<option value=%s %s>%s\n",
		    "$u\@$f", $from eq "$u\@$f" ? 'selected' : '',
		    $access{'fromname'} ?
			"\"$access{'fromname'}\" &lt;$u\@$f&gt;" : "$u\@$f";
		}
	print "</select></td>\n";
	}
elsif ($access{'fmode'} == 2) {
	# Listed from addresses
	print "<td><select name=from>\n";
	foreach $f (split(/\s+/, $access{'from'})) {
		printf "<option value=%s %s>%s\n",
		    $f, $from eq $f ? 'selected' : '',
		    $access{'fromname'} ? "$access{'fromname'} &lt;$f&gt;" : $f;
		}
	print "</select></td>\n";
	}
elsif ($access{'fmode'} == 3) {
	# Fixed address in fixed domain
	print "<td><input name=from size=10>$ouser\@$access{'from'}</td>\n";
	}

$to = &html_escape($to);
print "<td><b>$text{'mail_to'}</b></td> ",
      "<td><input name=to size=40 value=\"$to\"></td> </tr>\n";

$cc = &html_escape($cc);
print "<tr> <td><b>$text{'mail_cc'}</b></td> ",
      "<td><input name=cc size=40 value=\"$cc\"></td>\n";
print "<td><b>$text{'mail_bcc'}</b></td> ",
      "<td><input name=bcc size=40 value='$config{'bcc_to'}'></td> </tr>\n";
print "<tr> <td><b>$text{'mail_subject'}</b></td> ",
      "<td><input name=subject size=40 value=\"$subject\"></td>\n";
print "<td><b>$text{'mail_pri'}</b></td> ",
      "<td><table cellpadding=0 cellspacing=0 width=100%>\n",
      "<tr><td align=left><select name=pri>\n",
      "<option value=1>$text{'mail_highest'}\n",
      "<option value=2>$text{'mail_high'}\n",
      "<option value='' selected>$text{'mail_normal'}\n",
      "<option value=4>$text{'mail_low'}\n",
      "<option value=5>$text{'mail_lowest'}\n",
      "</select></td>\n",
      "<td align=right><input type=submit value=\"$text{'reply_send'}\">\n",
      "</tr></table></td></tr>\n";
print "</table></td></tr></table><p>\n";

# Output message body input
print "<table width=100% border=1>\n",
      "<tr $tb> <td><b>$text{'reply_body'}</b></td> </tr>",
      "<tr $cb> <td>";
if ($html_edit) {
	# Output HTML editor textarea
	print <<EOF;
<script type="text/javascript">
  _editor_url = "$gconfig{'webprefix'}/$module_name/xinha/";
  _editor_lang = "en";
</script>
<script type="text/javascript" src="xinha/htmlarea.js"></script>

<script type="text/javascript">
var editor = null;
function initEditor() {
  editor = new HTMLArea("body");
  editor.generate();
  return false;
}
</script>
EOF
	print "<textarea rows=20 cols=80 style='width:100%' name=body id=body>",
	      &html_escape($quote),"</textarea>\n";
	}
else {
	# Show text editing area
	print "<textarea rows=20 cols=80 name=body $config{'wrap_mode'}>",
	      &html_escape($quote),"</textarea>\n";
	if (&has_command("ispell")) {
		print "<br>\n";
		print "<input type=checkbox name=spell value=1> $text{'reply_spell'}\n";
		}
	}
print "</td></tr></table><p>\n";
print "<input type=hidden name=html_edit value='$html_edit'>\n";

# Display forwarded attachments
if (@attach) {
	print "<table width=100% border=1>\n";
	print "<tr> <td $tb><b>$text{'reply_attach'}</b></td> </tr>\n";
	print "<tr> <td $cb>\n";
	foreach $a (@attach) {
		push(@titles, "<input type=checkbox name=forward value=$a->{'idx'} checked> ".($a->{'filename'} ? $a->{'filename'} : $a->{'type'}));
		push(@links, "detach.cgi?idx=$in{'idx'}&folder=$in{'folder'}&attach=$a->{'idx'}$subs");
		push(@icons, "images/boxes.gif");
		}
	&icons_table(\@links, \@titles, \@icons, 8);
	print "</td></tr></table><p>\n";
	}

# Display forwarded mails
if (@mailforward) {
	print "<table width=100% border=1>\n";
	print "<tr> <td $tb><b>$text{'reply_mailforward'}</b></td> </tr>\n";
	print "<tr> <td $cb>\n";
	foreach $f (@mailforward) {
		push(@titles, &simplify_subject($mails[$f]->{'header'}->{'subject'}));
		push(@links, "view_mail.cgi?idx=$f&folder=$in{'folder'}&user=$in{'user'}");
		push(@icons, "images/boxes.gif");
		print "<input type=hidden name=mailforward value=$f>\n";
		}
	&icons_table(\@links, \@titles, \@icons, 8);
	print "</td></tr></table><p>\n";
	}

# Add form for more attachments
print "<table width=100% border=1>\n";
print "<tr $tb> <td colspan=3><b>$text{'reply_attach2'}</b></td> </tr>\n";

print "<tr $cb> <td><input type=file size=20 name=attach0></td>\n";
print "<td><input type=file size=20 name=attach1></td>\n";
print "<td><input type=file size=20 name=attach2></td> </tr>\n";

print "<tr $cb> <td><input type=file size=20 name=attach3></td>\n";
print "<td><input type=file size=20 name=attach4></td>\n";
print "<td><input type=file size=20 name=attach5></td> </tr>\n";

if ($access{'canattach'}) {
	print "<tr $cb> <td><input name=file0 size=20> ",
		&file_chooser_button("file0"),"</td>\n";
	print "<td><input name=file1 size=20> ",
		&file_chooser_button("file1"),"</td>\n";
	print "<td><input name=file2 size=20> ",
		&file_chooser_button("file2"),"</td> </tr>\n";
	}

print "</table><p>\n";
print "<input type=submit value=\"$text{'reply_send'}\">\n";
print "</form>\n";

&mail_page_footer("list_mail.cgi?folder=$in{'folder'}&user=$in{'user'}",
	$text{'mail_return'},
	"", $text{'index_return'});

sub decode_and_sub
{
return if (!$mail);
&parse_mail($mail);
@sub = split(/\0/, $in{'sub'});
$subs = join("", map { "&sub=$_" } @sub);
foreach $s (@sub) {
	# We are looking at a mail within a mail ..
	local $amail = &extract_mail(
			$mail->{'attach'}->[$s]->{'data'});
	&parse_mail($amail);
	$mail = $amail;
	}
}

