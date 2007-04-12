# log_parser.pl
# Functions for parsing this module's logs

do 'cluster-useradmin-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "user" || $type eq "group") {
	return &text("log_${action}_${type}", "<tt>$object</tt>");
	}
elsif ($action eq "add") {
	return &text("log_add_${type}", "<tt>$object</tt>");
	}
else {
	return $text{"log_$action"};
	}
}

