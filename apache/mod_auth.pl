# mod_auth.pl
# Defines editors for text-file authentication directives

sub mod_auth_directives
{
local($rv);
$rv = [ [ 'AuthUserFile AuthGroupFile AuthAuthoritative', 0, 4, 'directory htaccess' ] ];
return &make_directives($rv, $_[0], "mod_auth");
}

sub edit_AuthUserFile_AuthGroupFile_AuthAuthoritative
{
local($rv, $uf, $gf);
$uf = $_[0] && -r "list_authusers.cgi" ? 1 : 0;
$gf = $_[1] && -r "list_authgroups.cgi" ? 1 : 0;
$rv = "<table border><tr><td><table>\n";

$rv .= "<tr> <td><b>$text{'mod_auth_ufile'}</b></td> <td>".
       &opt_input($_[0]->{'value'}, "AuthUserFile", $text{'default'}, 45).
       &file_chooser_button("AuthUserFile", 0).
       ($uf ? "&nbsp;".&ui_link("list_authusers.cgi?file=".$_[0]->{'value'}.
       "&url=".&urlize(&this_url()), $text{'mod_auth_uedit'}) : "")."</td></tr>\n";

$rv .= "<tr> <td><b>$text{'mod_auth_gfile'}</b></td> <td>".
       &opt_input($_[1]->{'value'}, "AuthGroupFile", $text{'default'}, 45).
       &file_chooser_button("AuthGroupFile", 0).
       ($gf ? "&nbsp;".&ui_link("list_authgroups.cgi?file=".$_[1]->{'value'}.
       "&url=".&urlize(&this_url()), $text{'mod_auth_gedit'}) : "")."</td></tr>\n";

$rv .= "<tr> <td><b>$text{'mod_auth_pass'}</b></td> <td>".
       &choice_input($_[2]->{'value'}, "AuthAuthoritative", "",
       "$text{'yes'},off", "$text{'no'},on", "$text{'default'},").
       "</td> </tr>\n";
$rv .= "</table></td></tr></table>\n";
return (2, "$text{'mod_auth_auth'}", $rv);
}
sub save_AuthUserFile_AuthGroupFile_AuthAuthoritative
{
$in{'AuthUserFile_def'} || &allowed_auth_file($in{'AuthUserFile'}) ||
	&error($text{'mod_auth_eudir'});
$in{'AuthGroupFile_def'} || &allowed_auth_file($in{'AuthGroupFile'}) ||
	&error($text{'mod_auth_egdir'});
return (&parse_opt("AuthUserFile", '^\S+$', $text{'mod_auth_eufile'}) ,
        &parse_opt("AuthGroupFile", '^\S+$', $text{'mod_auth_egfile'}) ,
        &parse_choice("AuthAuthoritative", ""));
}

1;

