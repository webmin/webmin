# Empty for now

sub mod_rewrite_directives
{
$rv = [
      ];
return &make_directives($rv, $_[0], "mod_rewrite");
}

1;
