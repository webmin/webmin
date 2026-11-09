# log_parser.pl
# Functions for parsing this module's logs

do 'cluster-shell-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq 'clear') {
	return $text{'log_clear'};
	}
elsif ($action eq 'run') {
	my @server = split(/\0/, $p->{'run'});
	if ($long) {
		return &text('log_run_l', "<tt>".&html_escape($p->{'cmd'})."</tt>",
		     join(", ", map { $_ ? "<tt>".&html_escape($_)."</tt>"
					 : $text{'index_this'} } @server));
		}
	else {
		return &text('log_run', "<tt>".&html_escape($p->{'cmd'})."</tt>",
					scalar(@server));
		}
	}
}

