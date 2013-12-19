#!/usr/local/bin/perl
# rhn.cgi
# Display a list of packages available for download from RHN

require './software-lib.pl';
$bgcolor = defined($gconfig{'cs_page'}) ? $gconfig{'cs_page'} : "ffffff";
$link = defined($gconfig{'cs_link'}) ? $gconfig{'cs_link'} : "0000ee";
$text = defined($gconfig{'cs_text'}) ? $gconfig{'cs_text'} : "000000";
&PrintHeader();
print <<EOF;
<html>
<head><title>$text{'rhn_title'}</title>
<script>
function sel(p)
{
window.opener.ifield.value = p;
window.close();
return false;
}
</script>
</head><body bgcolor=#$bgcolor link=#$link vlink=#$link text=#$text>
EOF

$out = `up2date -l 2>&1`;
if ($out =~ /Error Message:/i) {
	print "<pre>$out</pre>\n";
	}
else {
	print "<table width=100%>\n";
	foreach (split(/\n/, $out)) {
		if ($dashes && /^(\S+)\s+(\S+)\s+(\S+)/) {
			if (!$count++) {
				print "<tr> <td><b>$text{'rhn_pack'}</b></td> ",
				      "<td align=right><b>",
				      "$text{'rhn_version'}</b></td> </tr>\n";
				}
			print "<tr>\n";
			print "<td>";
            print &ui_link("#", $1, undef, "onClick='sel(\"$1\");'");
            print "</td>\n";
			print "<td align=right>$2 - $3</td>\n";
			print "</tr>\n";
			}
		elsif (/^----/) {
			last if ($dashes);
			$dashes++;
			}
		}
	print "</table>\n";
	if (!$count) {
		print "<b>$text{'rhn_nonefound'}</b><p>\n";
		}
	}
print "</body></html>\n";

