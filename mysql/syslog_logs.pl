# Contains a function to supply the syslog module with extra logs

do 'mysql-lib.pl';

# syslog_getlogs()
# Returns a list of structures containing extra log files known to this module
sub syslog_getlogs
{
local $conf = &get_mysql_config();
local ($sect) = grep { $_->{'name'} eq 'mysqld_safe' ||
		       $_->{'name'} eq 'safe_mysqld' } @$conf;
local @rv;
if ($sect) {
	local $log = &find_value("err-log", $sect->{'members'});
	if ($log) {
		push(@rv, { 'file' => $log,
			    'desc' => $text{'syslog_desc'},
			    'active' => 1,
			  } );
		}
	local $log = &find_value("log", $sect->{'members'});
	if ($log) {
		push(@rv, { 'file' => $log,
			    'desc' => $text{'syslog_logdesc'},
			    'active' => 1,
			  } );
		}
	}
return @rv;
}

