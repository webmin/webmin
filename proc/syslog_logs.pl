# Contains a function to supply the syslog module with extra logs

do 'proc-lib.pl';

# syslog_getlogs()
# Returns the kernel log, on Linux systems
sub syslog_getlogs
{
if ($gconfig{'os_type'} =~ /-linux$/) {
	return ( { 'cmd' => "dmesg",
		   'desc' => $text{'syslog_dmesg'},
		   'active' => 1, } );
	}
else {
	return ( );
	}
}

