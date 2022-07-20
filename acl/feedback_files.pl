
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
do 'acl-lib.pl';
our ($config_directory);

sub feedback_files
{
return ( "$config_directory/miniserv.conf",
	 "$config_directory/miniserv.users",
	 "$config_directory/webmin.acl",
	 "$config_directory/webmin.groups",
	 "$config_directory/config" );
}

1;

