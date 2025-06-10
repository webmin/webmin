#!/usr/local/bin/perl
# Show the LDAP server's data tree

require './ldap-server-lib.pl';
&ui_print_header(undef, $text{'browser_title'}, "", "browser");
$access{'browser'} || &error($text{'browser_ecannot'});
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
	$base = &get_ldap_base();
	}
else {
	$base = $in{'base'};
	}

# Show current base (with option to change), and parent button
$formno = 0;
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
$formno++;

# Show list of objects under the base, and its attributes
if ($in{'search'}) {
	$filter = '(|'.join('', map { '('.$_.'=*'.$in{'search'}.'*)' }
				    @search_attrs).')';
	}
else {
	$filter = '(objectClass=*)';
	}
$rv = $ldap->search(base => $base,
		    filter => $filter,
		    scope => 'one',
		    sizelimit => int($config{'browse_max'}),
		   );
@subs = sort { lc($a->dn()) cmp lc($b->dn()) } $rv->all_entries;
if ($rv->code && !@subs) {
	# Search failed
	print &text('browser_esearch', $rv->error),"<p>\n";
	}
else {
	# Start tabs for layout
	$in{'mode'} ||= @subs || $in{'search'} ? "subs" : "attrs";
	@tabs = ( [ 'subs', $text{'browser_subs'} ],
		  [ 'attrs', $text{'browser_attrs'} ] );
	print &ui_tabs_start(\@tabs, "browser", $in{'mode'}, 1);

	# Show sub-objects, if any
	print &ui_tabs_start_tab("browser", "subs");
	@crlinks = ( "<a href='add_form.cgi?base=".
		     &urlize($base)."'>$text{'browser_sadd'}</a>" );
	if ($rv->code || ($in{'search'} && !@subs)) {
		# Too many to show
		if (@subs && $in{'search'}) {
			# Too many results
			print &text('browser_toomany2', "<i>$in{'search'}</i>",
				    $config{'browse_max'}),"<p>\n";
			}
		elsif (@subs) {
			# No search, many sub-objects
			print &text('browser_toomany',
				    $config{'browse_max'}),"<p>\n";
			}
		else {
			# No matches
			print &text('browser_nomatch',
				    "<i>$in{'search'}</i>"),"<p>\n";
			}
		&show_search_form($text{'browser_search'});
		print &ui_links_row(\@crlinks);
		}
	elsif (@subs) {
		# Search result, so show form
		if ($in{'search'}) {
			&show_search_form($text{'browser_search2'});
			}

		# Can show some
		@tds = ( "width=90%", "width=10%" );
		if ($in{'rename'}) {
			# Rename form
			print &ui_form_start("rename_browser.cgi", "post");
			print &ui_hidden("old", $in{'rename'});
			}
		else {
			# Delete sub-objects form
			print &ui_form_start("sdelete_browser.cgi", "post");
			@tds = ( "width=5", @tds );
			@links = ( &select_all_link("d", $formno),
				   &select_invert_link("d", $formno),
				   @crlinks,
				 );
			}
		print &ui_hidden("base", $base);
		print &ui_links_row(\@links);
		print &ui_columns_start([ $in{'rename'} ? ( ) : ( "" ),
					  $text{'browser_sub'},
					  $text{'browser_acts'},
					], 100, 0, \@tds);
		foreach $dn (@subs) {
			$link = "<a href='edit_browser.cgi?base=".
				&urlize($dn->dn())."'>".
				&html_escape($dn->dn())."</a>";
			@alinks = ( "<a href='edit_browser.cgi?base=".
				    &urlize($base)."&mode=subs".
				    "&rename=".&urlize($dn->dn()).
				    "'>$text{'browser_rename'}</a>" );
			if ($in{'rename'} eq $dn->dn()) {
				# Renaming this one
				@alinks = ( "<a href='edit_browser.cgi?base=".
					    &urlize($base)."&mode=subs".
					    "'>$text{'browser_cancel'}</a>" );
				print &ui_columns_row([
					&ui_textbox("rename", $dn->dn(), 70),
					&ui_links_row(\@alinks) ], \@tds);
				}
			elsif ($in{'rename'}) {
				# Display, no delete
				print &ui_columns_row([
					$link,&ui_links_row(\@alinks) ], \@tds);
				}
			else {
				# Rename or select for delete
				print &ui_checked_columns_row([
					$link, &ui_links_row(\@alinks) ],
					\@tds, "d", $dn->dn());
				}
			}
		print &ui_columns_end();
		print &ui_links_row(\@links);
		print &ui_form_end([ [ undef,
			$in{'rename'} ? $text{'browser_rsave'}
				      : $text{'browser_sdelete'} ] ]);
		$formno++;
		}
	else {
		# Nothing to show
		print "<i>$text{'browser_subnone'}</i><p>\n";
		print &ui_links_row(\@crlinks);
		}
	print &ui_tabs_end_tab();
	
	# Show attributes
	print &ui_tabs_start_tab("browser", "attrs");
	$rv2 = $ldap->search(base => $base,
			     filter => '(objectClass=*)',
			     scope => 'base');
	($bo) = $rv2->all_entries;
	@attrs = sort { lc($a) cmp lc($b) } $bo->attributes();
	if (@attrs) {
		# Show all attributes
		@tds = ( "valign=top width=45%", "valign=top width=45%",
			 "width=5% valign=top" );
		if ($in{'edit'}) {
			# Editing form
			print &ui_form_start("save_browser.cgi", "post");
			print &ui_hidden("edit", $in{'edit'});
			}
		elsif ($in{'add'}) {
			# Add form
			print &ui_form_start("add_browser.cgi", "post");
			}
		else {
			# Deleting form
			print &ui_form_start("delete_browser.cgi", "post");
			@links = ( &select_all_link("d", $formno),
				   &select_invert_link("d", $formno),
			           "<a href='edit_browser.cgi?base=".
				   &urlize($bo->dn())."&add=1&mode=attrs'>".
				   "$text{'browser_add'}</a>",
			           "<a href='add_form.cgi?base=".
				   &urlize($base)."&clone=1'>".
				   "$text{'browser_clone'}</a>" );
			@tds = ( "width=5", @tds );
			}
		print &ui_hidden("base", $bo->dn());
		print &ui_hidden("mode", "attrs");
		print &ui_links_row(\@links);
		print &ui_columns_start([
			$in{'edit'} || $in{'add'} ? ( ) : ( "" ),
			$text{'browser_name'},
			$text{'browser_value'},
			$text{'browser_acts'} ], 100, 0, \@tds);
		foreach $a (@attrs) {
			@v = $bo->get_value($a);
			@alinks = ( "<a href='edit_browser.cgi?base=".
				    &urlize($bo->dn())."&mode=attrs".
				    "&edit=$a'>$text{'browser_edit'}</a>" );
			@cols = ( $a, join(", ", @v),
				  &ui_links_row(\@alinks),
				);
			if ($in{'edit'} eq $a) {
				# Edit this one
				@alinks = ( "<a href='edit_browser.cgi?base=".
					    &urlize($bo->dn())."&mode=attrs".
					    "'>$text{'browser_cancel'}</a>" );
				print &ui_columns_row([
				  $a, &ui_textarea("value", join("\n", @v),
						   scalar(@v)+1, 60),
				  &ui_links_row(\@alinks),
				  ], \@tds);
				}
			elsif ($in{'edit'} || $in{'add'}) {
				# Display, no delete
				print &ui_columns_row(\@cols, \@tds);
				}
			else {
				# Edit or select for delete
				print &ui_checked_columns_row(
					\@cols, \@tds, "d", $a);
				}
			}
		if ($in{'add'}) {
			# Show row to add an attribute
			@alinks = ( "<a href='edit_browser.cgi?base=".
				    &urlize($bo->dn())."&mode=attrs".
				    "'>$text{'browser_cancel'}</a>" );
			print &ui_columns_row([
				&ui_textbox("add", undef, 20),
				&ui_textbox("value", undef, 60),
				&ui_links_row(\@alinks),
				], \@tds);
			}
		print &ui_columns_end();
		print &ui_links_row(\@links);
		print &ui_form_end([ [ undef, $in{'edit'} ? $text{'save'} :
					      $in{'add'} ? $text{'create'} :
						$text{'browser_delete'} ] ]);
		$formno++;
		}
	else {
		print "<i>$text{'browser_attrnone'}</i><p>\n";
		print &ui_links_row(\@links);
		}
	print &ui_tabs_end_tab();

	print &ui_tabs_end(1);
	}

$ldap->disconnect();
&ui_print_footer("", $text{'index_return'});

sub show_search_form
{
local ($msg) = @_;
print &ui_form_start("edit_browser.cgi");
print &ui_hidden("base", $base);
print "<b>$msg</b>\n";
print &ui_textbox("search", $in{'search'}, 40),"\n";
print &ui_submit($text{'browser_sok'}),"<p>\n";
print &ui_form_end();
$formno++;
}

