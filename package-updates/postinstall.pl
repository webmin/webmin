
do 'package-updates-lib.pl';

sub module_install
{
# Force clear all caches, as collected information may have changed
&flush_package_caches();

if ($software::update_system ne 'yum') {
	# Re-generate cache of available packages
	&list_available();
	}
}

