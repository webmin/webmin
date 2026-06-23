# Supplies the System Logs module with a journalctl-backed log source.

use strict;
use warnings;

require 'systemd-lib.pl'; ## no critic

our %text;

# syslog_getlogs()
# Returns a journalctl log source if journalctl is installed.
sub syslog_getlogs
{
if (has_command("journalctl")) {
	# Let the System Logs module run journalctl when rendering entries.
	return ( { 'cmd' => "journalctl -n 1000",
		   'desc' => $text{'syslog_journalctl'},
		   'active' => 1, } );
	}
else {
	# Without journalctl there is no useful systemd log source to add.
	return ( );
	}
}
