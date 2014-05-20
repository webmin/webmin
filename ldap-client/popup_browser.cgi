#!/usr/local/bin/perl
# Show the LDAP tree in a popup browser window, for selecting something

require './ldap-client-lib.pl';
&popup_header($text{'browser_title'});
&ReadParse();

# Connect to LDAP server, or die trying
$ldap = &ldap_connect(1);
if (!ref($ldap)) {
	print &text('browser_econn', $ldap),"<p>\n";
	&popup_footer();
	exit;
	}

# Work out the base (current navigation level)
if ($in{'parent'}) {
	$base = $in{'parent'};
	}
elsif (!$in{'base'}) {
	$conf = &get_config();
	$base = &find_value("base", $conf);
	}
else {
	$base = $in{'base'};
	}

# Javascript to update original field
print "<script>\n";
print "function ldap_select(f)\n";
print "{\n";
print "top.opener.ifield.value = f;\n";
print "top.close();\n";
print "window.close();\n";
print "return false;\n";
print "}\n";
print "</script>\n";

# Find the actual base object
$rv2 = $ldap->search(base => $base,
		     filter => '(objectClass=*)',
		     score => 'base');
if (!$rv2->code) {
	($bo) = $rv2->all_entries;
	($top) = grep { $_ eq "top" } $bo->get_value("objectClass");
	}

# Show current base (with option to change), and parent button
print &ui_form_start("popup_browser.cgi"),"\n";
print &ui_hidden("node", $in{'node'}),"\n";
print "<b>$text{'browser_base'}</b>\n";
print &ui_textbox("base", $base, 40)," ",&ui_submit($text{'browser_ok'}),"\n";
$parent = $base;
$parent =~ s/^[^,]+,\s*//;

# Show the OK button only if the object type is appropriatye
if ($in{'node'} == 0 && $top ||
    $in{'node'} == 1 && !$top ||
    $in{'node'} == 2) {
	print "<input type=button onClick='return ldap_select(\"".
	      &quote_escape($base, '"'),"\")' ",
	      "value='$text{'browser_sel'}'>\n";
	}
print &ui_form_end();

# Find sub-objects
$rv = $ldap->search(base => $base,
		    filter => '(objectClass=*)',
		    scope => 'one');
if ($rv->code) {
	# Search failed
	print &text('browser_esearch', $rv->error),"<p>\n";
	&popup_footer();
	exit;
	}

print "<table width=100%>\n";
if ($parent =~ /\S/) {
	print "<tr> <td><i><a href='popup_browser.cgi?node=".
	      &urlize($in{'node'})."&base=",
	      &urlize($parent),"'><img src=images/up.gif border=0> ",
	      &html_escape($parent),"</a></td> </tr>\n";
	}
if ($rv->all_entries) {
	# If this object has sub-objects, show them
	foreach $dn (sort { lc($a->dn()) cmp lc($b->dn()) } $rv->all_entries) {
		print "<tr> <td><a href='popup_browser.cgi?node=".
		      &urlize($in{'node'}),"&",
		      "base=".&urlize($dn->dn()).
		      "'><img src=images/open.gif border=0>",
		      " ",&html_escape($dn->dn()),"</a></td> </tr>\n";
		}
	}
else {
	# Show attributes
	foreach $a (sort { lc($a) cmp lc($b) } $bo->attributes()) {
		@v = $bo->get_value($a);
		print "<tr> <td>$a</td> <td>:</td> <td>",
		      join(" , ", @v),"</td> </tr>\n";
		}
	}
print "</table>\n";

&popup_footer();
