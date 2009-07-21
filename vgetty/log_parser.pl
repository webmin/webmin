# log_parser.pl
# Functions for parsing this module's logs

do 'vgetty-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "vgetty") {
	return &text("log_vgetty_$action",
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($action eq "delete") {
	return &text("log_delete$type", scalar(split(/\0/, $p->{'del'})));
	}
elsif ($action eq "move") {
	return &text("log_move", scalar(split(/\0/, $p->{'del'})));
	}
elsif ($action eq "upload") {
	return &text("log_upload", "<tt>".&html_escape($p->{'file'})."</tt>");
	}
else {
	return $text{"log_$action"};
	}
}

