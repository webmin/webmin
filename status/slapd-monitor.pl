# slapd-monitor.pl
# Monitor the openldap server on this host

# Check the PID file to see if slapd is running
sub get_slapd_status
{
return { 'up' => -1 } if (!&foreign_check("ldap-server"));
&foreign_require("ldap-server", "ldap-server-lib.pl");

if (&foreign_call("ldap-server", "is_ldap_server_running")) {
	local $pidfile = &foreign_call("ldap-server", "get_ldap_server_pidfile");
	local @st = stat($pidfile);
	return { 'up' => 1,
		 'desc' => &text('up_since', scalar(localtime($st[9]))) };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_slapd_dialog
{
&depends_check($_[0], "ldap-server");
}

1;

