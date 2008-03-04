
require 'webmin-lib.pl';

# Update cache of which module's underlying servers are installed 
sub module_install
{
&build_installed_modules();
}

