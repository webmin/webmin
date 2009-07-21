# fastCGI Directives

sub mod_fastcgi_directives
{
$rv = [
      ];
return &make_directives($rv, $_[0], "mod_fastcgi");
}

sub mod_fastcgi_handlers
{
return ("fastcgi-script");
}


