
require 'dns-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the dnsadmin module
sub acl_security_form
{
print "<tr> <td valign=top rowspan=5><b>Domains this user can edit</b></td>\n";
print "<td rowspan=5 valign=top>\n";
printf "<input type=radio name=zones_def value=1 %s> %s\n",
	$_[0]->{'zones'} eq '*' ? 'checked' : '', "All zones";
printf "<input type=radio name=zones_def value=0 %s> %s<br>\n",
	$_[0]->{'zones'} eq '*' ? '' : 'checked', "Selected..";
print "<select name=zones multiple size=5>\n";
local $conf = &get_config();
local @zones = ( &find_config("primary", $conf),
		 &find_config("secondary", $conf) );
local ($z, %zcan);
map { $zcan{$_}++ } split(/\s+/, $_[0]->{'zones'});
foreach $z (sort { $a->{'value'} cmp $b->{'value'} } @zones) {
	local $v = $z->{'values'}->[0];
	printf "<option value='%s' %s>%s\n",
		$v, $zcan{$v} ? "selected" : "",
		&arpa_to_ip($v);
	}
print "</select></td>\n";

print "<td><b>Can create master zones?</b></td> <td>\n";
printf "<input type=radio name=master value=1 %s> Yes\n",
	$_[0]->{'master'} ? "checked" : "";
printf "<input type=radio name=master value=0 %s> No</td> </tr>\n",
	$_[0]->{'master'} ? "" : "checked";

print "<tr> <td><b>Can create slave zones?</b></td> <td>\n";
printf "<input type=radio name=slave value=1 %s> Yes\n",
	$_[0]->{'slave'} ? "checked" : "";
printf "<input type=radio name=slave value=0 %s> No</td> </tr>\n",
	$_[0]->{'slave'} ? "" : "checked";

print "<tr> <td><b>Can edit master zone defaults?</b></td> <td>\n";
printf "<input type=radio name=defaults value=1 %s> Yes\n",
	$_[0]->{'defaults'} ? "checked" : "";
printf "<input type=radio name=defaults value=0 %s> No</td> </tr>\n",
	$_[0]->{'defaults'} ? "" : "checked";

print "<tr> <td><b>Can update reverse addresses in any domain?</b></td> <td>\n";
printf "<input type=radio name=reverse value=1 %s> Yes\n",
	$_[0]->{'reverse'} ? "checked" : "";
printf "<input type=radio name=reverse value=0 %s> No</td> </tr>\n",
	$_[0]->{'reverse'} ? "" : "checked";

print "<tr> <td><b>Can multiple addresses have the same IP?</b></td> <td>\n";
printf "<input type=radio name=multiple value=1 %s> Yes\n",
	$_[0]->{'multiple'} ? "checked" : "";
printf "<input type=radio name=multiple value=0 %s> No</td> </tr>\n",
	$_[0]->{'multiple'} ? "" : "checked";

print "<tr> <td><b>Restrict zone files to directory</b></td>\n";
printf "<td colspan=3><input name=dir size=30 value='%s'> %s</td> </tr>\n",
	$_[0]->{'dir'}, &file_chooser_button("dir", 1);
}

# acl_security_save(&options)
# Parse the form for security options for the dnsadmin module
sub acl_security_save
{
if ($in{'zones_def'}) {
	$_[0]->{'zones'} = "*";
	}
else {
	$_[0]->{'zones'} = join(" ", split(/\0/, $in{'zones'}));
	}
$_[0]->{'master'} = $in{'master'};
$_[0]->{'slave'} = $in{'slave'};
$_[0]->{'defaults'} = $in{'defaults'};
$_[0]->{'reverse'} = $in{'reverse'};
$_[0]->{'multiple'} = $in{'multiple'};
$_[0]->{'dir'} = $in{'dir'};
}

