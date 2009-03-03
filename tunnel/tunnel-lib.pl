# tunnel-lib.pl
# Common functions for the HTTP-tunnel module

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

1;

