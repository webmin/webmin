# log_parser.pl
# Functions for parsing this module's logs

do 'procmail-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "recipe") {
	local ($t, $a) = &parse_action($p);
	return &text('log_'.$action.'_rec',
		     &text('log_act'.$t, &html_escape($a)));
	}
elsif ($type eq "env") {
	return &text('log_'.$action.'_env', &html_escape($p->{'name'}));
	}
elsif ($type eq "inc") {
	return &text('log_'.$action.'_inc', &html_escape($p->{'include'}));
	}
elsif ($type eq "recipes") {
	return &text('log_'.$action.'_recs', $object);
	}
else {
	return $text{'log_'.$action};
	}
}

