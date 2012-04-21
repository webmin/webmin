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

# Show list of messages, with form
if (@rv) {
	print &ui_form_start("delete_mail.cgi", "post");
	print &ui_hidden("user", $in{'user'});
	print &ui_hidden("dom", $in{'dom'});
	print &ui_hidden("folder", $in{'folder'});
	if ($config{'top_buttons'} && !$multi_folder) {
		&show_buttons(1, \@folders, $folder, \@rv, $in{'user'}, 1);
		}
	&show_mail_table(\@rv, $multi_folder ? undef : $ofolder, 0);
	if (!$multi_folder) {
		&show_buttons(2, \@folders, $folder, \@rv, $in{'user'}, 1);
		}
	print &ui_form_end();
	}
else {
	print "<b>$text{'search_none'}</b> <p>\n";
	}

&ui_print_footer($in{'simple'} ? ( ) : ( "search_form.cgi?folder=$in{'folder'}",
				$text{'sform_return'} ),
	"list_mail.cgi?user=$in{'user'}&folder=$in{'folder'}&dom=$in{'dom'}",
	  $text{'mail_return'},
	&user_list_link(), $text{'index_return'});

