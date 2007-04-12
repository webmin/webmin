# mod_speling.pl
# Defines editors spelling correction directives

sub mod_speling_directives
{
$rv = [ [ 'CheckSpelling', 0, 5, 'virtual', '1.3-1.302' ],
	[ 'CheckSpelling', 0, 5, 'virtual directory htaccess', 1.302 ] ];
return &make_directives($rv, $_[0], "mod_speling");
}

sub edit_CheckSpelling
{
return (1, "$text{'mod_speling_autocorr'}",
        &choice_input($_[0]->{'value'}, "CheckSpelling",
        "", "$text{'no'},Off", "$text{'yes'},On", "$text{'mod_speling_default'},"));
}
sub save_CheckSpelling
{
return &parse_choice("CheckSpelling", "");
}

1;

