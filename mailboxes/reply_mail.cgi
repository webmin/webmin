#!/usr/local/bin/perl
# Display a form for replying to or composing an email

require './mailboxes-lib.pl';
&ReadParse();
&can_user($in{'user'}) || &error($text{'mail_ecannot'});
@uinfo = &get_mail_user($in{'user'});
@uinfo || &error($text{'view_eugone'});
$euser = &urlize($in{'user'});

@folders = &list_user_folders($in{'user'});
$folder = $folders[$in{'folder'}];
if ($in{'new'}) {
	# Composing a new email
	if (defined($in{'html'})) {
		$html_edit = $in{'html'};
		}
	else {
		$html_edit = $config{'html_edit'} == 2 ? 1 : 0;
		}
	$sig = &get_signature($in{'user'});
	if ($html_edit) {
		$sig =~ s/\n/<br>\n/g;
		$quote = "<html><body></body></html>";
		}
	else {
		$quote = "\n\n$sig" if ($sig);
		}
	$to = $in{'to'};
	$main::force_charset = &get_charset();
	&mail_page_header($text{'compose_title'}, undef,
			  $html_edit ? "onload='xinha_init()'" : "",
			  &folder_link($in{'user'}, $folder));
	}
else {
	# Replying or forwarding
	if ($in{'mailforward'} ne '') {
		# Forwarding multiple
		@mailforward = sort { $a <=> $b }
				    split(/\0/, $in{'mailforward'});
		@mails = &mailbox_list_mails(
			     $mailforward[0], $mailforward[@mailforward-1],
			     $folder);
		$mail = $mails[$mailforward[0]];
		@fwdmail = map { $mails[$_] } @mailforward;
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

	# Find the body parts and set the character set
	($textbody, $htmlbody, $body) =
		&find_body($mail, $config{'view_html'});
	$mail_charset = &get_mail_charset($mail, $body);
	if (&get_charset() eq 'UTF-8' &&
	    &can_convert_to_utf8(undef, $mail_charset)) {
		# Convert to UTF-8
		$body->{'data'} = &convert_to_utf8($body->{'data'},
						   $mail_charset);
		$main::force_charset = 'UTF-8';
		}
	else {
		# Set the character set for the page to match email
		$main::force_charset = $mail_charset;
		}

	if ($in{'delete'}) {
		# Just delete the email
		if (!$in{'confirm'} && &need_delete_warn($folder)) {
			# Need to ask for confirmation before deleting
			&mail_page_header($text{'confirm_title'}, undef, undef,
					  &folder_link($in{'user'}, $folder));
			print &ui_confirmation_form(
				"reply_mail.cgi",
				$text{'confirm_warn3'}."<br>".
				($config{'delete_warn'} ne 'y' ?
					$text{'confirm_warn2'} :
					$text{'confirm_warn4'}),
				[ &inputs_to_hiddens(\%in) ],
				[ [ 'confirm', $text{'confirm_ok'} ] ],
				);
			&mail_page_footer("view_mail.cgi?idx=$in{'idx'}&folder=$in{'folder'}&user=$euser&dom=$in{'dom'}",
				$text{'view_return'},
				"list_mail.cgi?folder=$in{'folder'}&user=$euser&dom=$in{'dom'}",
				$text{'mail_return'},
				&user_list_link(), $text{'index_return'});
			exit;
			}
		&lock_folder($folder);
		&mailbox_delete_mail($folder, $mail);
		&unlock_folder($folder);
		&webmin_log("delmail", undef, undef,
			    { 'from' => $folder->{'file'},
			      'count' => 1 } );
		&redirect("list_mail.cgi?folder=$in{'folder'}&user=$euser".
			  "&dom=$in{'dom'}");
		exit;
		}
	elsif ($in{'print'}) {
		# Show email for printing
		&decode_and_sub();
                &ui_print_header(undef, &decode_mimewords(
                                        $mail->{'header'}->{'subject'}));
                &show_mail_printable($mail, $body, $textbody, $htmlbody);
                print "<script>window.print();</script>\n";
                &ui_print_footer();
		exit;
		}
	elsif ($in{'mark1'} || $in{'mark2'}) {
		# Just mark the message
		$mode = $in{'mark1'} ? $in{'mode1'} : $in{'mode2'};
		&set_mail_read($folder, $mail, $mode);
		$perpage = $folder->{'perpage'} || $config{'perpage'};
		$s = int((@mails - $in{'idx'} - 1) / $perpage) * $perpage;
		&redirect("list_mail.cgi?start=$s&folder=$in{'folder'}".
			  "&user=$euser&dom=$in{'dom'}");
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

		&mail_page_footer("view_mail.cgi?idx=$in{'idx'}&folder=$in{'folder'}&user=$euser&dom=$in{'dom'}", $text{'view_return'},
			"list_mail.cgi?folder=$in{'folder'}&user=$euser&dom=$in{'dom'}", $text{'mail_return'},
			&user_list_link(), $text{'index_return'});
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

		&mail_page_footer("list_mail.cgi?folder=$in{'folder'}&user=$euser&dom=$in{'dom'}", $text{'mail_return'}, &user_list_link(), $text{'index_return'});
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

		&mail_page_footer("list_mail.cgi?folder=$in{'folder'}&user=$euser&dom=$in{'dom'}", $text{'mail_return'}, &user_list_link(), $text{'index_return'});
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
		&redirect("list_mail.cgi?user=$euser&folder=$in{'folder'}".
			  "&dom=$in{'dom'}");
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
			$cc = $mail->{'header'}->{'to'};
			$cc .= ", ".$mail->{'header'}->{'cc'}
				if ($mail->{'header'}->{'cc'});
			}
		}

	# Convert MIMEwords in headers to 8 bit for display
        $to = &decode_mimewords($to);
        $rto = &decode_mimewords($rto);
        $cc = &decode_mimewords($cc);
        $bcc = &decode_mimewords($bcc);

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
		$html_edit ? "onload='xinha_init()'" : "",
		&folder_link($in{'user'}, $folder));
	}

