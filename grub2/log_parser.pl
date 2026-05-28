# log_parser.pl
# Functions for parsing this module's logs.

use strict;
use warnings;
do 'grub2-lib.pl';

our %text;

# parse_webmin_log(user, script, action, type, object, &params, [long])
# Converts logged information from this module into human-readable form.
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p, $long) = @_;
# Simple module-wide actions do not need an object value.
if ($action eq 'defaults') {
	return $text{'log_defaults'};
	}
if ($action eq 'bls_args') {
	return $text{'log_bls_args'};
	}
if ($action eq 'theme') {
	return $text{'log_theme'};
	}
if ($action eq 'security') {
	return $text{'log_security'};
	}
# Object-bearing actions display paths, selectors, or titles as literals.
if ($action eq 'manual') {
	return &text('log_manual', &log_value($object));
	}
if ($action eq 'custom_create') {
	return &text('log_custom_create', &log_value($object));
	}
if ($action eq 'custom_modify') {
	return &text('log_custom_modify', &log_value($object));
	}
if ($action eq 'custom_move') {
	return &text('log_custom_move', &log_value($object));
	}
if ($action eq 'generate') {
	return &text('log_generate', &log_value($object));
	}
if ($action eq 'install') {
	return &text('log_install', &log_value($object));
	}
if ($action eq 'default') {
	return &text('log_default', &log_value($object));
	}
if ($action eq 'once') {
	return &text('log_once', &log_value($object));
	}
if ($action eq 'custom_delete') {
	return &text('log_custom_delete', $object || 0);
	}
return;
}

# log_value(value)
# Returns a styled inline value for log descriptions.
sub log_value
{
my ($value) = @_;
$value = '' if (!defined($value));
return &ui_tag('tt', &html_escape($value));
}

1;
