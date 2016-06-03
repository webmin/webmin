# Contains a function to supply the syslog module with extra logs
use strict;
use warnings;
our (%text);

do 'bind8-lib.pl';

# syslog_getlogs()
# Returns a list of structures containing extra log files known to this module
sub syslog_getlogs
{
my $conf = &get_config();
my $logging = &find("logging", $conf);
return ( ) if (!$logging);
my @chans = &find("channel", $logging->{'members'});
my @rv;
foreach my $c (@chans) {
	my $file = &find("file", $c->{'members'});
	if ($file && $file->{'values'}->[0] =~ /^\//) {
		push(@rv, { 'file' => $file->{'values'}->[0],
			    'active' => 1,
			    'desc' => $text{'syslog_desc'} });
		}
	}
return @rv;
}

