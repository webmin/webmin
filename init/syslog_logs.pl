# Contains a function to supply the syslog module with extra logs

do 'init-lib.pl';

# syslog_getlogs()
# Returns the output from journalctl if installed
sub syslog_getlogs
{
if (&has_command("journalctl")) {
	return ( { 'cmd' => "journalctl -n 1000",
		   'desc' => $text{'syslog_journalctl'},
		   'active' => 1, } );
	}
else {
	return ( );
	}
}

