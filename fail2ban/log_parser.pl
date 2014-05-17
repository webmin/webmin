# log_parser.pl
# Functions for parsing this module's logs

use strict;
use warnings;
do 'fail2ban-lib.pl';
our (%text);

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'filter' || $type eq 'action' || $type eq 'jail') {
	return &text('log_'.$action.'_'.$type, '<tt>'.&html_escape($object).'</tt>');
	}
elsif ($type eq 'filters' || $type eq 'actions' || $type eq 'jails') {
	return &text('log_'.$action.'_'.$type, $object);
	}
elsif ($action eq 'manual') {
	return &text('log_manual', '<tt>'.&html_escape($object).'</tt>');
	}
else {
	return $text{'log_'.$action};
	}
}

