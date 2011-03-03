#!/usr/local/bin/perl
# icp_access.cgi
# A form for editing or creating an ICP access restriction

require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
$conf = &get_config();

if (!defined($in{'index'})) {
	&ui_print_header(undef, $text{'aicp_header'}, "",
		undef, 0, 0, 0, &restart_button());
	}
else {
	&ui_print_header(undef, $text{'aicp_header1'}, "",
		undef, 0, 0, 0, &restart_button());
	@icp = @{$conf->[$in{'index'}]->{'values'}};
	}

print "<form action=icp_access_save.cgi>\n";
if (@icp) {
	print "<input type=hidden name=index value=$in{'index'}>\n";
	}
print "<table border>\n";
print "<tr $tb> <td><b>$text{'aicp_ir'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'aicp_a'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=action value=allow %s> $text{'aicp_a1'}\n",
	$icp[0] eq "allow" ? "checked" : "";
printf "<input type=radio name=action value=deny %s> $text{'aicp_d'}</td> </tr>\n",
	$icp[0] eq "allow" ? "" : "checked";

for($i=1; $i<@icp; $i++) { $match{$icp[$i]}++; }
@acls = grep { !$done{$_->{'values'}->[0]}++ } &find_config("acl", $conf);
unshift(@acls, { 'values' => [ 'all' ] }) if ($squid_version >= 3);
$r = @acls; $r = 10 if ($r > 10);

print "<tr> <td valign=top><b>$text{'aicp_ma'}</b></td>\n";
print "<td><select name=yes multiple rows=$r width=100>\n";
foreach $a (@acls) {
	printf "<option %s>%s\n",
		$match{$a->{'values'}->[0]} ? "selected" : "",
		$a->{'values'}->[0];
	}
print "</select></td>\n";

print "<td valign=top><b>$text{'aicp_dma'}</b></td>\n";
print "<td><select name=no multiple rows=$r width=100>\n";
foreach $a (@acls) {
	printf "<option %s>%s\n",
		$match{"!$a->{'values'}->[0]"} ? "selected" : "",
		$a->{'values'}->[0];
	}
print "</select></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'buttsave'}'>\n";
if (@icp) {
	print "<input type=submit value='$text{'buttdel'}' name=delete>\n";
	}
print "</form>\n";

&ui_print_footer("edit_acl.cgi?mode=icp", $text{'aicp_return'},
		 "", $text{'index_return'});

