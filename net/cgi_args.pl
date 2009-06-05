
do 'net-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_host.cgi') {
	# Link to first host
	my @hosts = &list_hosts();
	return @hosts ? 'idx='.$hosts[0]->{'index'} : 'new=1';
	}
elsif ($cgi eq 'edit_ipnode.cgi' && $config{'ipnodes_file'}) {
	# Link to first ipnode
	my @ipnodes = &list_ipnodes();
	return @ipnodes ? 'idx='.$ipnodes[0]->{'index'} : 'new=1';
	}
elsif ($cgi eq 'list_routes.cgi' || $cgi eq 'list_ifcs.cgi') {
	# Works, even though it calls ReadParse
	return '';
	}
elsif ($cgi eq 'edit_aifc.cgi') {
	my @act = &active_interfaces();
	return @act ? 'idx='.$act[0]->{'index'} : 'new=1';
	}
elsif ($cgi eq 'edit_bifc.cgi') {
	my @boot = &boot_interfaces();
	return @boot ? 'idx='.$boot[0]->{'index'} : 'new=1';
	}
return undef;
}
