# log_parser.pl
# Functions for parsing this module's logs

do 'mailboxes-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq 'delmail') {
	return &text("log_delmail", $p->{'count'}, "<tt>$p->{'from'}</tt>");
	}
elsif ($action eq 'movemail') {
	return &text("log_movemail", $p->{'count'}, "<tt>$p->{'from'}</tt>",
		     "<tt>$p->{'to'}</tt>");
	}
elsif ($action eq 'copymail') {
	return &text("log_copymail", $p->{'count'}, "<tt>$p->{'from'}</tt>",
		     "<tt>$p->{'to'}</tt>");
	}
elsif ($action eq 'send') {
	return &text('log_send', &html_escape(&extract_email($p->{'to'})));
	}
elsif ($action eq 'read') {
	return &text('log_read', &html_escape($object));
	}
else {
	return undef;
	}
}

sub extract_email
{
if ($_[0] =~ /([^<>"' \(\)]+\@[^<>"' \(\)]+)/) {
	return $1;
	}
elsif ($_[0] =~ /<(\S+)>/) {
	return $1;
	}
else {
	return $_[0];
	}
}