# Show form start, with upload progress tracker hook
$upid = time().$$;
$onsubmit = &read_parse_mime_javascript($upid, [ map { "attach$_" } (0..10) ]);
print &ui_form_start("send_mail.cgi?id=$upid", "form-data", undef, $onsubmit);

# Output various hidden fields
print &ui_hidden("user", $in{'user'});
print &ui_hidden("dom", $in{'dom'});
print &ui_hidden("ouser", $ouser);
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("folder", $in{'folder'});
print &ui_hidden("new", $in{'new'});
print &ui_hidden("enew", $in{'enew'});
foreach $s (@sub) {
	print &ui_hidden("sub", $s);
	}
print &ui_hidden("charset", $main::force_charset);

# Start tabs for from / to / cc / bcc
# Subject is separate
print &ui_table_start($text{'reply_headers'}, "width=100%", 2);
@tds = ( "width=10%", "width=90% nowrap" );
@tabs = ( [ "from", $text{'reply_tabfrom'} ],
          [ "to", $text{'reply_tabto'} ],
          [ "cc", $text{'reply_tabcc'} ],
          [ "bcc", $text{'reply_tabbcc'} ],
          [ "options", $text{'reply_taboptions'} ] );
print &ui_table_row(undef, &ui_tabs_start(\@tabs, "tab", "to", 0), 2);

# From address tab
$from ||= &get_user_from_address(\@uinfo);
@froms = split(/\s+/, $access{'from'});
if ($access{'fmode'} == 0) {
	# Any email addresss
	$frominput = &ui_address_field("from", $from, 1, 0);
	}
elsif ($access{'fmode'} == 1) {
	# Current username at some domains
	local $u = $from || $ouser || $in{'user'};
	$u =~ s/\@.*$//;
	$frominput = &ui_select("from", $from,
		$access{'fromname'} ?
			[ map { [ "$access{'fromname'} &lt;$u\@$_&gt;",
				  "$u\@$_" ] } @froms ] :
			[ map { "$u\@$_" } @froms ]);
	}
elsif ($access{'fmode'} == 2) {
	# Listed from addresses
	$frominput = &ui_select("from", $from,
		$access{'fromname'} ?
			[ map { [ "$access{'fromname'} &lt;$_&gt;", $_ ] }
			      @froms ] :
			\@froms);
	}
elsif ($access{'fmode'} == 3) {
	# Fixed address in fixed domain
	$frominput = "<tt>$ouser\@$access{'from'}</tt>".
		     &ui_hidden("from", "$ouser\@$access{'from'}");
	}
print &ui_tabs_start_tabletab("tab", "from");
print &ui_table_row($text{'mail_from'}, $frominput, 1, \@tds);
print &ui_tabs_end_tabletab();

# Show To: field
print &ui_tabs_start_tabletab("tab", "to");
print &ui_table_row($text{'mail_to'}, &ui_address_field("to", $to, 0, 1),
                    1, \@tds);
print &ui_tabs_end_tabletab();

# Show Cc: field
print &ui_tabs_start_tabletab("tab", "cc");
print &ui_table_row($text{'mail_cc'}, &ui_address_field("cc", $cc, 0, 1),
                    1, \@tds);
print &ui_tabs_end_tabletab();

