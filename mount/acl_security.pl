
require 'mount-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the mount module
sub acl_security_form
{
print "<tr> <td><b>$text{'acl_fs'}</b></td>\n";
print "<td colspan=3>",&ui_opt_textbox("fs", $_[0]->{'fs'}, 40,
		$text{'acl_all'}, $text{'acl_list'}),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_types'}</b></td>\n";
print "<td colspan=3>",&ui_opt_textbox("types", $_[0]->{'types'}, 30,
		$text{'acl_all'}, $text{'acl_fslist'}),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_create'}</b></td>\n";
print "<td>",&ui_radio("create", $_[0]->{'create'},
	       [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<td><b>$text{'acl_only'}</b></td>\n";
print "<td>",&ui_radio("only", $_[0]->{'only'},
	       [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_user'}</b></td>\n";
print "<td>",&ui_radio("user", $_[0]->{'user'},
	       [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<td><b>$text{'acl_hide'}</b></td>\n";
print "<td>",&ui_radio("hide", $_[0]->{'hide'},
	       [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_browse'}</b></td>\n";
print "<td>",&ui_radio("browse", $_[0]->{'browse'},
	       [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "</tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the mount module
sub acl_security_save
{
$_[0]->{'fs'} = $in{'fs_def'} ? undef : $in{'fs'};
$_[0]->{'types'} = $in{'types_def'} ? undef : $in{'types'};
$_[0]->{'only'} = $in{'only'};
$_[0]->{'create'} = $in{'create'};
$_[0]->{'user'} = $in{'user'};
$_[0]->{'hide'} = $in{'hide'};
$_[0]->{'browse'} = $in{'browse'};
}

