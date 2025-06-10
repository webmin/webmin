# samba-monitor.pl
# Monitor the samba servers on this host

# Check if samba is running
sub get_samba_status
{
return { 'up' => -1 } if (!&foreign_check($_[1]));
&foreign_require($_[1], "samba-lib.pl");
local %sconfig = &foreign_config($_[1]);
return { 'up' => -1 } if (!-x $sconfig{'samba_server'});
local $r = &foreign_call($_[1], "is_samba_running");
return { 'up' => $r ? 1 : 0 };
}

sub parse_samba_dialog
{
&depends_check($_[0], "samba");
}

1;

