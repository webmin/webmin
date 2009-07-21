
do 'nis-lib.pl';

sub feedback_files
{
return ( "/var/yp/Makefile",
	 $config{'client_conf'},
	 $config{'nsswitch_conf'},
	 $config{'securenets'} );
}

1;

