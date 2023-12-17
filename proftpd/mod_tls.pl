
sub mod_tls_directives
{
local $rv = [
	[ 'TLSEngine', 0, 0, 'virtual global', 1.27 ],
	];
return &make_directives($rv, $_[0], "mod_tls");
}

sub edit_TLSEngine
{
return (2, $text{'mod_tls_engine'},
	&choice_input($_[0]->{'value'}, "TLSEngine", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_TLSEngine
{
return &parse_choice("TLSEngine", "");
}
