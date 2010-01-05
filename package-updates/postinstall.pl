
do 'package-updates-lib.pl';

sub module_install
{
# Force clear all caches, as collected information may have changed
&flush_package_caches();

if ($software::update_system ne 'yum' &&
    !&foreign_check("security-updates")) {
	# Re-generate cache of possible packages
	&list_possible_updates();
	}
}

