# Monitorthe firewalld server on this host

sub get_firewalld_status
{
my ($mon, $mod) = @_;
return { 'up' => -1 } if (!&foreign_installed("firewalld"));
&foreign_require("firewalld");
&foreign_require("init");
my $ok = &init::status_action($firewalld::config{'init_name'});
return { 'up' => $ok };
}
