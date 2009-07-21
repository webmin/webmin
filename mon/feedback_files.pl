
do 'mon-lib.pl';

sub feedback_files
{
return ( $mon_config_file, &mon_auth_file(), &mon_users_file() );
}

1;

