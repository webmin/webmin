# mod_pam.pl

sub mod_pam_directives
{
local $rv = [
	[ 'AuthPAM', 0, 6, 'virtual global', 1.20 ],
	[ 'AuthPAMConfig', 0, 6, 'virtual global', 1.20 ]
	];
return &make_directives($rv, $_[0], "mod_pam");
}

sub edit_AuthPAM
{
return (1, $text{'mod_pam_pam'},
	&choice_input($_[0]->{'value'}, "AuthPAM", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_AuthPAM
{
return &parse_choice("AuthPAM", "");
}

sub edit_AuthPAMConfig
{
return (1, $text{'mod_pam_config'},
	&opt_input($_[0]->{'value'}, "AuthPAMConfig", $text{'default'}, 15));
}
sub save_AuthPAMConfig
{
return &parse_opt("AuthPAMConfig", '^\S+$', $text{'mod_pam_econfig'});
}

