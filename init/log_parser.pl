# log_parser.pl
# Functions for parsing this module's logs

do 'init-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;

# This parser returns HTML fragments, so escape log values before wrapping them
# in UI tags or translated strings.
if ($type eq 'systemd-user' &&
    ($action eq 'modify' || $action eq 'create' || $action eq 'delete' ||
     $action eq 'status' || $action eq 'logs' ||
     $action eq 'massstart' || $action eq 'massstop' ||
     $action eq 'massrestart' || $action eq 'massenable' ||
     $action eq 'massdisable' || $action eq 'linger')) {
	if ($action eq 'linger') {
		return &text('log_user_linger',
			     &ui_tag('tt', &html_escape($p->{'user'})),
			     $p->{'enabled'} ? $text{'yes'} : $text{'no'});
		}
	return &text('log_user_'.$action,
		join(", ", map { &ui_tag('tt', &html_escape($_)) }
		      split(/\s+/, $object)),
		&ui_tag('tt', &html_escape($p->{'user'})));
	}

# Existing system-unit messages retain their historical wording, with values
# escaped before they are wrapped for HTML.
elsif ($action eq 'modify') {
	if ($p->{'old'} ne $p->{'name'}) {
		return &text('log_rename',
			     &ui_tag('tt', &html_escape($p->{'old'})),
			     &ui_tag('tt', &html_escape($p->{'name'})));
		}
	else {
		return &text('log_modify',
			     &ui_tag('tt', &html_escape($object)));
		}
	}
elsif ($action eq 'create') {
	return &text('log_create', &ui_tag('tt', &html_escape($object)));
	}
elsif ($action eq 'delete') {
	return &text('log_delete', &ui_tag('tt', &html_escape($object)));
	}
elsif ($type eq 'action') {
	return &text('log_'.$action, &ui_tag('tt', &html_escape($object)));
	}
elsif ($action eq 'reboot') {
	return $text{'log_reboot'};
	}
elsif ($action eq 'shutdown') {
	return $text{'log_shutdown'};
	}
elsif ($action eq 'local') {
	return $text{'log_local'};
	}
elsif ($action eq 'bootup') {
	return &text('log_bootup',
		     join(", ", map { &ui_tag('tt', &html_escape($_)) }
			  keys %$p));
	}
elsif ($type eq 'systemd' && ($action eq 'status' || $action eq 'logs')) {
	return &text('log_'.$action,
		join(", ", map { &ui_tag('tt', &html_escape($_)) }
		      split(/\s+/, $object)));
	}

# Other mass-action log types predate user units and keep the legacy formatting.
elsif ($action eq 'massstart' || $action eq 'massstop' ||
       $action eq 'massrestart' ||
       $action eq 'massenable' || $action eq 'massdisable') {
	return &text('log_'.$action,
		     join(", ", map { &ui_tag('tt', &html_escape($_)) }
			  split(/\s+/, $object)));
	}
elsif ($action eq 'telinit') {
	return &text('log_telinit', &html_escape($object));
	}
else {
	return;
	}
}
