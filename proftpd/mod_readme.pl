# mod_readme.pl

sub mod_readme_directives
{
local $rv = [
	[ 'DisplayReadme', 0, 2, 'virtual anon global', 1.20 ]
	];
return &make_directives($rv, $_[0], "mod_readme");
}

sub edit_DisplayReadme
{
return (1, $text{'mod_readme_display'},
	&opt_input($_[0]->{'value'}, "DisplayReadme", $text{'mod_readme_none'},
		   15));
}
sub save_DisplayReadme
{
return &parse_opt("DisplayReadme", '^\S+$', $text{'mod_readme_edisplay'});
}
