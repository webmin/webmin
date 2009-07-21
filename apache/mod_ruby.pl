# mod_ruby.pl

sub mod_ruby_directives
{
$rv = [ ];
return &make_directives($rv, $_[0], "mod_ruby");
}

sub mod_ruby_handlers
{
return ("ruby-object");
}

