# log_parser.pl
# Functions for parsing this module's logs

do 'net-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'host') {
	return &text("log_${action}_host", "<tt>$object</tt>");
	}
elsif ($type eq 'ipnode') {
	return &text("log_${action}_ipnode", "<tt>$object</tt>");
	}
elsif ($type eq 'hosts' || $type eq 'ipnodes' ||
       $type eq 'aifcs' || $type eq 'bifcs') {
	return &text("log_${action}_${type}", $object);
	}
elsif ($action eq 'dns') {
	return $text{'log_dns'};
	}
elsif ($action eq 'routes') {
	return $text{'log_routes'};
	}
elsif ($type eq 'aifc' || $type eq 'bifc') {
	return &text("log_${action}_${type}", "<tt>$object</tt>",
		     $p->{'dhcp'} || $p->{'bootp'} ? $text{'log_dyn'} :
		     "<tt>$p->{'address'}</tt>");
	}
elsif ($type eq 'route' && $action eq 'create') {
	if ($object) {
		return &text('log_create_route',
			     "<tt>".&html_escape($object)."</tt>");
		}
	else {
		return &text('log_create_defroute');
		}
	}
elsif ($type eq 'routes' && $action eq 'delete') {
	return &text('log_delete_routes', $object);
	}
else {
	return undef;
	}
}