# Show Bcc: field
$bcc ||= $config{'bcc_to'};
print &ui_tabs_start_tabletab("tab", "bcc");
print &ui_table_row($text{'mail_bcc'}, &ui_address_field("bcc", $bcc, 0, 1),
                    1, \@tds);
print &ui_tabs_end_tabletab();

# Show tab for options
print &ui_tabs_start_tabletab("tab", "options");
print &ui_table_row($text{'mail_pri'},
                &ui_select("pri", "",
                        [ [ 1, $text{'mail_highest'} ],
                          [ 2, $text{'mail_high'} ],
                          [ "", $text{'mail_normal'} ],
                          [ 4, $text{'mail_low'} ],
                          [ 5, $text{'mail_lowest'} ] ]), 1, \@tds);
print &ui_tabs_end_tabletab();
print &ui_tabs_end();

# Subject field, outside tabs
print &ui_table_row($text{'mail_subject'},
	&ui_textbox("subject", $subject, 40, 0, undef,
		    "style='width:95%'"), 1, \@tds);
print &ui_table_end();

# Create link for switching to HTML/text mode for new mail
@bodylinks = ( );
if ($in{'new'}) {
	if ($html_edit) {
		push(@bodylinks, &ui_link("reply_mail.cgi?folder=$in{'folder'}&user=$euser&new=1&html=0",$text{'reply_html0'}));
		}
	else {
		push(@bodylinks, &ui_link("reply_mail.cgi?folder=$in{'folder'}&user=$euser&new=1&html=1",$text{'reply_html1'}));
		}
	}

# Output message body input
print &ui_table_start($text{'reply_body'}, "width=100%", 2, undef,
		      &ui_links_row(\@bodylinks));
if ($html_edit) {
	if ($current_theme !~ /authentic-theme/) {
		# Output HTML editor textarea
		print <<EOF;
	<script type="text/javascript">
	  _editor_url = "$gconfig{'webprefix'}/$module_name/xinha/";
	  _editor_lang = "en";
	</script>
	<script type="text/javascript" src="xinha/XinhaCore.js"></script>

	<script type="text/javascript">
	xinha_init = function()
	{
	xinha_editors = [ "body" ];
	xinha_plugins = [ ];
	xinha_config = new Xinha.Config();
	xinha_config.hideSomeButtons(" print showhelp about killword toggleborders ");
	xinha_editors = Xinha.makeEditors(xinha_editors, xinha_config, xinha_plugins);
	Xinha.startEditors(xinha_editors);
	}
	</script>
EOF
		}
	else {
	print '<script type="text/javascript">xinha_init = function(){}</script>';
		}
	print &ui_table_row(undef,
		&ui_textarea("body", $quote, 40, 80, undef, 0,
		  	     "style='width:99%' id=body"), 2);
	}
else {
	# Show text editing area
	$wm = $config{'wrap_mode'};
	$wm =~ s/^wrap=//g;
	$wcols = $config{'wrap_compose'};
	print &ui_table_row(undef,
		&ui_textarea("body", $quote, 20,
			     $wcols || 80,
			     $wcols ? "hard" : "",
			     0,
			     $wcols ? "" : "style='width:100%'"), 2);
	}
if (&has_command("ispell")) {
	print &ui_table_row(undef,
	      &ui_checkbox("spell", 1, $text{'reply_spell'}, 0), 2);
	}
print &ui_table_end();
print &ui_hidden("html_edit", $html_edit);

# Display forwarded attachments
$viewurl = "view_mail.cgi?idx=$in{'idx'}&user=$euser&".
           "&folder=$folder->{'index'}$subs";
$detachurl = "detach.cgi?idx=$in{'idx'}&user=$euser&".
             "&folder=$folder->{'index'}$subs";
$mailurl = "view_mail.cgi?user=$euser&folder=$folder->{'index'}$subs";
if (@attach) {
        &attachments_table(\@attach, $folder, $viewurl, $detachurl,
			   $mailurl, 'idx', "forward");
        }

# Display forwarded mails
if (@fwdmail) {
	&attachments_table(\@fwdmail, $folder, $viewurl, $detachurl,
			   $mailurl, 'idx');
	foreach $f (@mailforward) {
		print &ui_hidden("mailforward", $f);
		}
	}

# Display new attachment fields
&show_attachments_fields(3, $access{'canattach'});

print &ui_form_end([ [ undef, $text{'reply_send'} ] ]);

&mail_page_footer("list_mail.cgi?folder=$in{'folder'}&user=$in{'user'}".
		  "&dom=$in{'dom'}", $text{'mail_return'},
		  &user_list_link(), $text{'index_return'});

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
