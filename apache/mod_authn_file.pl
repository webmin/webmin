# mod_authn_file.pl
# Defines editors for user text-file authentication directives

sub mod_authn_file_directives
{
local($rv);
$rv = [ [ 'AuthUserFile', 0, 4, 'directory htaccess' ] ];
return &make_directives($rv, $_[0], "mod_authn_file");
}

sub edit_AuthUserFile
{
local $uf = $_[0] && -r "list_authusers.cgi" ? 1 : 0;
return (2, $text{'mod_auth_ufile'},
       &opt_input($_[0]->{'value'}, "AuthUserFile", $text{'default'}, 45).
       &file_chooser_button("AuthUserFile", 0).
       ($uf ? "&nbsp;".&ui_link("list_authusers.cgi?file=".$_[0]->{'value'}.
       "&url=".&urlize(&this_url()), $text{'mod_auth_uedit'}) : ""));
}
sub save_AuthUserFile
{
$in{'AuthUserFile_def'} || &allowed_auth_file($in{'AuthUserFile'}) ||
        &error($text{'mod_auth_eudir'});
return &parse_opt("AuthUserFile", '^\S+$', $text{'mod_auth_eufile'});
}

