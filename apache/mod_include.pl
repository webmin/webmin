# mod_include.pl
# Defines editors SSI directives

sub mod_include_directives
{
$rv = [ [ 'XBitHack', 0, 11, 'virtual directory htaccess' ] ];
return &make_directives($rv, $_[0], "mod_include");
}

sub mod_include_handlers
{
return ("server-parsed");
}

sub mod_include_filters
{
return ("INCLUDES");
}

sub edit_XBitHack
{
return (2, "$text{'mod_include_incl'}",
        &choice_input($_[0]->{'value'}, "XBitHack", "",
        "$text{'no'},off", "$text{'yes'},on", "$text{'mod_include_set'},full", "$text{'mod_include_default'},"));
}
sub save_XBitHack
{
return &parse_choice("XBitHack", "");
}

1;

