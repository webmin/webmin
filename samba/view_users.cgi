#!/usr/local/bin/perl
# view_users.cgi
# Display users connected to a share

require './samba-lib.pl';
&ReadParse();

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
if ($in{share}) { # this may be cracked very easy, don't know how to do better :    # per-share acls ...
    # per-share acls ...
	&error("$text{'eacl_np'} $text{'eacl_pconn'}") 
		unless &can('rv',\%access, $in{share});
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_pconn_all'}") 
		unless $access{'view_all_con'};
	} 
&ui_print_header(undef, $text{'viewu_index'}, "");

if (!&has_command($config{samba_status_program})) {
	print &text('viewu_ecmd', $config{'samba_status_program'}, "@{[&get_webprefix()]}/config.cgi?$module_name");
	print "<p>\n";
	&ui_print_footer("", $text{'index_sharelist'});
	exit;
	}

if ($in{share}) {
	print &ui_subheading(&text('viewu_list',"<tt>$in{share}</tt>"));
	@cons = &list_connections($in{'share'});
	}
else {
	@cons = &list_connections();
	}
@locks = &list_locks();

@rightlinks = ( &ui_link("view_users.cgi?$in",$text{'viewu_refresh'}) );
if (@cons) {
	print &ui_form_start("kill_users.cgi");
	print &ui_hidden("share", $in{'share'});
	@links = ( &select_all_link("d"),
		   &select_invert_link("d") );
	print &ui_grid_table([ &ui_links_row(\@links),
			       &ui_links_row(\@rightlinks) ], 2, 100,
			     [ undef, "align=right" ]);

	# Show table header
	@tds = ( "width=5" );
	print &ui_columns_start([
		"",
		$text{'viewu_pid'},
		$in{'share'} ? ( ) : ( $text{'viewu_share'} ),
		$text{'viewu_user'},
		$text{'viewu_group'},
		$text{'viewu_from'},
		$text{'viewu_time'},
		$text{'viewu_locks'} ], 100, 0, \@tds);

	# Show each connected user
	foreach $c (@cons) {
		local @cols;
		push(@cols, "<a href=\"kill_user.cgi?share=$in{'share'}&pid=$c->[3]\">".&html_escape($c->[3])."</a>");
		if (!$in{'share'}) {
			push(@cols, &html_escape($c->[0]));
			}
		$p = undef;
		&get_share($c->[0]);
		$p = &getval("path");
		push(@cols, &html_escape($c->[1]));
		push(@cols, &html_escape($c->[2]));
		push(@cols, &html_escape($c->[4]));
		push(@cols, &html_escape($c->[5]));
		local $ulocks;
		@ulocks = grep { $_->[0] == $c->[3] } @locks;
		if ($p) {
			# Limit to files under share
			@ulocks = grep { $_->[4] =~ /^\Q$p\E\// } @ulocks;
			}
		foreach $l (@ulocks) {
			$ulocks .= &html_escape($l->[4])." (".
			      	   &html_escape($l->[1]).")<br>\n";
			}
		$ulocks ||= $text{'viewu_none'};
		push(@cols, $ulocks);
		print &ui_checked_columns_row(\@cols, \@tds, "d", $c->[3]);
		}
	print &ui_columns_end();
	print &ui_grid_table([ &ui_links_row(\@links),
			       &ui_links_row(\@rightlinks) ], 2, 100,
			     [ undef, "align=right" ]);
	print &ui_form_end([ [ "kill", $text{'viewu_kill'} ] ]);

	print $text{'viewu_msg1'},"<p>\n";
	}
else {
	print "<b>$text{'viewu_msg2'}</b><p>\n";
	print &ui_links_row(\@rightlinks);
	}
print "<p>\n";

if ($in{share}) {
	&ui_print_footer($in{printer} ? "edit_pshare.cgi?share=$in{share}"
			     : "edit_fshare.cgi?share=$in{share}",
		$text{'index_shareconf'},
		"", $text{'index_sharelist'});
	}
else { &ui_print_footer("", $text{'index_sharelist'}); }

