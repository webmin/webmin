# log_parser.pl
# Human-readable Webmin action log descriptions for Kea DHCP.

use strict;
use warnings;

do 'kea-dhcp-lib.pl';
our %text;

# parse_webmin_log(user, script, action, type, object, &params)
# Converts stored Webmin log tuples into action text shown by the Webmin log UI.
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
$action = "" if (!defined($action));
$type = "" if (!defined($type));

if ($action eq 'start' || $action eq 'stop' || $action eq 'apply') {
	return $text{'log_'.$action};
	}
elsif ($type eq 'config' && $action eq 'modify') {
	return &text('log_modify_config', &kea_log_mono($object));
	}
elsif ($type eq 'global-options' && $action eq 'modify') {
	return &text('log_modify_global_options',
		     &kea_log_protocol_label($object));
	}
elsif ($type eq 'ddns' && $action eq 'modify') {
	return $text{'log_modify_ddns'};
	}
elsif ($type eq 'shared-network') {
	return &text('log_'.$action.'_shared_network',
		     &kea_log_mono($object));
	}
elsif ($type eq 'subnet') {
	return &text('log_'.$action.'_subnet',
		     &kea_log_mono($object));
	}
elsif ($type eq 'objects' && $action eq 'delete') {
	my $key = defined($object) && $object eq '1' ? 'log_delete_object' :
						 'log_delete_objects';
	return &text($key, $object);
	}
return;
}

# kea_log_mono(text)
# Formats a log object as escaped monospace text.
sub kea_log_mono
{
my ($value) = @_;
return &ui_tag('tt', &html_escape(defined($value) ? $value : ""));
}

# kea_log_protocol_label(protocol-key)
# Converts logged dhcp4/dhcp6 keys into user-facing protocol names.
sub kea_log_protocol_label
{
my ($object) = @_;
return $object eq 'dhcp4' ? $text{'tab_dhcp4'} :
       $object eq 'dhcp6' ? $text{'tab_dhcp6'} :
       &kea_log_mono($object);
}

1;
