# log_parser.pl
# Functions for parsing this module's logs

do 'software-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq 'install') {
	return &text("log_install_package", "<tt>$object</tt>");
	}
elsif ($action eq 'apt') {
	local @p = split(/\0/, $p->{'packages'});
	return &text($long || @p < 2 ? "log_${type}_apt_l" : "log_${type}_apt",
		     "<tt>".join(" ",@p)."</tt>", scalar(@p));
	}
elsif ($action eq 'rhn') {
	local @p = split(/\0/, $p->{'packages'});
	return &text($long || @p < 2 ? "log_${type}_rhn_l" : "log_${type}_rhn",
		     "<tt>".join(" ",@p)."</tt>", scalar(@p));
	}
elsif ($action eq "yum") {
	local @p = split(/\0/, $p->{'packages'});
	return &text($long || @p < 2 ? "log_${type}_yum_l" : "log_${type}_yum",
		     "<tt>".join(" ",@p)."</tt>", scalar(@p));
	}
elsif ($action eq "urpmi") {
	return $text{'log_urpmi_'.$type};
	}
elsif ($action eq 'delete') {
	return &text('log_delete', "<tt>$object</tt>");
	}
elsif ($action eq 'deletes') {
	local @p = split(/\0/, $p->{'packs'});
	if ($long) {
		return &text('log_deletes_l', "<tt>".join(" ", @p)."</tt>");
		}
	else {
		return &text('log_deletes', scalar(@p));
		}
	}
else {
	return undef;
	}
}

