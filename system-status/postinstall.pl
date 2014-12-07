
use strict;
use warnings;
require 'system-status-lib.pl';
our ($module_config_directory, $module_name);

sub module_install
{
# Create wrapper for system status setup script
if (&foreign_check("cron")) {
	&foreign_require("cron");
	&cron::create_wrapper("$module_config_directory/enable-collection.pl",
			      $module_name, "enable-collection.pl");
	}
}

