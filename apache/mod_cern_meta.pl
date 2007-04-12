# mod_cern_meta.pl
# Defines editors CERN metafile directives

sub mod_cern_meta_directives
{
local($rv);
$rv = [ [ 'MetaFiles', 0, 5, 'directory', 1.3 ],
        [ 'MetaDir', 0, 5, 'server', -1.3 ],
        [ 'MetaDir', 0, 5, 'directory', 1.3 ],
        [ 'MetaSuffix', 0, 5, 'server', -1.3 ],
        [ 'MetaSuffix', 0, 5, 'directory', 1.3 ] ];
return &make_directives($rv, $_[0], "mod_cern_meta");
}

sub edit_MetaFiles
{
return (1, "$text{'mod_cern_meta_process'}",
        &choice_input($_[0]->{'value'}, "MetaFiles", "off",
        "$text{'yes'},on", "$text{'no'},off"));
}
sub save_MetaFiles
{
return &parse_choice("MetaFiles", "off");
}

sub edit_MetaDir
{
return (1, "$text{'mod_cern_meta_dir'}",
        &opt_input($_[0]->{'value'}, "MetaDir", "$text{'mod_cern_meta_default'}", 8));
}
sub save_MetaDir
{
return &parse_opt("MetaDir", '^\S+$', "$text{'mod_cern_meta_edir'}");
}

sub edit_MetaSuffix
{
return (1, "$text{'mod_cern_meta_suffix'}",
        &opt_input($_[0]->{'value'}, "MetaSuffix", "$text{'mod_cern_meta_default2'}", 15));
}
sub save_MetaSuffix
{
return &parse_opt("MetaSuffix", '^\S+$', "$text{'mod_cern_meta_esuffix'}");
}

1;

