# log_parser.pl
# Functions for parsing this module's logs

do 'lilo-lib.pl';
&foreign_require("mount", "mount-lib.pl");

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
local $ll = $long ? "_l" : "";
if ($type eq 'image') {
	return &text("log_${action}_image${ll}", "<tt>$object</tt>",
		     "<tt>".&html_escape($p->{'image'})."</tt>");
	}
elsif ($type eq 'other') {
	local $other = &foreign_call("mount", "device_name", $p->{'other'})
		if ($long);
	return &text("log_${action}_other${ll}", "<tt>$object</tt>", $other);
	}
elsif ($action eq 'apply') {
	return $text{'log_apply'};
	}
elsif ($action eq 'global') {
	return $text{'log_global'};
	}
else {
	return undef;
	}
}

