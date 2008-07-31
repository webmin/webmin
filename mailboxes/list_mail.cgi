#!/usr/local/bin/perl
# list_mail.cgi
# List the mail messages for some user in some folder

require './mailboxes-lib.pl';
&ReadParse();
&can_user($in{'user'}) || &error($text{'mail_ecannot'});
&is_user($in{'user'}) || -e $in{'user'} || &error($text{'mail_efile'});
$uuser = &urlize($in{'user'});

if ($config{'track_read'}) {
	dbmopen(%read, "$module_config_directory/$in{'user'}.read", 0600);
	}

# Make sure the mail system is OK
$err = &test_mail_system();
if ($err) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	if (!$access{'noconfig'}) {
		&ui_print_endpage(&text('index_esystem3',
					"../config.cgi?$module_name", $err));
		}
	else {
		&ui_print_endpage(&text('mail_esystem', $err));
		}
	}

&ui_print_header(undef, $text{'mail_title'}, "");
print &check_clicks_function();
@folders = &list_user_folders_sorted($in{'user'});
($folder) = grep { $_->{'index'} == $in{'folder'} } @folders;

# Get folder-selection HTML
$sel = &folder_select(\@folders, $folder, "folder", undef, 0, 1);

# Work out start from jump page
$perpage = $folder->{'perpage'} || $config{'perpage'};
if ($in{'jump'} =~ /^\d+$/ && $in{'jump'} > 0) {
	$in{'start'} = ($in{'jump'}-1)*$perpage;
	}

# View mail from the most recent
@mail = reverse(&mailbox_list_mails(-$in{'start'},
				    -$in{'start'}-$perpage+1,
				    $folder, 1, \@error));
if ($in{'start'} >= @mail && $in{'jump'}) {
	# Jumped too far!
	$in{'start'} = @mail - $perpage;
	@mail = reverse(&mailbox_list_mails(-$in{'start'},
					    -$in{'start'}-$perpage+1,
					    $folder, 1, \@error));
	}

# Show page flipping arrows
&show_arrows();

print "<form action=delete_mail.cgi method=post>\n";
print "<input type=hidden name=user value='$in{'user'}'>\n";
print "<input type=hidden name=folder value='$folder->{'index'}'>\n";
print "<input type=hidden name=mod value=",&modification_time($folder),">\n";
print "<input type=hidden name=start value='$in{'start'}'>\n";
if ($config{'top_buttons'} && @mail) {
	&show_buttons(1, \@folders, $folder, \@mail, $in{'user'});
	@links = ( &select_all_link("d", 1),
		   &select_invert_link("d", 1) );
	print &ui_links_row(\@links);
	}

# Show error opening folder
if (@error) {
	print "<center><b><font color=#ff0000>\n";
	print &text('mail_err', $error[0] == 0 ? $error[1] :
			      &text('save_elogin', $error[1])),"\n";
	print "</font></b></center>\n";
	}

$showto = $folder->{'sent'} || $folder->{'drafts'};
@tds = ( "width=5", "nowrap", "nowrap", "nowrap", "nowrap" );
if (@mail) {
	# Show mailbox headers
	local @hcols;
	push(@hcols, "");
	push(@hcols, $showto ? $text{'mail_to'} : $text{'mail_from'});
	push(@hcols, $config{'show_to'} ? $showto ? ( $text{'mail_from'} ) :
						    ( $text{'mail_to'} ) : ());
	push(@hcols, $text{'mail_date'});
	push(@hcols, $text{'mail_size'});
	push(@hcols, $text{'mail_subject'});
	print &ui_columns_start(\@hcols, 100, 0, \@tds);
	}

# Get the mails
@showmail = ( );
for($i=$in{'start'}; $i<@mail && $i<$in{'start'}+$perpage; $i++) {
	push(@showmail, $mail[$i]);
	}
@hasattach = &mail_has_attachments(\@showmail, $folder);

