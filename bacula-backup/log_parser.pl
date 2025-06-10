# log_parser.pl
# Functions for parsing this module's logs

do 'bacula-backup-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "client" || $type eq "fileset" || $type eq "schedule" ||
    $type eq "job" || $type eq "pool" || $type eq "storage" ||
    $type eq "device" || $type eq "group" || $type eq "gjob") {
	# Adding, modifying or deleting some object
	return &text('log_'.$action.'_'.$type,
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq "clients" || $type eq "filesets" || $type eq "schedules" ||
    $type eq "jobs" || $type eq "pools" || $type eq "storages" ||
    $type eq "devices" || $type eq "groups" || $type eq "gjobs") {
	# Deleting several
	return &text('log_'.$action.'_'.$type, $object);
	}
else {
	return &text('log_'.$action, "<tt>".&html_escape($object)."</tt>");
	}
}

