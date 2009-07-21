
do 'dhcpd-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_group.cgi' || $cgi eq 'edit_host.cgi' ||
    $cgi eq 'edit_subnet.cgi' || $cgi eq 'edit_shared.cgi' ||
    $cgi eq 'edit_keys.cgi' || $cgi eq 'edit_zones.cgi') {
	# Creating new one
	return 'new=1';
	}
elsif ($cgi eq 'edit_options.cgi') {
	# Global options
	return '';
	}
return undef;
}
