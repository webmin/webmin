# log_parser.pl
# Functions for parsing this module's logs

do 'cluster-shell-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq 'clear') {
	return $text{'log_clear'};
	}
elsif ($action eq 'run') {
	local @server = split(/\0/, $p->{'run'});
	if ($long) {
		return &text('log_run_l', "<tt>$p->{'cmd'}</tt>",
		     join(", ", map { $_ ? "<tt>$_</tt>"
					 : $text{'index_this'} } @server));
		}
	else {
		return &text('log_run', "<tt>$p->{'cmd'}</tt>",
					scalar(@server));
		}
	}
}

