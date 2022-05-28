# Contains a function to supply the syslog module with extra logs

require 'proc-lib.pl';

# syslog_getlogs()
# Returns the kernel log, on Linux systems
sub syslog_getlogs
{
if ($gconfig{'os_type'} =~ /-linux$/) {
	my %syslog_config = &foreign_config('syslog');
	if (!(&has_command('journalctl') &&
	      ! -r $syslog_config{'syslog_conf'})) {
		return ( { 'cmd' => "dmesg",
			   'desc' => $text{'syslog_dmesg'},
			   'active' => 1, } );
		}
	else {
		return ( );
		}
	}
else {
	return ( );
	}
}

