# log_parser.pl
# Functions for parsing this module's logs

do 'ipfw-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($type eq "rule") {
	return &text("log_${action}_rule".($long ? "_l" : ""),
		     $text{'action_'.$object},
		     &describe_rule($p, 1));
	}
elsif ($action eq "delsel") {
	return &text('log_delsel', $p->{'count'});
	}
else {
	return $text{"log_$action"};
	}
}

