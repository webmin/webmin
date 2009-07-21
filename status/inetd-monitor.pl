# inetd-monitor.pl
# Monitor inetd on this host

sub get_inetd_status
{
return { 'up' => -1 } if (!&foreign_check("proc"));
&foreign_require("proc", "proc-lib.pl");
local %iconfig = &foreign_config($_[1]);
return { 'up' => -1 } if (!-r $iconfig{'inetd_conf_file'});
return { 'up' => &find_named_process('inetd$') ? 1 : 0 };
}

sub parse_inetd_dialog
{
&depends_check($_[0], "inetd", "proc");
}

1;

