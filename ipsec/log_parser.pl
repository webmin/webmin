# log_parser.pl
# Functions for parsing this module's logs

do 'ipsec-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($type eq "conn") {
	return &text('log_'.$action.'_conn', "<tt>$object</tt>");
	}
elsif ($type eq "secret") {
	if ($p->{'name'}) {
		return &text('log_'.$action.'_secret', "<tt>$p->{'name'}</tt>");
		}
	else {
		return &text('log_'.$action.'_secret_nn');
		}
	}
elsif ($action eq "up") {
	return &text('log_up', "<tt>$object</tt>");
	}
elsif ($action eq "policy") {
	return &text('log_policy', $text{'policy_desc_'.$object} ||
				   &text('policy_desc', $object));
	}
else {
	return $text{'log_'.$action};
	}
}

