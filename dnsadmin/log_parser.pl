# log_parser.pl
# Functions for parsing this module's logs

do 'dns-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'record') {
	if ($p->{'type'} eq 'PTR') {
		return &text("log_${action}_record",$text{"type_$p->{'type'}"},
			     "<tt>".&arpa_to_ip($p->{'name'})."</tt>",
			     "<tt>".&arpa_to_ip($object)."</tt>");
		}
	else {
		$p->{'name'} =~ s/\.$object\.*$//;
		return &text("log_${action}_record", $text{"type_$p->{'type'}"},
			     "<tt>$p->{'name'}</tt>", "<tt>$object</tt>");
		}
	}
elsif ($action eq 'create') {
	return &text("log_${type}", "<tt>$object</tt>");
	}
elsif ($action eq 'delete') {
	return &text("log_delete_${type}", "<tt>$object</tt>");
	}
elsif ($action eq 'text') {
	return &text("log_text", "<tt>$object</tt>");
	}
elsif ($action eq 'soa') {
	return &text("log_soa", "<tt>$object</tt>");
	}
elsif ($action eq 'opts') {
	return &text("log_opts", "<tt>$object</tt>");
	}
elsif ($text{"log_${action}"}) {
	return $text{"log_${action}"};
	}
else {
	return undef;
	}
}

