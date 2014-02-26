
require 'format-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the format module
sub acl_security_form
{
local @dlist = &list_disks();
local ($d, %dcan);
map { $dcan{$_}++ } split(/\s+/, $_[0]->{'disks'});
print "<tr> <td valign=top><b>$text{'acl_disks'}</b></td> <td>\n";
printf "<input type=radio name=disks_def value=1 %s> %s\n",
	$_[0]->{'disks'} eq '*' ? 'checked' : '', $text{'acl_dall'};
printf "<input type=radio name=disks_def value=0 %s> %s<br>\n",
	$_[0]->{'disks'} eq '*' ? '' : 'checked', $text{'acl_dsel'};
print "<select name=disks size=4 multiple>\n";
foreach $d (@dlist) {
	$d->{'device'} =~ s/^.*\///;
	printf "<option value='%s' %s>%s</option>\n",
		$d->{'device'},
		$dcan{$d->{'device'}} ? "selected" : "",
		"$d->{'desc'} ($d->{'type'})";
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'acl_view'}</b></td>\n";
print "<td>",&ui_radio("view", $access{'view'}, 
	       [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]),"</td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the format module
sub acl_security_save
{
if ($in{'disks_def'}) {
	$_[0]->{'disks'} = "*";
	}
else {
	$_[0]->{'disks'} = join(" ", split(/\0/, $in{'disks'}));
	}
$_[0]->{'view'} = $in{'view'};
}

