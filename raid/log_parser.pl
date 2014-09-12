# log_parser.pl
# Functions for parsing this module's logs

do 'raid-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
$object = &html_escape($object);
if ($action eq 'create') {
	return &text('log_create', $p->{'level'} eq 'linear' ? $text{$p->{'level'}} : $text{'raid'.$p->{'level'}}, "<tt>$object</tt>");
	}
elsif ($action eq 'stop') {
	return &text('log_stop', "<tt>$object</tt>");
	}
elsif ($action eq 'start') {
	return &text('log_start', "<tt>$object</tt>");
	}
elsif ($action eq 'delete') {
	return &text('log_delete', "<tt>$object</tt>");
	}
elsif ($action eq 'mkfs') {
	return &text('log_mkfs', "<tt>$p->{'fs'}</tt>", "<tt>$object</tt>");
	}
elsif ($action eq 'add') {
	return &text('log_add', "<tt>$object</tt>", "<tt>$p->{'disk'}</tt>");
	}
elsif ($action eq 'remove') {
	return &text('log_remove', "<tt>$object</tt>", "<tt>$p->{'disk'}</tt>");
	}
elsif ($action eq 'replace') {
	return &text('log_replace', "<tt>$object</tt>", "<tt>$p->{'disk'}</tt>", "<tt>$p->{'disk2'}</tt>");
	}
elsif ($action eq 'grow') {
	return &text('log_grow', "<tt>$object</tt>", "<tt>$p->{'disk'}</tt>");
	}
elsif ($action eq 'convert_to_raid6') {
	return &text('log_convert_to_raid6', "<tt>$object</tt>", "<tt>$p->{'disk'}</tt>");
	}
elsif ($action eq 'convert_to_raid5') {
	return &text('log_convert_to_raid5', "<tt>$object</tt>", "<tt>$p->{'disk'}</tt>");
	}
else {
	return undef;
	}
}

