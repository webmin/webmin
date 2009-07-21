# log_parser.pl
# Functions for parsing this module's logs

do 'usermin-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "restrict") {
	return &text("log_restrict_$action",
		$object eq "*" ? $text{'log_all'} :
		$object =~ /^\@(.*)$/ ? &text('log_group', "<tt>$1</tt>")
				      : "<tt>$object</tt>");
	}
elsif ($action eq 'install') {
	return &text('log_install', "<i>$p->{'desc'}</i>");
	}
elsif ($action eq 'tinstall') {
	return &text('log_tinstall', "<i>$p->{'desc'}</i>");
	}
elsif ($action eq 'clone') {
	return &text('log_clone', "<i>$p->{'desc'}</i>",
				  "<i>$p->{'dstdesc'}</i>");
	}
elsif ($action eq 'delete') {
	return &text('log_delete', "<i>$p->{'desc'}</i>");
	}
elsif ($action eq 'upgrade') {
	return &text('log_upgrade', $p->{'version'});
	}
elsif ($action eq 'uinstall') {
	return &text('log_uinstall', $p->{'version'});
	}
elsif ($action eq 'theme') {
	return $p->{'theme'} ? &text('log_theme', "<tt>$p->{'theme'}</tt>")
			     : $text{'log_theme_def'};
	}
elsif ($action eq "config") {
	return &text('log_config', "<tt>$p->{'mod'}</tt>");
	}
elsif ($action eq "uconfig") {
	return &text('log_uconfig', "<tt>$p->{'mod'}</tt>");
	}
elsif ($action eq 'switch') {
	return &text('log_switch', "<tt>$object</tt>");
	}
elsif ($text{"log_$action"}) {
	return $text{"log_$action"};
	}
else {
	return undef;
	}
}

