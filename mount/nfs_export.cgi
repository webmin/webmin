#!/usr/local/bin/perl
# nfs_export.cgi
# Display a list of NFS exports on some host for the user to choose from

require './mount-lib.pl';
&ReadParse();
$access{'browse'} || &error($text{'browse_ecannot'});
# A leading dash would be read as a showmount option
$in{'server'} =~ /^-/ &&
	&error(&text('nfs_failed', &html_escape($in{'server'}), ""));
&popup_header(&text('nfs_choose', &html_escape($in{'server'})));
print <<EOF;
<script>
function choose(f)
{
top.opener.ifield.value = f;
window.close();
}
</script>
EOF

if ($error = &exports_list($in{'server'}, \@dirs, \@clients)) {
	print "<b>",&text('nfs_failed', &html_escape($in{'server'}),
			  "<p><tt>".&html_escape($error)."</tt><p>"),"</b>\n";
	exit;
	}
print "<b>$text{'nfs_seldir'}</b>\n";
if (defined(&nfs_max_version) && &nfs_max_version($in{'server'}) >= 4) {
	print "<br>$text{'nfs_seldirv4'}\n";
	}

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'nfs_dir'}</b></td> ",
      "<td><b>$text{'nfs_clients'}</b></td> </tr>\n";
for($i=0; $i<@dirs; $i++) {
	print "<tr $cb>\n";
	# Remote names are untrusted, so escape them for HTML and JavaScript
	print "<td>".&ui_link("#", &html_escape($dirs[$i]), undef,
		"onClick='choose(\"".&quote_javascript($dirs[$i]).
		"\"); return false;'");
	print "</td>\n";
	printf "<td>%s</td>\n",
		length($clients[$i]) > 45 ?
			&html_escape(substr($clients[$i], 0, 45))." ..." :
			&html_escape($clients[$i]);
	print "</tr>\n";
	}
print "</table>\n";
&popup_footer();
