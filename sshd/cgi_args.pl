
do 'sshd-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_keys.cgi') {
	# Allows no args
	return undef;
	}
elsif ($cgi eq 'edit_host.cgi') {
	# First client host
	my $hconf = &get_client_config();
	return @$hconf ? 'idx=0' : 'new=1';
	}
return undef;
}
