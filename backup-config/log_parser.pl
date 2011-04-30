# log_parser.pl
# Functions for parsing this module's logs

use strict;
use warnings;
do 'backup-config-lib.pl';
our (%text);

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "backup") {
	my @mods = split(/\s+/, $p->{'mods'});
	return &text('log_'.$action.'_backup', scalar(@mods), &nice_dest($object));
	}
elsif ($action eq "backup" || $action eq "restore") {
	my @mods = split(/\0/, $p->{'mods'});
	return &text('log_'.$action, scalar(@mods), &nice_dest($object));
	}
else {
	return undef;
	}
}

