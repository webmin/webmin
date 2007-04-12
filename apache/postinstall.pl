
require 'apache-lib.pl';

sub module_install
{
chmod(0644, "$module_config_directory/site");
}

