#!/usr/local/bin/perl
# Show a list of all authorizations

require './rbac-lib.pl';
&ReadParse();

&header("Select Authorization");
print <<EOF;
<script>
function sel(m)
{
if (window.opener.ifield.value != "") {
	window.opener.ifield.value += "\\n";
	}
window.opener.ifield.value += m;
window.close();
return false;
}
</script>
EOF

# Show Solaris authorizations
$auths = &list_auth_attrs();
print "<table width=100% cellpadding=1 cellspacing=1>\n";
print "<tr> <td><b>$text{'authc_name'}</b></td> ",
      "<td><b>$text{'authc_desc'}</b></td> </tr>\n";
foreach $a (sort { $a->{'name'} cmp $b->{'name'} } @$auths) {
	print "<tr>\n";
	if ($a->{'name'} =~ /\.$/) {
		print "<td><a href='' onClick='sel(\"$a->{'name'}*\")'>",
		      "$a->{'name'}*</td>\n";
		}
	else {
		print "<td><a href='' onClick='sel(\"$a->{'name'}\")'>",
		      "$a->{'name'}</td>\n";
		}
	print "<td>",$a->{'short'} || $a->{'desc'},"</td>\n";
	print "</tr>\n";
	}

# Add Webmin authorizations
print "<tr> <td colspan=2><hr></td> </tr>\n";
foreach $m (sort { $a->{'dir'} cmp $b->{'dir'} } &get_all_module_infos()) {
	next if (!&check_os_support($m));
	print "<tr>\n";
	print "<td><a href='' onClick='sel(\"webmin.$m->{'dir'}.admin\")'>",
	      "webmin.$m->{'dir'}.admin</td>\n";
	print "<td>$m->{'desc'}</td>\n";
	print "</tr>\n";
	}

print "</table>\n";

