# log_parser.pl
# Functions for parsing this module's logs

do 'itsecur-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "rule") {
	local $source = &group_names($p->{'source'});
	local $dest = &group_names($p->{'dest'});
	return &text('log_'.$action.'_'.$type, $source, $dest);
	}
elsif ($type eq "service" || $type eq "group" || $type eq "user" ||
       $type eq "time" || $type eq "sep") {
	return &text('log_'.$action.'_'.$type,
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq "nat" || $type eq "pat" || $type eq "spoof") {
	return $text{'log_'.$action.'_'.$type};
	}
elsif ($action eq "backup" || $action eq "restore") {
	return $object ? &text('log_'.$action, "<tt>".&html_escape($object)."</tt>") : $text{'log_'.$action.'_file'};
	}
elsif ($action eq "import") {
	return $text{'log_import_'.$type};
	}
elsif ($type eq "rules") {
	if (defined($p->{'enabled'})) {
		return &text('log_oldenable_rules',
			     $p->{'enabled'}, $p->{'disabled'});
		}
	else {
		return &text('log_'.$action.'_rules', $p->{'count'});
		}
	}
else {
	return $text{'log_'.$action};
	}
}

