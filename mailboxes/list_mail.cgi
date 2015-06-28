#!/usr/local/bin/perl
# list_mail.cgi
# List the mail messages for some user in some folder

require './mailboxes-lib.pl';
&ReadParse();
&can_user($in{'user'}) || &error($text{'mail_ecannot'});
&is_user($in{'user'}) || -e $in{'user'} || &error($text{'mail_efile'});
$uuser = &urlize($in{'user'});

if ($config{'track_read'}) {
	dbmopen(%read, &user_read_dbm_file($in{'user'}), 0600);
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
print &ui_hidden("dom", $in{'dom'});
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

# Get the mails
@showmail = ( );
for($i=$in{'start'}; $i<@mail && $i<$in{'start'}+$perpage; $i++) {
	push(@showmail, $mail[$i]);
	}
&mail_has_attachments(\@showmail, $folder);

# Show them
if (@mail) {
	&show_mail_table(\@showmail, $folder, 1,
			 $config{'track_read'} ? \%read : undef);
	}

&show_buttons(2, \@folders, $folder, \@mail, $in{'user'});
print &ui_form_end();
if ($config{'arrows'} && @mail) {
        # Show page flipping arrows at the bottom
        &show_arrows();
        }

@grid = ( );
if (@mail) {
	# Show simple search form
	push(@grid, &ui_form_start("mail_search.cgi").
		    &ui_hidden("user", $in{'user'}).
		    &ui_hidden("dom", $in{'dom'}).
		    &ui_hidden("folder", $folder->{'index'}).
		    &ui_hidden("simple", 1).
		    &ui_submit($text{'mail_search2'})." ".
		    &ui_textbox("search", undef, 20).
		    &ui_form_end());

	# Show advanced search button
	push(@grid, &ui_form_start("search_form.cgi").
		    &ui_hidden("user", $in{'user'}).
		    &ui_hidden("dom", $in{'dom'}).
		    &ui_hidden("folder", $folder->{'index'}).
		    &ui_submit($text{'mail_advanced'}, "advanced").
		    &ui_form_end());

	# Show delete all button
	push(@grid, &ui_form_start("delete_all.cgi").
		    &ui_hidden("user", $in{'user'}).
		    &ui_hidden("dom", $in{'dom'}).
		    &ui_hidden("folder", $folder->{'index'}).
		    &ui_submit($text{'mail_delall'}).
		    &ui_form_end());
	}

# Show page jump form
$jumpform = (@mail > $perpage);
if ($jumpform) {
	push(@grid, &ui_form_start("list_mail.cgi").
		    &ui_hidden("user", $in{'user'}).
		    &ui_hidden("dom", $in{'dom'}).
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
&ui_print_footer(&user_list_link(), $text{'index_return'});

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
	&ui_submit($text{'mail_fchange'}).
	  &ui_hidden("user", $in{'user'}).
	  &ui_hidden("dom", $in{'dom'}),
	"list_mail.cgi",
	$left,
	$right,
	$first,
	$last,
	);
}

