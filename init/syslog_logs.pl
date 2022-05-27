# Contains a function to supply the syslog module with extra logs

do 'init-lib.pl';

# syslog_getlogs()
# Returns the output from journalctl if installed
sub syslog_getlogs
{
if (&has_command("journalctl")) {
	my %syslog_config = &foreign_config('syslog');
	my %syslog_lang = &load_language('syslog');
	my $lines = $syslog_config{'lines'} || 1000;
	my @logs = (
		{ 'cmd' => "journalctl -n $lines",
		  'desc' => $text{'syslog_journalctl'},
		  'active' => 1, },
		{ 'cmd' => "journalctl -x -n $lines",
		  'desc' => $text{'syslog_expla_journalctl'},
		  'active' => 1, } );
	my $norsyslog = ! -r $syslog_config{'syslog_conf'};
	if ($norsyslog) {
			foreach my $conf (keys %syslog_config) {
				if ($conf =~ /file_(.*)/) {
					my $logfile = "$1";
					push(@logs,
						{ 'file' => $logfile,
						  'desc' => $syslog_lang{$syslog_config{$conf}},
						  'active' => 1 }) if (-r $logfile);
					}
				}
			}
	return sort { $a->{'file'} cmp $b->{'file'} } @logs;
	}
else {
	return ( );
	}
}

