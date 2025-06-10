#!/usr/local/bin/perl
# index.cgi
# Display a list of protected directories and their users. The user can
# add more directories, and specify the encryption mode for each.

require './htaccess-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

# Check needed Perl modules
if ($config{'md5'}) {
	$missing = &check_md5();
	if ($missing) {
		print &text('index_emd5', "<tt>$missing</tt>"),"\n";
		}
	}
if ($config{'sha1'} && !$missing) {
	$missing = &check_sha1();
	if ($missing) {
		print &text('index_sha1', "<tt>$missing</tt>"),"\n";
		}
	}
if ($missing) {
	if (!$module_info{'usermin'}) {
		print &text('index_cpan', "../cpan/download.cgi?source=3&cpan=$missing&mode=2&return=/$module_name/&returndesc=".&urlize($text{'index_return'}));
		}
	print "<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check for htdigest command, if we need it
if ($config{'digest'} && !$htdigest_command) {
	eval "use Digest::MD5";
	if ($@) {
		print &text('index_digest2', "<tt>htdigest</tt>",
					     "<tt>Digest::MD5</tt>"),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	}

@accessdirs || &error($text{'index_eaccess'});

@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   &ui_link("edit_dir.cgi?new=1",$text{'index_add'}) );

@dirs = &list_directories();
@dirs = grep { &can_access_dir($_->[0]) } @dirs;
@gtds = ( "width=25%", "width=25%", "width=25%", "width=25%" );
if (@dirs) {
	@tds = ( "width=30% valign=top", "width=70% valign=top" );
	if ($can_create) {
		print &ui_form_start("delete.cgi", "post");
		@tds = ( "width=5", @tds );
		print &ui_links_row(\@links);
		}
	print &ui_columns_start([ $can_create ? ( "" ) : ( ),
				  $text{'index_dir'},
				  $text{'index_usersgroups'} ], 100, 0, \@tds);
	&switch_user();
	foreach $d (@dirs) {
		local @cols;
		if ($can_create) {
			push(@cols, "<a href='edit_dir.cgi?dir=".
				    &urlize($d->[0])."'>".
				    &html_escape($d->[0])."</a>");
			}
		else {
			push(@cols, &html_escape($d->[0]));
			}

		# Show the users
		$users = $d->[2] == 3 ? &list_digest_users($d->[1])
				      : &list_users($d->[1]);
		if ($userconfig{'sort'} == 1 || $config{'sort'} == 1) {
			$users = [ sort { $a->{'user'} cmp $b->{'user'} }
					@$users ];
			}
		@grid = ( );
		for($i=0; $i<@$users; $i++) {
			$u = $users->[$i];
			$link = "<a href='edit_user.cgi?idx=$u->{'index'}&dir=".
				&urlize($d->[0])."'>".
				&html_escape($u->{'user'})."</a>";
			if ($u->{'enabled'}) {
				push(@grid, $link);
				}
			else {
				push(@grid, "<i>$link</i>");
				}
			}
		if (@grid) {
			$utable = &ui_grid_table(\@grid, 4, 100, \@gtds);
			}
		else {
			$utable = "<i>$text{'index_nousers'}</i><br>\n";
			}

		# Show the groups
		if ($d->[4]) {
			@grid = ( );
			$groups = &list_groups($d->[4]);
			if ($userconfig{'sort'} == 1 || $config{'sort'} == 1) {
				$groups = [ sort { $a->{'group'} cmp $b->{'group'} }
						@$groups ];
				}
			for($i=0; $i<@$groups; $i++) {
				$u = $groups->[$i];
				$link= "<a href='edit_group.cgi?idx=$u->{'index'}&dir=".
				       &urlize($d->[0])."'>".
				       &html_escape($u->{'group'})." (".
				       scalar(@{$u->{'members'}}).")</a>";
				if ($u->{'enabled'}) {
					push(@grid, $link);
					}
				else {
					push(@grid, "<i>$link</i>");
					}
				}
			if (@grid) {
				$utable .= &ui_grid_table(\@grid, 4,100,\@gtds);
				}
			else {
				$utable .= "<i>$text{'index_nogroups'}</i><br>\n";
				}
			}

		# User / group adder links
		@ulinks = ( );
		push(@ulinks, "<a href='edit_user.cgi?new=1&dir=".
			      &urlize($d->[0])."'>$text{'index_uadd'}</a>");
		if ($d->[4]) {
			push(@ulinks, "<a href='edit_group.cgi?new=1&dir=".
			     &urlize($d->[0])."'>$text{'index_gadd'}</a>");
			}
		$utable .= &ui_links_row(\@ulinks);
		push(@cols, $utable);
		if ($can_create) {
			print &ui_checked_columns_row(\@cols, \@tds,
						      "d", $d->[0]);
			}
		else {
			print &ui_columns_row(\@cols, \@tds);
			}
		}
	&switch_back();
	print &ui_columns_end();
	if ($can_create) {
		print &ui_links_row(\@links);
		print &ui_form_end([ [ "delete", $text{'index_delete'} ],
				     [ "remove", $text{'index_remove'} ] ]);
		}
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

# Form to find existing .htaccess files
if ($can_create) {
	print &ui_hr();
	print &ui_form_start("search.cgi");
	print &ui_submit($text{'index_search'}),"\n";
	print &ui_textbox("search", $accessdirs[0] eq "/" ? "" : $accessdirs[0],
			  40)." ".&file_chooser_button("search", 1)."<br>\n";
	print &ui_form_end();
	}

&ui_print_footer("/", $text{'index'});
