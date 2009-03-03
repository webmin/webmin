# cluster-shell-lib.pl
# Doesn't really contain anything ..

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("servers", "servers-lib.pl");

$commands_file = "$module_config_directory/commands";

1;

