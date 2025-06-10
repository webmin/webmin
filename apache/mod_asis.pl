# mod_asis.pl
# No directives

sub mod_asis_directives
{
return ();
}

sub mod_asis_handlers
{
return ("send-as-is");
}

1;

