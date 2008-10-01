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

# Start of the deletion / move form
print &ui_form_start("delete_mail.cgi", "post");
print &ui_hidden("user", $in{'user'});
print &ui_hidden("folder", $folder->{'index'});
print &ui_hidden("mod", &modification_time($folder));
print &ui_hidden("start", $in{'start'});
if ($config{'top_buttons'} && @mail) {
	&show_buttons(1, \@folders, $folder, \@mail, $in{'user'});
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
	@links = ( &select_all_link("d", 1),
		   &select_invert_link("d", 1) );
	print &ui_links_row(\@links);
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

@grid = ( );
if (@mail) {
	# Show simple search form
	push(@grid, &ui_form_start("mail_search.cgi").
		    &ui_hidden("user", $in{'user'}).
		    &ui_hidden("folder", $folder->{'index'}).
		    &ui_hidden("simple", 1).
		    &ui_submit($text{'mail_search2'})." ".
		    &ui_textbox("search", undef, 20).
		    &ui_form_end());

	# Show advanced search button
	push(@grid, &ui_form_start("search_form.cgi").
		    &ui_hidden("user", $in{'user'}).
		    &ui_hidden("folder", $folder->{'index'}).
		    &ui_submit($text{'mail_advanced'}, "advanced").
		    &ui_form_end());

	# Show delete all button
	push(@grid, &ui_form_start("delete_all.cgi").
		    &ui_hidden("user", $in{'user'}).
		    &ui_hidden("folder", $folder->{'index'}).
		    &ui_submit($text{'mail_delall'}).
		    &ui_form_end());
	}

# Show page jump form
$jumpform = (@mail > $perpage);
if ($jumpform) {
	push(@grid, &ui_form_start("list_mail.cgi").
		    &ui_hidden("user", $in{'user'}).
		    &ui_hidden("folder", $folder->{'index'}).
		    &ui_submit($text{'mail_jump'})." ".
		    &ui_textbox("jump", int($in{'start'} / $perpage)+1, 3)." ".
		    $text{'mail_of'}." ".(int(@mail / $perpage)+1).
		    &ui_form_end());
	}

# Show the buttons, if any
if (@grid) {
	print &ui_hr();
	print &ui_grid_table(\@grid, 4, 100,
		  [ "align=left width=25%", "align=center width=25%",
		    "align=center width=25%", "align=right width=25%" ],
		  "cellpadding=0 cellspacing=0");
	}

if ($config{'log_read'}) {
	&webmin_log("read", undef, $in{'user'},
		    { 'file' => $folder->{'file'} });
	}
&ui_print_footer("", $text{'index_return'});

sub show_arrows
{
my $link = "list_mail.cgi?user=".&urlize($in{'user'})."&folder=".$in{'folder'};
my $left = $in{'start'} ?
	   $link."&start=".($in{'start'}-$perpage) : undef;
my $right = $in{'start'}+$perpage < @mail ?
	    $link."&start=".($in{'start'}+$perpage) : undef;
my $first = $in{'start'} ?
	    $link."&start=0" : undef;
my $last = $in{'start'}+$perpage < @mail ?
	   $link."&start=".(int((scalar(@mail)-$perpage-1)/$perpage + 1)*$perpage) : undef;
my $s = @mail-$in{'start'};
my $e = @mail-$in{'start'}-$perpage+1;
print &ui_page_flipper(
	@mail ? &text('mail_pos', $s, $e < 1 ? 1 : $e, scalar(@mail), $sel)
	      : &text('mail_none', $sel),
	&ui_submit($text{'mail_fchange'}).&ui_hidden("user", $in{'user'}),
	"list_mail.cgi",
	$left,
	$right,
	$first,
	$last,
	);
}

