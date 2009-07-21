# Contains a function to supply the syslog module with extra logs

do 'bind8-lib.pl';

# syslog_getlogs()
# Returns a list of structures containing extra log files known to this module
sub syslog_getlogs
{
local $conf = &get_config();
local $logging = &find("logging", $conf);
return ( ) if (!$logging);
local @chans = &find("channel", $logging->{'members'});
local @rv;
foreach my $c (@chans) {
	local $file = &find("file", $c->{'members'});
	if ($file) {
		push(@rv, { 'file' => $file->{'values'}->[0],
			    'active' => 1,
			    'desc' => $text{'syslog_desc'} });
		}
	}
return @rv;
}

