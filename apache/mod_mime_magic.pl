# mod_mime_magic.pl
# Defines MIME type guessing directives

sub mod_mime_magic_directives
{
$rv = [ [ 'MimeMagicFile', 0, 6, 'virtual' ] ];
return &make_directives($rv, $_[0], "mod_mime_magic");
}

sub edit_MimeMagicFile
{
return (1, "$text{'mod_mime_magic_file'}",
        &opt_input($_[0]->{'value'}, "MimeMagicFile", "$text{'mod_mime_magic_none'}", 20).
        &file_chooser_button("MimeMagicFile", 1));
}
sub save_MimeMagicFile
{
return &parse_opt("MimeMagicFile", '^\S+$', "$text{'mod_mime_magic_efile'}");
}

1;

