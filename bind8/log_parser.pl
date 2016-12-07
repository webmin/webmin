# log_parser.pl
# Functions for parsing this module's logs

do 'bind8-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'record') {
	if ($p->{'type'} eq 'PTR') {
		return &text("log_${action}_record", $text{"type_$p->{'type'}"},
			     "<tt>".&arpa_to_ip($p->{'name'})."</tt>",
			     "<tt>".&arpa_to_ip($object)."</tt>");
		}
	else {
		$p->{'name'} =~ s/\.$object\.*$//;
		if (($action eq "modify" || $action eq "create") &&
		    $p->{'newvalues'}) {
			return &text("log_${action}_record_v",
				     $text{"type_$p->{'type'}"},
				     "<tt>".&html_escape($p->{'name'})."</tt>",
				     "<tt>".&html_escape($object)."</tt>",
				     "<tt>".&html_escape($p->{'newvalues'})."</tt>");
			}
		else {
			return &text("log_${action}_record",
				     $text{"type_$p->{'type'}"},
				     "<tt>".&html_escape($p->{'name'})."</tt>",
				     "<tt>".&html_escape($object)."</tt>");
			}
		}
	}
elsif ($type eq 'recs') {
	return &text("log_${action}_recs", $object);
	}
elsif ($type eq 'zones') {
	return &text("log_${action}_zones", $object);
	}
elsif ($type eq "host" || $type eq "group") {
	return &text("log_${action}_${type}", "<tt>$object</tt>");
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
elsif ($action eq 'zonekeyon' || $action eq 'zonekeyoff' || $action eq 'sign') {
	return &text("log_".$action, "<tt>$object</tt>");
	}
elsif ($action eq 'opts') {
	return &text("log_opts", "<tt>$object</tt>");
	}
elsif ($action eq 'view') {
	return &text("log_review", "<tt>$object</tt>");
	}
elsif ($action eq 'move') {
	return &text("log_move", "<tt>$object</tt>");
	}
elsif ($action eq 'apply' && $type && $type ne '-') {
	return &text("log_apply2", "<tt>$type</tt>");
	}
elsif ($action eq 'freeze' || $action eq 'thaw') {
	return &text("log_".$action, "<tt>$type</tt>");
	}
elsif ($action eq 'mass') {
	return &text("log_mass", $object);
	}
elsif ($action eq 'manual') {
	return &text("log_manual", "<tt>$object</tt>");
	}
elsif ($text{"log_${action}"}) {
	return $text{"log_${action}"};
	}
else {
	return undef;
	}
}