# Show rows for actual mail messages
$i = 0;
foreach my $mail (@showmail) {
	local $idx = $mail->{'idx'};
	local $cols = 0;
	local @cols;
	local $from = $mail->{'header'}->{$showto ? 'to' : 'from'};
	$from = $text{'mail_unknown'} if ($from !~ /\S/);
	push(@cols, &view_mail_link($in{'user'}, $folder, $idx, $from));
	if ($config{'show_to'}) {
		push(@cols, &simplify_from(
	   		$mail->{'header'}->{$showto ? 'from' : 'to'}));
		}
	push(@cols, &simplify_date($mail->{'header'}->{'date'}));
	push(@cols, &nice_size($mail->{'size'}, 1024));
	local $tbl;
	$tbl .= "<table border=0 cellpadding=0 cellspacing=0 width=100%>".
	      "<tr><td>".&simplify_subject($mail->{'header'}->{'subject'}).
	      "</td> <td align=right>";
	if ($hasattach[$i]) {
		$tbl .= "<img src=images/attach.gif>";
		}
	local $p = int($mail->{'header'}->{'x-priority'});
	if ($p == 1) {
		$tbl .= "&nbsp;<img src=images/p1.gif>";
		}
	elsif ($p == 2) {
		$tbl .= "&nbsp;<img src=images/p2.gif>";
		}
	if (!$showto) {
		if ($read{$mail->{'header'}->{'message-id'}} == 2) {
			$tbl .= "&nbsp;<img src=images/special.gif>";
			}
		elsif ($read{$mail->{'header'}->{'message-id'}} == 1) {
			$tbl .= "&nbsp;<img src=images/read.gif>";
			}
		}
	$tbl .= "</td></tr></table>\n";
	push(@cols, $tbl);

	if (&editable_mail($mail)) {
		print &ui_checked_columns_row(\@cols, \@tds, "d", $idx);
		}
	else {
		print &ui_columns_row([ "", @cols ], \@tds);
		}

	if ($config{'show_body'}) {
                # Show part of the body too
                &parse_mail($mail);
		local $data = &mail_preview($mail);
		if ($data) {
                        print "<tr $cb> <td colspan=",(scalar(@cols)+1),"><tt>",
				&html_escape($data),"</tt></td> </tr>\n";
			}
                }
	$i++;
	}
if (@mail) {
	print &ui_columns_end();
	print &ui_links_row(\@links);
	}

&show_buttons(2, \@folders, $folder, \@mail, $in{'user'});
print "</form>\n";
if ($config{'arrows'} && @mail) {
        # Show page flipping arrows at the bottom
        &show_arrows();
        }

if (@mail) {
	print &ui_hr();
	print "<table width=100%><tr>\n";

	# Show simple search form
	print "<form action=mail_search.cgi><td width=30%>\n";
	print "<input type=hidden name=user value='$in{'user'}'>\n";
	print "<input type=hidden name=folder value='$folder->{'index'}'>\n";
	print "<input type=hidden name=simple value=1>\n";
	print "<input type=submit value='$text{'mail_search2'}'>\n";
	print "<input name=search size=20></td></form>\n";

	# Show advanced search button
	print "<form action=search_form.cgi>\n";
	print "<input type=hidden name=user value='$in{'user'}'>\n";
	print "<input type=hidden name=folder value='$folder->{'index'}'>\n";
	print "<td width=20% align=center><input type=submit name=advanced ",
	      "value='$text{'mail_advanced'}'></td>\n";
	print "</form>\n";

	# Show delete all button
	print "<form action=delete_all.cgi>\n";
	print "<input type=hidden name=user value='$in{'user'}'>\n";
	print "<input type=hidden name=folder value='$folder->{'index'}'>\n";
	print "<td width=20% align=center><input type=submit ",
	      "value='$text{'mail_delall'}'></td>\n";
	print "</form>\n";
	}

# Show page jump form
$jumpform = (@mail > $perpage);
if ($jumpform) {
	print "<form action=list_mail.cgi>\n";
	print "<input type=hidden name=user value='$in{'user'}'>\n";
	print "<input type=hidden name=folder value='$folder->{'index'}'>\n";
	print "<td width=30% align=right>\n";
	print "<input type=submit value='$text{'mail_jump'}'>\n";
	printf "<input name=jump size=3 value='%s'> %s %s\n",
		int($in{'start'} / $perpage)+1, $text{'mail_of'},
		int(@mail / $perpage)+1;
	print "</td></form>\n";
	}
elsif (@mail) {
	print "<td width=30% align=right></td>\n";
	}

if (@mail) {
	print "</tr>\n";
	print "</table>\n";
	}

if ($config{'log_read'}) {
	&webmin_log("read", undef, $in{'user'},
		    { 'file' => $folder->{'file'} });
	}
&ui_print_footer("", $text{'index_return'});

sub show_arrows
{
print "<center>\n";
print "<form action=list_mail.cgi><font size=+1>\n";
print "<input type=hidden name=user value='$in{'user'}'>\n";
if ($in{'start'}+$perpage < @mail) {
	printf "<a href='list_mail.cgi?start=%d&user=%s&folder=%d'>".
	       "<img src=/images/left.gif border=0 align=middle></a>\n",
		$in{'start'}+$perpage, $uuser, $in{'folder'};
	}

local $s = @mail-$in{'start'};
local $e = @mail-$in{'start'}-$perpage+1;
if (@mail) {
	print &text('mail_pos', $s, $e < 1 ? 1 : $e, scalar(@mail), $sel);
	}
else {
	print &text('mail_none', $sel);
	}
print "</font><input type=submit value='$text{'mail_fchange'}'>\n";

if ($in{'start'}) {
	printf "<a href='list_mail.cgi?start=%d&user=%s&folder=%d'>".
	       "<img src=/images/right.gif border=0 align=middle></a>\n",
		$in{'start'}-$perpage, $uuser, $in{'folder'};
	}
print "</form></center>\n";
}

