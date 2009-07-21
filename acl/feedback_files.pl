
do 'acl-lib.pl';

sub feedback_files
{
return ( "$config_directory/miniserv.conf",
	 "$config_directory/miniserv.users",
	 "$config_directory/webmin.acl",
	 "$config_directory/webmin.groups",
	 "$config_directory/config" );
}

1;

