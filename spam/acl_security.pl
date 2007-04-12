
require 'spam-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the spam module
sub acl_security_form
{
print "<tr> <td valign=top><b>$text{'acl_avail'}</b></td>\n";
print "<td><select name=avail rows=6 multiple>\n";
local %avail = map { $_, 1 } split(/,/, $_[0]->{'avail'});
foreach $a ('white', 'score', 'report', 'user', 'header', 'setup', 'procmail') {
	printf "<option value=%s %s>%s\n",
		$a, $avail{$a} ? "selected" : "", $text{$a."_title"};
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'acl_file'}</b></td>\n";
print "<td>",&ui_opt_textbox("file", $_[0]->{'file'}, 40, $text{'acl_filedef'}),
      "</td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the cron module
sub acl_security_save
{
$_[0]->{'avail'} = join(",", split(/\0/, $in{'avail'}));
$_[0]->{'file'} = $in{'file_def'} ? undef : $in{'file'};
}

