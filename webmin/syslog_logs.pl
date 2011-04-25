# Contains a function to supply the syslog module with extra logs

do 'webmin-lib.pl';

# syslog_getlogs()
# Returns the Webmin error log
sub syslog_getlogs
{
my %miniserv;
&get_miniserv_config(\%miniserv);
if ($miniserv{'errorlog'} eq '-') {
	# Logging to stdout
	return ( );
	}
elsif ($miniserv{'errorlog'}) {
	# Specific file
	return ( { 'file' => $miniserv{'errorlog'},
		   'desc' => $text{'syslog_errorlog'},
		   'active' => 1, } );
	}
elsif ($miniserv{'logfile'} =~ /^(.*)\/[^\/]+$/) {
	# Relative to main log
	return ( { 'file' => "$1/miniserv.error",
		   'desc' => $text{'syslog_errorlog'},
		   'active' => 1, } );
	}
}

