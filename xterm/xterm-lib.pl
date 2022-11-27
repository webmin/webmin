# Common functions for the xterm module

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
our %access = &get_module_acl();
do "$module_root_directory/websockets-lib-funcs.pl";

1;