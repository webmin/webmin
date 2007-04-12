# log_parser.pl
# Functions for parsing this module's logs

do 'majordomo-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
$object = &html_escape($object);
$p->{'addr'} = &html_escape($p->{'addr'});
if ($action eq 'global') {
	return $text{'log_global'};
	}
elsif ($action eq 'create') {
	return &text("log_create_${type}", "<tt>$object</tt>");
	}
elsif ($action eq 'delete') {
	return &text("log_delete_${type}", "<tt>$object</tt>");
	}
elsif ($action eq 'subscribe') {
	return &text('log_subscribe', "<tt>$object</tt>",
				      "<tt>$p->{'addr'}</tt>");
	}
elsif ($action eq 'unsubscribe') {
	return &text('log_unsubscribe', "<tt>$object</tt>",
				        "<tt>$p->{'addr'}</tt>");
	}
elsif ($text{"log_${action}"}) {
	return &text("log_${action}", "<tt>$object</tt>");
	}
else {
	return undef;
	}
}

