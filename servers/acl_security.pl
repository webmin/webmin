
require 'servers-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the servers module
sub acl_security_form
{
print "<tr> <td valign=top><b>$text{'acl_servers'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=servers_def value=1 %s> %s\n",
        $_[0]->{'servers'} eq '*' ? 'checked' : '', $text{'acl_sall'};
printf "<input type=radio name=servers_def value=0 %s> %s<br>\n",
        $_[0]->{'servers'} eq '*' ? '' : 'checked', $text{'acl_ssel'};
print "<select name=servers multiple size=4 width=15>\n";
local @servers = sort { $a->{'host'} cmp $b->{'host'} } &list_servers();
local ($z, %zcan);
map { $zcan{$_}++ } split(/\s+/, $_[0]->{'servers'});
foreach $z (sort { $a->{'value'} cmp $b->{'value'} } @servers) {
        printf "<option value='%s' %s>%s</option>\n",
                $z->{'id'},
                $zcan{$z->{'host'}} || $zcan{$z->{'id'}} ? "selected" : "",
                $z->{'host'} ;
        }
print "</select></td></tr>\n";

print "<tr> <td><b>$text{'acl_edit'}</b></td> <td>\n";
print &ui_yesno_radio("edit", $_[0]->{'edit'}),"</td>\n";

print "<td><b>$text{'acl_find'}</b></td> <td>\n";
print &ui_yesno_radio("find", $_[0]->{'find'}),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_auto'}</b></td> <td>\n";
print &ui_yesno_radio("auto", $_[0]->{'auto'}),"</td>\n";

print "<td><b>$text{'acl_add'}</b></td> <td>\n";
print &ui_yesno_radio("add", $_[0]->{'add'}),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_forcefast'}</b></td> <td>\n";
print &ui_yesno_radio("forcefast", $_[0]->{'forcefast'}),"</td>\n";

print "<td><b>$text{'acl_forcetype'}</b></td> <td>\n";
print &ui_yesno_radio("forcetype", $_[0]->{'forcetype'}),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_forcelink'}</b></td> <td>\n";
print &ui_yesno_radio("forcelink", $_[0]->{'forcelink'}),"</td>\n";

print "<td><b>$text{'acl_links'}</b></td> <td>\n";
print &ui_yesno_radio("links", $_[0]->{'links'}),"</td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the servers module
sub acl_security_save
{
if ($in{'servers_def'}) {
        $_[0]->{'servers'} = "*";
        }
else {
        $_[0]->{'servers'} = join(" ", split(/\0/, $in{'servers'}));
        }
$_[0]->{'edit'} = $in{'edit'};
$_[0]->{'find'} = $in{'find'};
$_[0]->{'auto'} = $in{'auto'};
$_[0]->{'add'} = $in{'add'};
$_[0]->{'forcefast'} = $in{'forcefast'};
$_[0]->{'forcetype'} = $in{'forcetype'};
$_[0]->{'forcelink'} = $in{'forcelink'};
$_[0]->{'links'} = $in{'links'};
}

