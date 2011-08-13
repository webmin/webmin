# log_parser.pl
# Functions for parsing this module's logs

do 'firewall-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "rule") {
	return &text("log_${action}_rule", "<tt>$p->{'chain'}</tt>",
					   "<tt>$p->{'table'}</tt>");
	}
elsif ($type eq "chain") {
	return &text("log_${action}_chain", "<tt>$p->{'chain'}</tt>",
					    "<tt>$p->{'table'}</tt>",
					    $p->{'count'});
	}
elsif ($type eq "host" || $type eq "group") {
	return &text("log_${action}_${type}", "<tt>$object</tt>");
	}
elsif ($action eq "openports") {
	return &text('log_openports', join(" ", split(/\0/, $p->{'ports'})));
	}
else {
	return $text{"log_$action"};
	}
}

