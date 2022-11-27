# Common functions for the xterm module

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
our %access = &get_module_acl();
do 'websockets-lib-funcs.pl';

1;