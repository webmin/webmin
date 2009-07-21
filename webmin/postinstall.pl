
require 'webmin-lib.pl';

sub module_install
{
# Update cache of which module's underlying servers are installed 
&build_installed_modules();

# Pick a random update time
if (!defined($config{'uphour'}) ||
    $config{'uphour'} == 3 && $config{'upmins'} == 0 && !$config{'update'}) {
	&seed_random();
	$config{'uphour'} = int(rand()*24);
	$config{'upmins'} = int(rand()*60);
	&save_module_config();
	}
}

