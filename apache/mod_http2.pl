# mod_http2.pl

sub mod_http2_directives
{
$rv = [ ];
return &make_directives($rv, $_[0], "mod_http2");
}

