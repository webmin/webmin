# postgresql-monitor.pl
# Monitor the PostgreSQL server on this host

# Check if postgresql is running
sub get_postgresql_status
{
return { 'up' => -1 } if (!&foreign_check($_[1]));
&foreign_require($_[1], "postgresql-lib.pl");
local %pconfig = &foreign_config($_[1]);
return { 'up' => -1 } if (!-x $pconfig{'psql'});
local $r = &foreign_call($_[1], "is_postgresql_running");
return { 'up' => $r ? 1 : 0 };
}

sub parse_postgresql_dialog
{
&depends_check($_[0], "postgresql");
}

