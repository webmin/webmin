# mod_auth_dbm.pl
# Defines editors for DBM file authentication directives

sub mod_auth_dbm_directives
{
local($rv);
$rv = [ [ 'AuthDBMUserFile AuthDBMGroupFile AuthDBMAuthoritative', 0, 4, 'directory htaccess' ],
	[ 'AuthDBMType', 0, 4, 'directory htaccess', 2.030, -1 ] ];
return &make_directives($rv, $_[0], "mod_auth_dbm");
}

sub edit_AuthDBMUserFile_AuthDBMGroupFile_AuthDBMAuthoritative
{
local($rv, $uf, $gf);
$uf = $_[0] ? 1 : 0; $gf = $_[1] ? 1 : 0;
$rv = "<table border><tr><td><table>\n";

$rv .= "<tr> <td><b>$text{'mod_auth_dbm_ufile'}</b></td> <td>".
       &opt_input($_[0]->{'value'}, "AuthDBMUserFile", $text{'default'}, 25).
       &file_chooser_button("AuthDBMUserFile", 0)."</td></tr>\n";

$rv .= "<tr> <td><b>$text{'mod_auth_dbm_gfile'}</b></td> <td>".
       &opt_input($_[1]->{'value'}, "AuthDBMGroupFile", $text{'default'}, 25).
       &file_chooser_button("AuthDBMGroupFile", 0)."</td></tr>\n";

$rv .= "<tr> <td><b>$text{'mod_auth_dbm_pass'}</b></td> <td>".
       &choice_input($_[2]->{'value'}, "AuthDBMAuthoritative", "",
       "$text{'yes'},off", "$text{'no'},on", "$text{'default'},").
       "</td> </tr>\n";
$rv .= "</table></td></tr></table>\n";
return (2, $text{'mod_auth_dbm_auth'}, $rv);
}
sub save_AuthDBMUserFile_AuthDBMGroupFile_AuthDBMAuthoritative
{
local(@rv);
@rv = (&parse_opt("AuthDBMUserFile", '^\S+$', $text{'mod_auth_dbm_eufile'}) ,
       &parse_opt("AuthDBMGroupFile", '^\S+$', $text{'mod_auth_dbm_egfile'}) ,
       &parse_choice("AuthDBMAuthoritative", ""));
return @rv;
}

sub edit_AuthDBMType
{
return (1, $text{'mod_auth_dbm_type'},
	&select_input($_[0]->{'value'}, "AuthDBMType", "",
		      "$text{'default'},", "GDBM,GDBM", "SDBM,SDBM", "DB,DB",
		      "$text{'mod_auth_dbm_default'},default"));
}
sub save_AuthDBMType
{
return &parse_select("AuthDBMType", "");
}

1;

