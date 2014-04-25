# Contains a function to supply the syslog module with extra logs

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
do 'squid-lib.pl';

# syslog_getlogs()
# Returns the Squid cache and store logs
sub syslog_getlogs
{
my @rv;
if (-d $config{'log_dir'}) {
	push(@rv, { 'file' => "$config{'log_dir'}/access.log",
		    'desc' => $text{'syslog_access'},
		    'active' => 1 });
	push(@rv, { 'file' => "$config{'log_dir'}/cache.log",
		    'desc' => $text{'syslog_cache'},
		    'active' => 1 });
	push(@rv, { 'file' => "$config{'log_dir'}/store.log",
		    'desc' => $text{'syslog_store'},
		    'active' => 1 });
	}
return @rv;
}

