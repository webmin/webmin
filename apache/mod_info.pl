# mod_info.pl
# This module defines only handlers

sub mod_info_directives
{
return ();
}

sub mod_info_handlers
{
return ("server-info");
}

1;
