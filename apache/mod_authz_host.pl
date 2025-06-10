# mod_authz_host.pl
# Just calls mod_access.pl , to handle the move of these directives to a
# new module in Apache 2.2.0

require 'mod_access.pl';

sub mod_authz_host_directives
{
local($rv);
$rv = [ [ 'allow deny order', 1, 4, 'directory htaccess' ] ];
return &make_directives($rv, $_[0], "mod_authz_host");
}


