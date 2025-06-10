
require 'lpadmin-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the lpadmin module
sub acl_security_form
{
print "<tr> <td valign=top><b>$text{'acl_printers'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input name=printers_def type=radio value=1 %s> %s\n",
	$_[0]->{'printers'} eq '*' ? 'checked' : '', $text{'acl_pall'};
printf "<input name=printers_def type=radio value=0 %s> %s<br>\n",
	$_[0]->{'printers'} eq '*' ? '' : 'checked', $text{'acl_psel'};
print "<select name=printers multiple size=4 width=15>\n";
local @plist = &list_printers();
local ($p, %pcan);
map { $pcan{$_}++ } split(/\s+/, $_[0]->{'printers'});
foreach $p (@plist) {
	local $prn = &get_printer($p);
	printf "<option value=%s %s>%s (%s)</option>\n",
		$p, $pcan{$p} ? 'selected' : '',
		$prn->{'desc'}, $p;
	}
print "</select></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'acl_cancel'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=cancel value=0 %s> $text{'no'}\n",
	$_[0]->{'cancel'} == 0 ? "checked" : "";
printf "<input type=radio name=cancel value=1 %s> $text{'yes'}\n",
	$_[0]->{'cancel'} == 1 ? "checked" : "";
printf "<input type=radio name=cancel value=2 %s> $text{'acl_listed'}<br>\n",
	$_[0]->{'cancel'} == 2 ? "checked" : "";
print "<select name=jobs multiple size=4 width=15>\n";
map { $jcan{$_}++ } split(/\s+/, $_[0]->{'jobs'});
foreach $p (@plist) {
	local $prn = &get_printer($p);
	printf "<option value=%s %s>%s (%s)</option>\n",
		$p, $jcan{$p} ? 'selected' : '',
		$prn->{'desc'}, $p;
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'acl_user'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=user_def value=1 %s> %s\n",
	$_[0]->{'user'} eq '*' ? 'checked' : '', $text{'acl_user_all'};
printf "<input type=radio name=user_def value=2 %s> %s\n",
	$_[0]->{'user'} ? '' : 'checked', $text{'acl_user_this'};
printf "<input type=radio name=user_def value=0 %s>\n",
	$_[0]->{'user'} eq '*' || !$_[0]->{'user'} ? '' : 'checked';
printf "<input name=user size=13 value='%s'></td> </tr>\n",
	$_[0]->{'user'} eq '*' || !$_[0]->{'user'} ? '' : $_[0]->{'user'};

print "<tr> <td><b>$text{'acl_add'}</b></td>\n";
printf "<td><input type=radio name=add value=1 %s> $text{'yes'}\n",
	$_[0]->{'add'} ? "checked" : "";
printf "<input type=radio name=add value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'add'} ? "" : "checked";

print "<td><b>$text{'acl_stop'}</b></td>\n";
printf "<td><input type=radio name=stop value=1 %s> $text{'yes'}\n",
	$_[0]->{'stop'} == 1 ? "checked" : "";
printf "<input type=radio name=stop value=2 %s> $text{'acl_restart'}\n",
	$_[0]->{'stop'} == 2 ? "checked" : "";
printf "<input type=radio name=stop value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'stop'} == 0 ? "checked" : "";

print "<tr> <td><b>$text{'acl_view'}</b></td>\n";
printf "<td><input type=radio name=view value=1 %s> $text{'yes'}\n",
	$_[0]->{'view'} ? "checked" : "";
printf "<input type=radio name=view value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'view'} ? "" : "checked";

print "<td><b>$text{'acl_test'}</b></td>\n";
printf "<td><input type=radio name=test value=1 %s> $text{'yes'}\n",
	$_[0]->{'test'} ? "checked" : "";
printf "<input type=radio name=test value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'test'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_delete'}</b></td>\n";
printf "<td><input type=radio name=delete value=1 %s> $text{'yes'}\n",
	$_[0]->{'delete'} ? "checked" : "";
printf "<input type=radio name=delete value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'delete'} ? "" : "checked";

print "<td><b>$text{'acl_cluster'}</b></td>\n";
printf "<td><input type=radio name=cluster value=1 %s> $text{'yes'}\n",
	$_[0]->{'cluster'} ? "checked" : "";
printf "<input type=radio name=cluster value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'cluster'} ? "" : "checked";

print "</tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the lpadmin module
sub acl_security_save
{
if ($in{'printers_def'}) {
	$_[0]->{'printers'} = '*';
	}
else {
	$_[0]->{'printers'} = join(" ", split(/\0/, $in{'printers'}));
	}
$_[0]->{'cancel'} = $in{'cancel'};
$_[0]->{'jobs'} = $in{'cancel'} == 2 ? join(" ", split(/\0/, $in{'jobs'})) : "";
$_[0]->{'add'} = $in{'add'};
$_[0]->{'stop'} = $in{'stop'};
$_[0]->{'view'} = $in{'view'};
$_[0]->{'user'} = $in{'user_def'} == 1 ? '*' :
		  $in{'user_def'} == 2 ? undef : $in{'user'};
$_[0]->{'delete'} = $in{'delete'};
$_[0]->{'test'} = $in{'test'};
$_[0]->{'cluster'} = $in{'cluster'};
}

