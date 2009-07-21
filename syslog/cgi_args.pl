
do 'syslog-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_log.cgi' && $access{'syslog'}) {
	# Link to editor for first log
	my $conf = &get_config();
	my @logs = grep { !$_->{'tag'} && &can_edit_log($_) } @$conf;
	return @logs ? 'idx='.$logs[0]->{'index'} :
	       $access{'noedit'} ? 'none' : 'new=1';
	}
elsif ($cgi eq 'save_log.cgi') {
	if ($access{'syslog'}) {
		# View first system log
		my $conf = &get_config();
		my @logs = grep { !$_->{'tag'} && &can_edit_log($_) &&
				  $_->{'file'} && -f $_->{'file'} } @$conf;
		if (@logs) {
			return 'view=1&idx='.$logs[0]->{'index'};
			}
		}
	# View first individual log
	my @extras = grep { &can_edit_log($_) } &extra_log_files();
	return @extras ? 'view=1&extra='.&urlize($extras[0]->{'file'})
		       : 'none';
	}
return undef;
}
