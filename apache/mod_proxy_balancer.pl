# Only exists to detect this module, as it adds no directives

sub mod_proxy_balancer_directives
{
$rv = [ ];
return &make_directives($rv, $_[0], "mod_proxy_balancer");
}


