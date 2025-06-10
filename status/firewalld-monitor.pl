# Monitorthe firewalld server on this host

sub get_firewalld_status
{
my ($mon, $mod) = @_;
return { 'up' => -1 } if (!&foreign_installed("firewalld"));
&foreign_require("firewalld");
return { 'up' => &firewalld::is_firewalld_running() };
}
