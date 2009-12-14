
require 'custom-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the custom module
sub acl_security_form
{
local $mode = $_[0]->{'cmds'} eq '*' ? 1 :
	      $_[0]->{'cmds'} =~ /^\!/ ? 2 : 0;
print "<tr> <td valign=top><b>$text{'acl_cmds'}</b></td> <td>\n";
printf "<input type=radio name=cmds_def value=1 %s> %s\n",
	$mode == 1 ? 'checked' : '', $text{'acl_call'};
printf "<input type=radio name=cmds_def value=0 %s> %s\n",
	$mode == 0 ? 'checked' : '', $text{'acl_csel'};
printf "<input type=radio name=cmds_def value=2 %s> %s<br>\n",
	$mode == 2 ? 'checked' : '', $text{'acl_cexcept'};
print "<select name=cmds size=10 multiple width=200>\n";
local @cmds = &sort_commands(&list_commands());
local ($c, %ccan);
map { $ccan{$_}++ } split(/\s+/, $_[0]->{'cmds'});
foreach $c (@cmds) {
	printf "<option value=%s %s> %s\n",
		$c->{'id'},
		$ccan{$c->{'id'}} ? "selected" : "",
		$c->{'desc'};
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'acl_edit'}</b></td> <td>\n";
printf "<input type=radio name=edit value=1 %s> $text{'yes'}\n",
	$_[0]->{'edit'} ? "checked" : "";
printf "<input type=radio name=edit value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'edit'} ? "" : "checked";
}

# acl_security_save(&options)
# Parse the form for security options for the custom module
sub acl_security_save
{
if ($in{'cmds_def'} == 1) {
	$_[0]->{'cmds'} = "*";
	}
elsif ($in{'cmds_def'} == 0) {
	$_[0]->{'cmds'} = join(" ", split(/\0/, $in{'cmds'}));
	}
else {
	$_[0]->{'cmds'} = join(" ", "!", split(/\0/, $in{'cmds'}));
	}
$_[0]->{'edit'} = $in{'edit'};
}

