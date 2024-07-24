# log_parser.pl
# Functions for parsing this module's logs

do 'package-updates-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'repos') {
	return &text('log_'.$action.'_repos', $object);
	}
elsif ($type eq 'repo') {
	return &text('log_'.$action.'_repo',
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($action eq 'update') {
	return &text('log_update', $object);
	}
elsif ($action eq 'schedup') {
	return &text('log_schedup', $object);
	}
elsif ($action eq 'sched') {
	return $text{$object ? 'log_sched' : 'log_unsched'};
	}
elsif ($action eq 'refresh') {
	return $text{'log_refresh'};
	}
else {
	return undef;
	}
}

