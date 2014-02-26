# mod_authz_groupfile.pl
# Defines editors for user text-file authentication directives

sub mod_authz_groupfile_directives
{
local($rv);
$rv = [ [ 'AuthGroupFile', 0, 4, 'directory htaccess' ] ];
return &make_directives($rv, $_[0], "mod_authz_groupfile");
}

sub edit_AuthGroupFile
{
local $uf = $_[0] && -r "list_authgroups.cgi" ? 1 : 0;
return (2, $text{'mod_auth_gfile'},
       &opt_input($_[0]->{'value'}, "AuthGroupFile", $text{'default'}, 45).
       &file_chooser_button("AuthGroupFile", 0).
       ($uf ? "&nbsp;".&ui_link("list_authgroups.cgi?file=".$_[0]->{'value'}.
       "&url=".&urlize(&this_url()), $text{'mod_auth_gedit'}) : ""));
}
sub save_AuthGroupFile
{
$in{'AuthGroupFile_def'} || &allowed_auth_file($in{'AuthGroupFile'}) ||
        &error($text{'mod_auth_egdir'});
return &parse_opt("AuthGroupFile", '^\S+$', $text{'mod_auth_egfile'});
}

