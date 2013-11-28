#!/usr/local/bin/perl
# view_mail.cgi
# View a single email message 

require './mailboxes-lib.pl';
&ReadParse();
&can_user($in{'user'}) || &error($text{'mail_ecannot'});
if (&is_user($in{'user'})) {
	@uinfo = &get_mail_user($in{'user'});
	@uinfo || &error($text{'view_eugone'});
	}

$uuser = &urlize($in{'user'});
@folders = &list_user_folders($in{'user'});
$folder = $folders[$in{'folder'}];
@mail = &mailbox_list_mails($in{'idx'}, $in{'idx'}, $folder);
$mail = $mail[$in{'idx'}];
&parse_mail($mail, undef, $in{'raw'});
@sub = split(/\0/, $in{'sub'});
$subs = join("", map { "&sub=$_" } @sub);
foreach $s (@sub) {
        # We are looking at a mail within a mail ..
        local $amail = &extract_mail($mail->{'attach'}->[$s]->{'data'});
        &parse_mail($amail, undef, $in{'raw'});
        $mail = $amail;
        }

dbmopen(%read, "$module_config_directory/$in{'user'}.read", 0600);
eval { $read{$mail->{'header'}->{'message-id'}} = 1 }
	if (!$read{$mail->{'header'}->{'message-id'}});

if ($in{'raw'}) {
	# Special mode - viewing whole raw message
	print "Content-type: text/plain\n\n";
	if ($mail->{'fromline'}) {
		print $mail->{'fromline'},"\n";
		}
	if (defined($mail->{'rawheaders'})) {
		#$mail->{'rawheaders'} =~ s/(\S)\t/$1\n\t/g;
		print $mail->{'rawheaders'};
		}
	else {
		foreach $h (@{$mail->{'headers'}}) {
			#$h->[1] =~ s/(\S)\t/$1\n\t/g;
			print "$h->[0]: $h->[1]\n";
			}
		}
	print "\n";
	print $mail->{'body'};
	return;
	}

# Find body attachment and type
($textbody, $htmlbody, $body) = &find_body($mail, $config{'view_html'});
$body = $htmlbody if ($in{'body'} == 2);
$body = $textbody if ($in{'body'} == 1);
@attach = @{$mail->{'attach'}};

# Show pre-body HTML
if ($body && $body eq $htmlbody) {
	$headstuff = &head_html($body->{'data'});
	}

# Set the character set for the page to match email
$main::force_charset = &get_mail_charset($mail, $body);

&mail_page_header($text{'view_title'}, $headstuff, undef,
		  &folder_link($in{'user'}, $folder));
print &check_clicks_function();
&show_arrows();

