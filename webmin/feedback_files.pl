
do 'webmin-lib.pl';

sub feedback_files
{
return ( "$config_directory/miniserv.conf",
	 "$config_directory/config" );
}

1;

