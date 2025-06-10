
do 'usermin-lib.pl';

sub feedback_files
{
return ( "$config{'usermin_dir'}/miniserv.conf",
	 "$config{'usermin_dir'}/config" );
}

1;

