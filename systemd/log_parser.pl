# log_parser.pl
# Functions for parsing this module's logs

use strict;
use warnings;

require 'systemd-lib.pl'; ## no critic

our %text;

# parse_webmin_log(user, script, action, type, object, params)
# Converts logged information from this module into escaped HTML fragments.
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;

# This parser returns HTML fragments, so escape log values before wrapping them
# in UI tags or translated strings.
if ($type eq 'systemd-user' &&
    ($action eq 'modify' || $action eq 'create' || $action eq 'delete' ||
     $action eq 'override' || $action eq 'deleteoverride' ||
     $action eq 'status' || $action eq 'props' || $action eq 'deps' ||
     $action eq 'logs' ||
     $action eq 'massstart' || $action eq 'massstop' ||
     $action eq 'massrestart' || $action eq 'massenable' ||
     $action eq 'massdisable' || $action eq 'massmask' ||
     $action eq 'massunmask' || $action eq 'massdelete' ||
     $action eq 'linger' ||
     $action eq 'manual' || $action eq 'reload')) {

	# Linger logs describe the user rather than one or more unit names.
	if ($action eq 'linger') {
		return text('log_user_linger',
			     ui_tag('tt', html_escape($p->{'user'})),
			     $p->{'enabled'} ? $text{'yes'} : $text{'no'});
		}
	if ($action eq 'manual') {
		return text('log_user_manual',
			     ui_tag('tt', html_escape($object)),
			     ui_tag('tt', html_escape($p->{'user'})));
		}
	if ($action eq 'reload') {
		return text('log_user_reload',
			     ui_tag('tt', html_escape($p->{'user'})));
		}

	# User-unit actions include both escaped unit names and the owner.
	return text('log_user_'.$action,
		join(", ", map { ui_tag('tt', html_escape($_)) }
		      split(/\s+/, $object)),
		ui_tag('tt', html_escape($p->{'user'})));
	}

# System-unit messages use the same escaping as user units because unit names
# can be shown directly in the Webmin log viewer.
elsif ($type eq 'systemd' && $action eq 'modify') {
	return text('log_modify', ui_tag('tt', html_escape($object)));
	}
elsif ($type eq 'systemd' && $action eq 'create') {
	return text('log_create', ui_tag('tt', html_escape($object)));
	}
elsif ($type eq 'systemd' && $action eq 'delete') {
	return text('log_delete', ui_tag('tt', html_escape($object)));
	}
elsif ($type eq 'systemd' && $action eq 'override') {
	return text('log_override', ui_tag('tt', html_escape($object)));
	}
elsif ($type eq 'systemd' && $action eq 'deleteoverride') {
	return text('log_deleteoverride',
		     ui_tag('tt', html_escape($object)));
	}
elsif ($type eq 'systemd' && $action eq 'manual') {
	return text('log_manual', ui_tag('tt', html_escape($object)));
	}
elsif ($type eq 'systemd' && $action eq 'reload') {
	return $text{'log_reload'};
	}
elsif ($type eq 'systemd' &&
       ($action eq 'status' || $action eq 'props' || $action eq 'deps' ||
        $action eq 'logs')) {
	return text('log_'.$action,
		join(", ", map { ui_tag('tt', html_escape($_)) }
		      split(/\s+/, $object)));
	}

# Mass-action logs contain space-separated unit names.
elsif ($type eq 'systemd' &&
       ($action eq 'massstart' || $action eq 'massstop' ||
       $action eq 'massrestart' ||
       $action eq 'massenable' || $action eq 'massdisable' ||
       $action eq 'massmask' || $action eq 'massunmask')) {
	return text('log_'.$action,
		     join(", ", map { ui_tag('tt', html_escape($_)) }
			  split(/\s+/, $object)));
	}
else {
	# Unknown log records fall back to Webmin's default rendering.
	return;
	}
}
