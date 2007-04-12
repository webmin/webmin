# log_parser.pl
# Functions for parsing this module's logs

do 'ipfilter-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq "delsel") {
	return &text($type eq "nat" ? 'log_delselnat'
				    : 'log_delsel', $p->{'count'});
	}
elsif ($type eq "rule") {
	return &text("log_${action}_rule".($long ? "_l" : ""),
		     $text{'action_'.$p->{'action'}},
		     &describe_rule($p, 1));
	}
elsif ($type eq "nat") {
	return &text("log_${action}_nat".($long ? "_l" : ""),
		     $text{'action_'.$p->{'action'}},
		     &describe_from($p, 1),
		     &describe_to($p, 1));
	}
elsif ($type eq "host" || $type eq "group") {
        return &text("log_${action}_${type}", "<tt>$object</tt>");
        }
else {
	return $text{"log_$action"};
	}
}

