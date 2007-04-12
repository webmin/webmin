# cluster-shell-lib.pl
# Doesn't really contain anything ..

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
&foreign_require("servers", "servers-lib.pl");

$commands_file = "$module_config_directory/commands";

1;

