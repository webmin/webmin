#!/usr/local/bin/perl
# Show the LDAP server's data tree

require './ldap-server-lib.pl';
&ui_print_header(undef, $text{'browser_title'}, "", "browser");
&ReadParse();

# Connect to LDAP server, or die trying
$ldap = &connect_ldap_db();
if (!ref($ldap)) {
	print &text('browser_econn', $ldap),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# Work out the base (current navigation level)
if ($in{'goparent'}) {
	$base = $in{'parent'};
	}
elsif (!$in{'base'}) {
	$conf = &get_config();
	$base = &find_value("suffix", $conf);
	}
else {
	$base = $in{'base'};
	}

# Show current base (with option to change), and parent button
print &ui_form_start("edit_browser.cgi"),"\n";
print "<b>$text{'browser_base'}</b>\n";
print &ui_textbox("base", $base, 60)," ",&ui_submit($text{'browser_ok'}),"\n";
$parent = $base;
$parent =~ s/^[^,]+,\s*//;
if ($parent =~ /\S/) {
	print &ui_hidden("parent", $parent),"\n";
	print "&nbsp;&nbsp;\n";
	print &ui_submit($text{'browser_parent'}, "goparent"),"\n";
	}
print &ui_form_end();

# Show list of objects under the base, and its attributes
$rv = $ldap->search(base => $base,
		    filter => '(objectClass=*)',
		    scope => 'one');
if ($rv->code) {
	# Search failed
	print &text('browser_esearch', $rv->error),"<p>\n";
	}
else {
	# Table for layout
	print "<table width=100%><tr>\n";
	print "<td width=50%><b>$text{'browser_subs'}</b></td>\n";
	print "<td width=50%><b>$text{'browser_attrs'}</b></td>\n";
	print "</tr> <tr><td width=50% valign=top>\n";

	# Show sub-objects
	@tds = ( undef, "width=10%" );
	if ($in{'rename'}) {
		print &ui_form_start("rename_browser.cgi", "post");
		}
	else {
		print &ui_form_start("sdelete_browser.cgi", "post");
		@tds = ( "width=5", @tds );
		}
	print &ui_hidden("base", $base);
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'browser_sub'},
				  $text{'browser_acts'},
				], 100, 0, \@tds);
	foreach $dn (sort { lc($a->dn()) cmp lc($b->dn()) } $rv->all_entries) {
		print "<a href='edit_browser.cgi?base=".&urlize($dn->dn())."'>".
		      &html_escape($dn->dn())."</a><br>\n";
		}
	print &ui_columns_end();
	if (!$rv->all_entries) {
		print "<i>$text{'browser_none'}</i><br>\n";
		}
	
	print "</td><td width=50% valign=top>\n";
	print "<table>\n";

	# Show attributes
	$rv2 = $ldap->search(base => $base,
			     filter => '(objectClass=*)',
			     score => 'base');
	($bo) = $rv2->all_entries;
	@attrs = sort { lc($a) cmp lc($b) } $bo->attributes();
	if (@attrs) {
		# Show all attributes
		@tds = ( "valign=top", "valign=top", "width=5% valign=top" );
		if ($in{'edit'}) {
			print &ui_form_start("save_browser.cgi", "post");
			@links = ( );
			}
		else {
			print &ui_form_start("delete_browser.cgi", "post");
			@links = ( &select_all_link("d", 1),
				   &select_invert_link("d", 1),
				   "<a href='edit_browser.cgi?base=".
                                   &urlize($bo->dn())."&add=1'>".
				   "$text{'browser_add'}</a>" );
			@tds = ( "width=5", @tds );
			}
		print &ui_hidden("base", $bo->dn());
		print &ui_links_row(\@links);
		print &ui_columns_start([ $in{'edit'} ? ( ) : ( "" ),
					  $text{'browser_name'},
					  $text{'browser_value'},
					  $text{'browser_acts'} ],
					100, 0, \@tds);
		foreach $a (@attrs) {
			@v = $bo->get_value($a);
			@alinks = ( "<a href='edit_browser.cgi?base=".
				    &urlize($bo->dn()).
				    "&edit=$a'>$text{'browser_edit'}</a>" );
			@cols = ( $a, join(", ", @v),
				  &ui_links_row(\@alinks),
				);
			if ($in{'edit'} eq $a) {
				# Edit this one
				@alinks = ( "<a href='edit_browser.cgi?base=".
					    &urlize($bo->dn()).
					    "'>$text{'browser_cancel'}</a>" );
				print &ui_columns_row([
				  $a, &ui_textarea($a, join("\n", @v),
						   scalar(@v)+1, 40),
				  &ui_links_row(\@alinks),
				  ], \@tds);
				}
			elsif ($in{'edit'}) {
				# Display, no delete
				print &ui_columns_row(\@cols, \@tds);
				}
			else {
				# Edit or select for delete
				print &ui_checked_columns_row(
					\@cols, \@tds, "d", $a);
				}
			}
		print &ui_columns_end();
		print &ui_links_row(\@links);
		print &ui_form_end([ [ undef, $in{'edit'} ? $text{'save'} :
						$text{'browser_delete'} ] ]);
		}
	else {
		print "<tr> <td><i>$text{'browser_none'}</i></td> </tr>\n";
		}
	print "</table>\n";

	print "</td></tr></table><br>\n";
	}

$ldap->disconnect();
&ui_print_footer("", $text{'index_return'});

