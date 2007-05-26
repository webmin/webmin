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
	   "<a href='edit_dir.cgi?new=1'>$text{'index_add'}</a>" );

@dirs = &list_directories();
@dirs = grep { &can_access_dir($_->[0]) } @dirs;
if (@dirs) {
	print &ui_form_start("delete.cgi", "post");
	@tds = ( "width=5", "width=30% valign=top", "width=70% valign=top" );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "", $text{'index_dir'},
				  $text{'index_usersgroups'} ], 100, 0, \@tds);
	foreach $d (@dirs) {
		local @cols;
		push(@cols, "<a href='edit_dir.cgi?dir=".
			    &urlize($d->[0])."'>$d->[0]</a>");

		# Show the users
		$utable = "<table width=100%>\n";
		$users = $d->[2] == 3 ? &list_digest_users($d->[1])
				      : &list_users($d->[1]);
		if ($userconfig{'sort'} == 1 || $config{'sort'} == 1) {
			$users = [ sort { $a->{'user'} cmp $b->{'user'} }
					@$users ];
			}
		for($i=0; $i<@$users; $i++) {
			$u = $users->[$i];
			$link = "<a href='edit_user.cgi?idx=$u->{'index'}&dir=".
				&urlize($d->[0])."'>$u->{'user'}</a>";
			$utable .= "<tr>\n" if ($i%4 == 0);
			if ($u->{'enabled'}) {
				$utable .= "<td width=25%>$link</td>\n";
				}
			else {
				$utable .= "<td width=25%><i>$link</i></td>\n";
				}
			$utable .= "</tr>\n" if ($i%4 == 3);
			}
		if ($i%4) {
			while($i++%4) { $utable .= "<td width=25%></td>\n"; }
			$utable .= "</tr>\n";
			}
		if (!@$users) {
			$utable .= "<tr> <td colspan=4><i>".
				   "$text{'index_nousers'}</i></td> </tr>\n";
			}
		$utable .= "</table>\n";

		# Show the groups
		if ($d->[4]) {
			$utable .= "<table width=100%>\n";
			$groups = &list_groups($d->[4]);
			if ($userconfig{'sort'} == 1 || $config{'sort'} == 1) {
				$groups = [ sort { $a->{'group'} cmp $b->{'group'} }
						@$groups ];
				}
			for($i=0; $i<@$groups; $i++) {
				$u = $groups->[$i];
				$link= "<a href='edit_group.cgi?idx=$u->{'index'}&dir=".
				       &urlize($d->[0])."'>$u->{'group'} (".
				       scalar(@{$u->{'members'}}).")</a>";
				$utable .= "<tr>\n" if ($i%4 == 0);
				if ($u->{'enabled'}) {
					$utable .= "<td width=25%>$link</td>\n";
					}
				else {
					$utable .= "<td width=25%><i>$link</i></td>\n";
					}
				$utable .= "</tr>\n" if ($i%4 == 3);
				}
			if ($i%4) {
				while($i++%4) { $utable .= "<td width=25%></td>\n"; }
				$utable .= "</tr>\n";
				}
			if (!@$groups) {
				$utable .= "<tr> <td colspan=4><i>$text{'index_nogroups'}</i></td> </tr>\n";
				}
			$utable .= "</table>\n";
			}

		# User / group adder links
		$utable .= "<a href='edit_user.cgi?new=1&dir=".&urlize($d->[0]).
			   "'>$text{'index_uadd'}</a>\n";
		if ($d->[4]) {
			$utable .= "&nbsp;&nbsp;";
			$utable .= "<a href='edit_group.cgi?new=1&dir=".
				 &urlize($d->[0])."'>$text{'index_gadd'}</a>\n";
			}
		push(@cols, $utable);
		print &ui_checked_columns_row(\@cols, \@tds, "d", $d->[0]);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

# Form to find existing .htaccess files
print "<hr>\n";
print "<form action=search.cgi>\n";
print "<input type=submit value='$text{'index_search'}'>\n";
printf "<input name=search size=30 value='%s'> %s<br>\n",
	$accessdirs[0] eq "/" ? "" : $accessdirs[0],
	&file_chooser_button("search", 1);
print "</form>\n";

&ui_print_footer("/", $text{'index'});
