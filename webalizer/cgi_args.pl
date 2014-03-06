
use strict;
use warnings;
our (%text, %access);
do 'webalizer-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_log.cgi') {
	# Link to first log that can be edited
	my @logs = grep { &can_edit_log($_->{'file'}) } &get_all_logs();
	if (!@logs) {
		return $access{'add'} ? 'new=1' : 'none';
		}
	elsif (!$access{'view'}) {
		return 'file='.&urlize($logs[0]->{'file'}).
		       '&type='.&urlize($logs[0]->{'type'}).
		       '&custom='.&urlize($logs[0]->{'custom'});
		}
	else {
		return 'none';
		}
	}
elsif ($cgi eq 'view_log.cgi') {
	# Show first log
	my @logs = grep { my $lconf = &get_log_config($_->{'file'});
			  &can_edit_log($_->{'file'}) &&
			  $lconf->{'dir'} } &get_all_logs();
	return @logs ? &urlize($logs[0]->{'file'}).'/index.html' : 'none';
	}
return undef;
}
