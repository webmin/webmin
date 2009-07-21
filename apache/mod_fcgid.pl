# Not done yet

sub mod_fcgid_directives
{
$rv = [
      ];
return &make_directives($rv, $_[0], "mod_fcgid");
}

sub mod_fcgid_handlers
{
return ("fcgid-script");
}

1;
