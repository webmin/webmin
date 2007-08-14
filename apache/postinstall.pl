
require 'apache-lib.pl';

sub module_install
{
unlink("$module_config_directory/site");
}

