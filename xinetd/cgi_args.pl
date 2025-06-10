
do 'xinetd-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_serv.cgi') {
	my @conf = grep { $_->{'name'} eq 'service' } &get_xinetd_config();
	return @conf ? 'idx='.$conf[0]->{'index'} : 'new=1';
	}
return undef;
}
