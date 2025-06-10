
do 'inetd-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_serv.cgi' || $cgi eq 'edit_rpc.cgi') {
	return 'new=1';
	}
return undef;
}
