
require 'dfsadmin-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the format module
sub acl_security_form
{
print "<tr> <td><b>$text{'acl_view'}</b></td>\n";
print "<td>",&ui_radio("view", $access{'view'}, 
	       [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]),"</td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the format module
sub acl_security_save
{
$_[0]->{'view'} = $in{'view'};
}

