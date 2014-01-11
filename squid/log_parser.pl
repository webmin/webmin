# log_parser.pl
# Functions for parsing this module's logs

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
do 'squid-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
$object = &html_escape($object);
if ($type eq 'acl') {
	return &text("log_acl_$action", "<tt>$object</tt>");
	}
elsif ($type eq 'host') {
	return &text("log_host_$action", "<tt>$object</tt>");
	}
elsif ($type eq 'http' || $type eq 'icp' ||
       $type eq 'always' || $type eq 'never' ||
       $type eq 'pool' || $type eq 'delay' ||
       $type eq 'headeracc' || $type eq 'refresh') {
	return &text("log_${type}_${action}",
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'pools' || $type eq 'refreshes' || $type eq 'hosts') {
	return &text("log_${type}_${action}", $object);
	}
elsif ($type eq 'user') {
	return &text("log_user_$action", "<tt>$object</tt>");
	}
elsif ($action eq 'purge') {
	return &text('log_purge', "<tt>".&html_escape($object)."</tt>");
	}
elsif ($text{"log_$action"}) {
	return $text{"log_$action"};
	}
else {
	return undef;
	}
}

