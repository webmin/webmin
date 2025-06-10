# log_parser.pl
# Functions for parsing this module's logs

do 'qmail-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params, long)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($type eq 'alias') {
	return &text("log_alias_$action",
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'virt') {
	return &text($object ne '-' ? "log_virt_$action" :
		"log_virtall_$action", "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'route') {
	return &text("log_route_$action",
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'assign') {
	local $str = $object =~ /^=(\S*)/ ? $1 :
		     $object =~ /^\+(\S*)/ ? "$1*" : "";
	return &text("log_assign_$action", &html_escape($str));
	}
elsif ($type eq 'aliases' || $type eq 'virts' || $type eq 'routes' ||
       $type eq 'assigns') {
	return &text("log_${action}_${type}", $object);
	}
elsif ($action eq 'delmail') {
	local @d = split(/\0/, $p->{'d'});
	return &text("log_delmail", scalar(@d), "<tt>$p->{'user'}</tt>");
	}
elsif ($action eq 'movemail') {
	local @d = split(/\0/, $p->{'d'});
	local $to = $p->{'move1'} ? $p->{'moveto1'} : $p->{'moveto2'};
	return &text("log_movemail", scalar(@d), "<tt>$p->{'user'}</tt>",
		     "<tt>$to</tt>");
	}
elsif ($action eq 'send') {
        return &text('log_send', &html_escape(&extract_email($p->{'to'})));
        }
else {
	return $text{"log_$action"};
	}
}

