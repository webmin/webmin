
require 'majordomo-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the majordomo module
sub acl_security_form
{
local $conf = &get_config();
local @lists = &list_lists($conf);
print "<tr> <td valign=top rowspan=3><b>$text{'acl_lists'}</b></td>\n";
print "<td rowspan=3 valign=top>\n";
printf "<input type=radio name=lists_def value=1 %s> %s\n",
	$_[0]->{'lists'} eq '*' ? 'checked' : '', $text{'acl_lall'};
printf "<input type=radio name=lists_def value=0 %s> %s<br>\n",
	$_[0]->{'lists'} eq '*' ? '' : 'checked', $text{'acl_lsel'};
print "<select name=lists multiple size=3 width=150>\n";
local (%lcan, $l);
map { $lcan{$_}++ } split(/\s+/, $_[0]->{'lists'});
foreach $l (@lists) {
	printf "<option %s>%s\n",
		$lcan{$l} ? "selected" : "", $l;
	}
print "</select></td>\n";

print "<td><b>$text{'acl_global'}</b></td> <td>\n";
printf "<input type=radio name=global value=1 %s> $text{'yes'}\n",
	$_[0]->{'global'} ? "checked" : "";
printf "<input type=radio name=global value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'global'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_create'}</b></td> <td>\n";
printf "<input type=radio name=create value=1 %s> $text{'yes'}\n",
	$_[0]->{'create'} ? "checked" : "";
printf "<input type=radio name=create value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'create'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_edit'}</b></td> <td>\n";
printf "<input type=radio name=edit value=1 %s> $text{'yes'}\n",
	$_[0]->{'edit'} ? "checked" : "";
printf "<input type=radio name=edit value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'edit'} ? "" : "checked";
}

# acl_security_save(&options)
# Parse the form for security options for the majordomo module
sub acl_security_save
{
if ($in{'lists_def'}) {
	$_[0]->{'lists'} = "*";
	}
else {
	$_[0]->{'lists'} = join(" ", split(/\0/, $in{'lists'}));
	}
$_[0]->{'global'} = $in{'global'};
$_[0]->{'create'} = $in{'create'};
$_[0]->{'edit'} = $in{'edit'};
}

