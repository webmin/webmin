
do 'mailcap-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit.cgi') {
	my @mailcap = &list_mailcap();
	return @mailcap ? 'index='.$mailcap[0]->{'index'} : 'new=1';
	}
return undef;
}
