#!/usr/local/bin/perl
# mail_search.cgi
# Find mail messages matching some pattern

require './mailboxes-lib.pl';
&ReadParse();
&can_user($in{'user'}) || &error($text{'mail_ecannot'});
@folders = &list_user_folders($in{'user'});
$uuser = &urlize($in{'user'});

if ($in{'simple'}) {
	# Make sure a search was entered
	$in{'search'} || &error($text{'search_ematch'});
	$ofolder = $folders[$in{'folder'}];
	}
else {
	# Validate search fields
	for($i=0; defined($in{"field_$i"}); $i++) {
		if ($in{"field_$i"}) {
			$in{"what_$i"} || &error(&text('search_ewhat', $i+1));
			$neg = $in{"neg_$i"} ? "!" : "";
			push(@fields, [ $neg.$in{"field_$i"}, $in{"what_$i"} ]);
			}
		}
	@fields || &error($text{'search_enone'});
	$ofolder = $folders[$in{'ofolder'}];
	}

if ($in{'folder'} == -2) {
	$desc = $text{'search_local'};
	}
elsif ($in{'folder'} == -1) {
	$desc = $text{'search_all'};
	}
else {
	$folder = $folders[$in{'folder'}];
	$desc = &text('mail_for', $folder->{'name'});
	}
&ui_print_header($desc, $text{'search_title'}, "", undef, 0, 0, undef,
	&folder_link($in{'user'}, $ofolder));

if ($in{'simple'}) {
	if ($in{'search'} =~ /^(\S+):\s*(.*)$/) {
		# A specific field was entered
		local ($field, $what) = ($1, $2);
		@searchlist = ( [ $field, $what ] );
		@rv = &mailbox_search_mail(\@searchlist, 0, $folder);
		print "<p><b>",&text('search_results5', scalar(@rv),
			    "<tt>$field</tt>", "<tt>$what</tt>")," ..</b><p>\n";
		}
	else {
		# Just search by Subject and From in one folder
		($mode, $words) = &parse_boolean($in{'search'});
		if ($mode == 0) {
			# Can just do a single 'or' search
			@searchlist = map { ( [ 'subject', $_ ],
					      [ 'from', $_ ] ) } @$words;
			@rv = &mailbox_search_mail(\@searchlist, 0, $folder);
			}
		elsif ($mode == 1) {
			# Need to do two 'and' searches and combine
			@searchlist1 = map { ( [ 'subject', $_ ] ) } @$words;
			@rv1 = &mailbox_search_mail(\@searchlist1, 1, $folder);
			@searchlist2 = map { ( [ 'from', $_ ] ) } @$words;
			@rv2 = &mailbox_search_mail(\@searchlist2, 1, $folder);
			@rv = @rv1;
			%gotidx = map { $_->{'idx'}, 1 } @rv;
			foreach $mail (@rv2) {
				push(@rv, $mail) if (!$gotidx{$mail->{'idx'}});
				}
			}
		else {
			&error($text{'search_eboolean'});
			}
		print "<p><b>",&text('search_results2', scalar(@rv),
				     "<tt>$in{'search'}</tt>")," ..</b><p>\n";
		}
	foreach $mail (@rv) {
		$mail->{'folder'} = $folder;
		}
	}
else {
	# Complex search, perhaps over multiple folders!
	if ($in{'folder'} == -2) {
		@sfolders = grep { !$_->{'remote'} } @folders;
		$multi_folder = 1;
		}
	elsif ($in{'folder'} == -1) {
		@sfolders = @folders;
		$multi_folder = 1;
		}
	else {
		@sfolders = ( $folder );
		}
	foreach $sf (@sfolders) {
		local @frv = &mailbox_search_mail(\@fields, $in{'and'}, $sf);
		foreach $mail (@frv) {
			$mail->{'folder'} = $sf;
			}
		push(@rv, @frv);
		}
	print "<p><b>",&text('search_results4', scalar(@rv))," ..</b><p>\n";
	}
@rv = reverse(@rv);

$showto = $folder->{'sent'} || $folder->{'drafts'};
if (@rv) {
	print "<form action=delete_mail.cgi method=post>\n";
	print "<input type=hidden name=folder value='$in{'folder'}'>\n";
	print "<input type=hidden name=user value='$in{'user'}'>\n";
	if ($config{'top_buttons'}) {
		if (!$multi_folder) {
			&show_buttons(1, \@folders, $folder, \@rv, $in{'user'},
				      1);
			@links = ( &select_all_link("d", 0),
				   &select_invert_link("d", 0) );
			print &ui_links_row(\@links);
			}
		}

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
foreach $m (@rv) {
	local $idx = $m->{'idx'};
	local $mf = $m->{'folder'};
	local @cols;
	local $from = &simplify_from($m->{'header'}->{
					$showto ? 'to' : 'from'});
	$from = $text{'mail_unknown'} if ($from !~ /\S/);
	push(@cols, "<a href='view_mail.cgi?idx=$idx&user=$uuser&folder=$mf->{'index'}'>$from</a>");
	if ($config{'show_to'}) {
		push(@cols, &simplify_from(
	   		$m->{'header'}->{$showto ? 'from' : 'to'}));
		}
	push(@cols, &simplify_date($m->{'header'}->{'date'}));
	push(@cols, &nice_size($m->{'size'}, 1024));
	local $tbl;
	$tbl .= "<table border=0 cellpadding=0 cellspacing=0 width=100%>".
	      "<tr><td>".&simplify_subject($m->{'header'}->{'subject'}).
	      "</td> <td align=right>";
	if ($m->{'header'}->{'content-type'} =~ /multipart\/\S+/i) {
		$tbl .= "<img src=images/attach.gif>";
		}
	local $p = int($m->{'header'}->{'x-priority'});
	if ($p == 1) {
		$tbl .= "&nbsp;<img src=images/p1.gif>";
		}
	elsif ($p == 2) {
		$tbl .= "&nbsp;<img src=images/p2.gif>";
		}
	if (!$showto) {
		if ($read{$m->{'header'}->{'message-id'}} == 2) {
			$tbl .= "&nbsp;<img src=images/special.gif>";
			}
		elsif ($read{$m->{'header'}->{'message-id'}} == 1) {
			$tbl .= "&nbsp;<img src=images/read.gif>";
			}
		}
	$tbl .= "</td></tr></table>\n";
	push(@cols, $tbl);

	if (&editable_mail($m)) {
		print &ui_checked_columns_row(\@cols, \@tds, "d", $idx);
		}
	elsif ($multi_folder) {
		print &ui_columns_row([ $mf->{'name'}, @cols ], \@tds);
		}
	else {
		print &ui_columns_row([ "", @cols ], \@tds);
		}

	if ($config{'show_body'}) {
                # Show part of the body too
                &parse_mail($m);
		local $data = &mail_preview($m);
		if ($data) {
                        print "<tr $cb> <td colspan=",(scalar(@cols)+1),"><tt>",
				&html_escape($data),"</tt></td> </tr>\n";
			}
                }
	}
if (@rv) {
	print &ui_columns_end();
	if (!$multi_folder) {
		print &ui_links_row(\@links);
		&show_buttons(2, \@folders, $folder, \@rv, $in{'user'}, 1);
		}
	print "</form><p>\n";
	}
else {
	print "<b>$text{'search_none'}</b> <p>\n";
	}

&ui_print_footer($in{'simple'} ? ( ) : ( "search_form.cgi?folder=$in{'folder'}",
				$text{'sform_return'} ),
	"list_mail.cgi?user=$in{'user'}&folder=$in{'folder'}", $text{'mail_return'},
	"", $text{'index_return'});

