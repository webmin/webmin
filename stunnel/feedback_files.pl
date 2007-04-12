
do 'stunnel-lib.pl';

sub feedback_files
{
local %iconfig = &foreign_config("inetd");
local %xconfig = &foreign_config("xinetd");
return ( $iconfig{'inetd_conf_file'},
	 $xconfig{'xinetd_conf'} );
}

1;

