
do 'package-updates-lib.pl';

sub module_install
{
# Force clear all caches, as collected information may have changed
&flush_package_caches();
}

