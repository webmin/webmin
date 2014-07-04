#!/usr/local/bin/perl
# Show the LDAP server's data tree

require './ldap-client-lib.pl';
&ui_print_header(undef, $text{'browser_title'}, "", "browser");
&ReadParse();

# Connect to LDAP server, or die trying
$ldap = &ldap_connect(1);
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
	$base = &find_value("base", $conf);
	}
else {
	$base = $in{'base'};
	}

# Show current base (with option to change), and parent button
print &ui_form_start("browser.cgi"),"\n";
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
	print "<table width=100%><tr>\n";
	print "<td width=50%><b>$text{'browser_subs'}</b></td>\n";
	print "<td width=50%><b>$text{'browser_attrs'}</b></td>\n";
	print "</tr> <tr><td width=50% valign=top>\n";

	# Show sub-objects
	foreach $dn (sort { lc($a->dn()) cmp lc($b->dn()) } $rv->all_entries) {
		print &ui_link("browser.cgi?base=".&urlize($dn->dn()),
				&html_escape($dn->dn())),"<br>\n";
		}
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
	foreach $a (sort { lc($a) cmp lc($b) } $bo->attributes()) {
		@v = $bo->get_value($a);
		print "<tr> <td>$a</td> <td>:</td> <td>",
		      join(" , ", @v),"</td> </tr>\n";
		}
	if (!$bo->attributes()) {
		print "<tr> <td><i>$text{'browser_none'}</i></td> </tr>\n";
		}
	print "</table>\n";

	print "</td></tr></table>\n";
	}

$ldap->disconnect();
&ui_print_footer("", $text{'index_return'});

