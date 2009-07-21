# mod_site.pl

sub mod_site_directives
{
local $rv = [
#	[ 'AllowChmod', 0, 3, 'virtual directory anon limit ftpaccess global', 1.20 ]
	];
return &make_directives($rv, $_[0], "mod_site");
}

sub edit_AllowChmod
{
return (1, $text{'mod_site_chmod'},
	&choice_input($_[0]->{'value'}, "AllowChmod", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_AllowChmod
{
return &parse_choice("AllowChmod", "");
}
