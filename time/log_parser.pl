# log_parser.pl
# Functions for parsing this module's logs

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
do 'time-lib.pl';
our (%text);

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq 'remote') {
	my $server = "<tt>".&html_escape($p->{'timeserver'})."</tt>";
	# Older sync entries may have no recorded time.
	if ($long && $object =~ /\A-?[0-9]+\z/) {
		my $tm = localtime($object);
		return &text("log_remote_${type}_l", "<i>$tm</i>", $server);
		}
	return &text("log_remote_${type}", "", $server);
	}
elsif ($action eq 'set') {
	my $tm = localtime($object);
	return &text("log_set_${type}", "<i>$tm</i>");
	}
elsif ($action eq 'sync') {
	return $text{'log_sync'};
	}
elsif ($action eq 'sync_s') {
	return $text{'log_sync_s'};
	}
elsif ($action eq 'timezone') {
	return &text('log_timezone', &html_escape($object));
	}
else {
	return undef;
	}
}

