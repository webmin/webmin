# log_parser.pl
# Functions for parsing this module's logs

use strict;
use warnings;
do 'exports-lib.pl';
our (%text);

# parse_webmin_log(user, script, action, type, object, &params, [long])
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p, $long) = @_;
$p->{'host'} = $p->{'host'} ? &html_escape($p->{'host'}) : '*';
$object = &html_escape($object);
if ($type eq 'exports') {
	return &text('log_'.$action.'_exports', $object);
	}
elsif ($action eq 'modify') {
	return &text($long ? 'log_modify_l' : 'log_modify',
		     "<tt>$object</tt>", "<tt>$p->{'host'}</tt>");
	}
elsif ($action eq 'create') {
	return &text($long ? 'log_create_l' : 'log_create',
		     "<tt>$object</tt>", "<tt>$p->{'host'}</tt>");
	}
elsif ($action eq 'delete') {
	return &text($long ? 'log_delete_l' : 'log_delete',
		     "<tt>$object</tt>", "<tt>$p->{'host'}</tt>");
	}
elsif ($action eq 'apply') {
	return $text{'log_apply'};
	}
else {
	return undef;
	}
}

