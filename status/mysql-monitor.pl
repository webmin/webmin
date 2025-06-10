# mysql-monitor.pl
# Monitor the MySQL server on this host

# Check if mysql is running
sub get_mysql_status
{
return { 'up' => -1 } if (!&foreign_check($_[1]));
&foreign_require($_[1], "mysql-lib.pl");
local %mconfig = &foreign_config($_[1]);
return { 'up' => -1 } if (!-x $mconfig{'mysqladmin'});
local $r = &foreign_call($_[1], "is_mysql_running");
return { 'up' => $r ? 1 : 0 };
}

sub parse_mysql_dialog
{
&depends_check($_[0], "mysql");
}

1;

