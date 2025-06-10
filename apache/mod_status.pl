# mod_status.pl
# This module defines the one directive and handle for mod_status

sub mod_status_directives
{
$rv = [ [ 'ExtendedStatus', 0, 0, 'global', 1.302 ] ];
return &make_directives($rv, $_[0], "mod_status");
}

sub mod_status_handlers
{
return ("server-status");
}

sub edit_ExtendedStatus
{
return (1, "$text{'mod_status_msg'}",
        &choice_input($_[0]->{'value'}, "ExtendedStatus",
	               "off", "$text{'yes'},on", "$text{'no'},off"));
}
sub save_ExtendedStatus
{
return &parse_choice("ExtendedStatus", "off");
}

1;

