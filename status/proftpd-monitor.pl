# proftpd-monitor.pl
# Monitor the ProFTPD server on this host

# Check the PID file to see if proftpd is running
sub get_proftpd_status
{
return { 'up' => -1 } if (!&foreign_check($_[1]));
local %pconfig = &foreign_config($_[1]);
-r $pconfig{'proftpd_path'} || return { 'up' => -1 };
&foreign_require($_[1], "proftpd-lib.pl");
if (&foreign_call($_[1], "get_proftpd_pid")) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_proftpd_dialog
{
&error($text{'proftpd_etype'}) if (&run_from_inetd());
}

sub run_from_inetd
{
local $m = $_[0]->{'clone'} || "proftpd";
&foreign_require($m, "proftpd-lib.pl");
local $conf = &foreign_call($m, "get_config");
local $st = &foreign_call($m, "find_directive", "ServerType", $conf);
return lc($st) eq 'inetd';
}

1;

