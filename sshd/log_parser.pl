# log_parser.pl
# Functions for parsing this module's logs

do 'sshd-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "host") {
	if ($object eq "*") {
		return $text{"log_${action}_all"};
		}
	else {
		return &text("log_${action}_host",
			     "<tt>".&html_escape($object)."</tt>");
		}
	}
elsif ($action eq "manual") {
	return &text("log_${action}", "<tt>$object</tt>");
	}
else {
	return $text{"log_${action}"};
	}
}

