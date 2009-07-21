# mod_dav.pl
# Editors for DAV directives

sub mod_dav_directives
{
local $rv;
$rv = [ [ 'Dav', 0, 5, 'directory' ],
	[ 'DavDepthInfinity', 0, 5, 'virtual directory' ],
	[ 'DavMinTimeout', 0, 5, 'virtual directory' ],
      ];
return &make_directives($rv, $_[0], "mod_dav");
}

sub edit_Dav
{
local @extra;
push(@extra, "$_[0]->{'value'},$_[0]->{'value'}")
	if ($_[0]->{'value'} && $_[0]->{'value'} !~ /^(on|off)$/i);
return (1, $text{'mod_dav_active'},
	&choice_input($_[0]->{'value'}, "Dav", "",
	      "$text{'yes'},on", "$text{'no'},off", @extra, "$text{'default'},"));
}
sub save_Dav
{
return &parse_choice("Dav");
}

sub edit_DavDepthInfinity
{
return (1, $text{'mod_dav_inf'},
	&choice_input($_[0]->{'value'}, "DavDepthInfinity", "",
	      "$text{'yes'},on", "$text{'no'},off", "$text{'default'},"));
}
sub save_DavDepthInfinity
{
return &parse_choice("DavDepthInfinity");
}

sub edit_DavMinTimeout
{
return (1,
	$text{'mod_dav_timeout'},
	&opt_input($_[0]->{'value'}, "DavMinTimeout", $text{'default'}, 4));
}
sub save_DavMinTimeout
{
return &parse_opt("DavMinTimeout", '^\d+$',
		  $text{'mod_dav_etimeout'});
}

1;

