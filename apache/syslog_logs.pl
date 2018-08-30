# Contains a function to supply the syslog module with extra logs

do 'apache-lib.pl';

# syslog_getlogs()
# Returns the main error log, if it exists
sub syslog_getlogs
{
local $conf = &get_config();
local $errlog = &find_directive("ErrorLog", $conf, 1);
local @rv;
if ($errlog && $errlog !~ /^\|/ && $errlog !~ /^syslog:/) {
	push(@rv, { 'file' => &server_root($errlog),
		    'desc' => $text{'syslog_desc'},
		    'active' => 1 });
	}
return @rv;
}