# Start of the form
print &ui_form_start("reply_mail.cgi");
print &ui_hidden("user", $in{'user'});
print &ui_hidden("dom", $in{'dom'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("folder", $in{'folder'});
print &ui_hidden("mod", &modification_time($folder));
foreach $s (@sub) {
	print &ui_hidden("sub", $s);
	}

# Find any delivery status attachment
($dstatus) = grep { $_->{'type'} eq 'message/delivery-status' } @attach;

# Strip out attachments not to display as icons
@attach = grep { $_ ne $body && $_ ne $dstatus } @attach;
@attach = grep { !$_->{'attach'} } @attach;

if ($config{'top_buttons'} == 2 && &editable_mail($mail)) {
	&show_mail_buttons(1, scalar(@sub));
	print "<p>\n";
	}

# Start of headers section
$hbase = "view_mail.cgi?idx=$in{'idx'}&body=$in{'body'}&".
	 "folder=$in{'folder'}&dom=$in{'dom'}&user=$uuser$subs";
if ($in{'headers'}) {
	push(@hmode, "<a href='$hbase&headers=0'>$text{'view_noheaders'}</a>");
	}
else {
	push(@hmode, "<a href='$hbase&headers=1'>$text{'view_allheaders'}</a>");
	}
push(@hmode, "<a href='$hbase&raw=1'>$text{'view_raw'}</a>");
print &ui_table_start($text{'view_headers'},
		      "width=100%", 2, [ "width=10% nowrap" ],
		      &ui_links_row(\@hmode));

if ($in{'headers'}) {
	# Show all the headers
	if ($mail->{'fromline'}) {
		print &ui_table_row($text{'mail_rfc'},
			&eucconv_and_escape($mail->{'fromline'}));
		}
	foreach $h (@{$mail->{'headers'}}) {
		print &ui_table_row($h->[0].":",
			&eucconv_and_escape(&decode_mimewords($h->[1])));
		}
	}
else {
	# Just show the most useful headers
	print &ui_table_row($text{'mail_from'},
		&address_link($mail->{'header'}->{'from'}));
	print &ui_table_row($text{'mail_to'},
		&address_link($mail->{'header'}->{'to'}));
	if ($mail->{'header'}->{'cc'}) {
		print &ui_table_row($text{'mail_cc'},
			&address_link($mail->{'header'}->{'cc'}));
		}
	print &ui_table_row($text{'mail_date'},
		&eucconv_and_escape(
                        &simplify_date($mail->{'header'}->{'date'})));
	print &ui_table_row($text{'mail_subject'},
		&eucconv_and_escape(&decode_mimewords(
                                        $mail->{'header'}->{'subject'})));
	}
print &ui_table_end();

# Show body attachment, with properly linked URLs
@bodyright = ( );
if ($body && $body->{'data'} =~ /\S/) {
	if ($body eq $textbody) {
		# Show plain text
		$bodycontents = "<pre>";
		foreach $l (&wrap_lines(&eucconv($body->{'data'}),
					$config{'wrap_width'})) {
			$bodycontents .= &link_urls_and_escape($l,
						$config{'link_mode'})."\n";
			}
		$bodycontents .= "</pre>";
		if ($htmlbody && $userconfig{'view_html'} != 0) {
			push(@bodyright,
			    "<a href='$hbase&body=2'>$text{'view_ashtml'}</a>");
			}
		}
	elsif ($body eq $htmlbody) {
		# Attempt to show HTML
		$bodycontents = &safe_html($body->{'data'});
		$bodycontents = &fix_cids($bodycontents, \@attach,
			"detach.cgi?user=$uuser&idx=$in{'idx'}&folder=$in{'folder'}$subs");
		if ($textbody) {
			push(@bodyright,
			    "<a href='$hbase&body=1'>$text{'view_ashtml'}</a>");
			}
		}
	}
if ($bodycontents) {
	print &ui_table_start($text{'view_body'}, "width=100%", 1,
                              undef, &ui_links_row(\@bodyright));
	print &ui_table_row(undef, $bodycontents);
	print &ui_table_end();
	}
else {
	print &ui_table_start($text{'view_body'}, "width=100%", 1);
	print &ui_table_row(undef, "<b>$text{'view_nobody'}</b>");
	print &ui_table_end();
	}

# Show delivery status
if ($dstatus) {
	&show_delivery_status($dstatus);
	}

# Display other attachments
if (@attach) {
	# Table of attachments
	$viewurl = "view_mail.cgi?idx=$in{'idx'}&folder=$in{'folder'}&".
		   "user=$uuser$subs";
	$detachurl = "detach.cgi?idx=$in{'idx'}&folder=$in{'folder'}&".
		     "user=$uuser$subs";
        @detach = &attachments_table(\@attach, $folder, $viewurl, $detachurl,
				     undef, undef, undef);

	# Links to download all / slideshow
	@links = ( );
	if (@attach > 1) {
		push(@links, "<a href='detachall.cgi/attachments.zip?folder=$in{'folder'}&idx=$in{'idx'}&user=$uuser$subs'>$text{'view_aall'}</a>");
		}
	@iattach = grep { $_->{'type'} =~ /^image\// } @attach;
	if (@iattach > 1) {
		push(@links, "<a href='slideshow.cgi?folder=$in{'folder'}&idx=$in{'idx'}&user=$uuser$subs'>$text{'view_aslideshow'}</a>");
		}
	print &ui_links_row(\@links) if (@links);

	# Show form to detact to server, if enabled
	if ($access{'candetach'} && @detach && defined($uinfo[2])) {
                print &ui_table_start($text{'view_dheader'}, "width=100%", 1);
                $dtach = &ui_submit($text{'view_detach'}, 'detach');
                $dtach .= &ui_hidden("bindex", $body->{'idx'}) if ($body);
                $dtach .= &ui_hidden("sindex", $sindex) if (defined($sindex));
                $dtach .= &ui_select("attach", undef,
                                [ [ '*', $text{'view_dall'} ],
                                  @detach ]);
                $dtach .= "<b>$text{'view_dir'}</b>\n";
                $dtach .= &ui_textbox("dir", undef, 60)." ".
                          &file_chooser_button("dir", 1);
                print &ui_table_row(undef, $dtach);
                print &ui_table_end();
                }
	}

&show_mail_buttons(2, scalar(@sub)) if (&editable_mail($mail));
if ($config{'arrows'} == 2 && !@sub) {
        &show_arrows();
        }
print "</form>\n";

dbmclose(%read);

# Footer with backlinks
local @sr = !@sub ? ( ) :
    ( "view_mail.cgi?idx=$in{'idx'}", $text{'view_return'} ),
$s = int((@mail - $in{'idx'} - 1) / $config{'perpage'}) *
	$config{'perpage'};
&mail_page_footer(
	@sub ? ("view_mail.cgi?idx=$in{'idx'}&folder=$in{'folder'}&".
		"user=$uuser&dom=$in{'dom'}", $text{'view_return'})
	     : ( ),
	"list_mail.cgi?folder=$in{'folder'}&user=$uuser&dom=$in{'dom'}",
	  $text{'mail_return'},
	&user_list_link(), $text{'index_return'});

# show_mail_buttons(pos, submode)
sub show_mail_buttons
{
local $spacer = "&nbsp;\n";
if (!$_[1]) {
	print "<input type=submit value=\"$text{'view_delete'}\" name=delete ",
	      "onClick='return check_clicks(form)'>";
	print $spacer;

	if (!$folder->{'sent'} && !$folder->{'drafts'}) {
		$m = $read{$mail->{'header'}->{'message-id'}};
		print "<input name=mark$_[0] type=submit value=\"$text{'view_mark'}\">";
		print "<select name=mode$_[0]>\n";
		foreach $i (0 .. 2) {
			printf "<option value=%d %s>%s\n",
				$i, $m == $i ? 'selected' : '', $text{"view_mark$i"};
			}
		print "</select>";
		print $spacer;
		}
	}
if (&is_user($in{'user'})) {
	print "<input type=submit value=\"$text{'view_forward'}\" name=forward>";
	print $spacer;
	}

print "<input type=submit value=\"$text{'view_print'}\" name=print>";
print $spacer;

if (&is_user($in{'user'})) {
	print "<input type=submit value=\"$text{'view_reply'}\" name=reply>";
	print "<input type=submit value=\"$text{'view_reply2'}\" name=rall>";
	print $spacer;
	}

print "<input type=submit value=\"$text{'view_strip'}\" name=strip>";
print $spacer;

# Show spam report buttons
@modules = &get_available_module_infos(1);
($hasspam) = grep { $_->{'dir'} eq "spam" } @modules;
if (&foreign_installed("spam") &&
    $config{'spam_buttons'} =~ /mail/ &&
    &spam_report_cmd($in{'user'})) {
	if ($hasspam) {
		print "<input type=submit value=\"$text{'view_black'}\" name=black>";
		}
	if ($config{'spam_del'}) {
		print "<input type=submit value=\"$text{'view_razordel'}\" name=razor>\n";
		}
	else {
		print "<input type=submit value=\"$text{'view_razor'}\" name=razor>\n";
		}
	}
print "<br>\n";
}

sub show_arrows
{
print "<center>\n";
if (!@sub) {
	if ($in{'idx'}) {
		print "<a href='view_mail.cgi?idx=",
		    $in{'idx'}-1,"&folder=$in{'folder'}&user=$uuser'>",
		    "<img src=$gconfig{'webprefix'}/images/left.gif border=0 ",
		    "align=middle></a>\n";
		}
	print "<font size=+1>",&text('view_desc', $in{'idx'}+1,
			$folder->{'name'}),"</font>\n";
	if ($in{'idx'} < @mail-1) {
		print "<a href='view_mail.cgi?idx=",
		    $in{'idx'}+1,"&folder=$in{'folder'}&user=$uuser'>",
		    "<img src=$gconfig{'webprefix'}/images/right.gif border=0 ",
		    "align=middle></a>\n";
		}
	}
else {
	print "<font size=+1>$text{'view_sub'}</font>\n";
	}
print "</center><br>\n";
}

# address_link(address)
sub address_link
{
local @addrs = &split_addresses(&decode_mimewords($_[0]));
local @rv;
foreach $a (@addrs) {
	push(@rv, &eucconv_and_escape($a->[2]));
	}
return join(" , ", @rv);
}

