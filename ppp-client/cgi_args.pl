
do 'ppp-client-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit.cgi') {
	my $conf = &get_config();
	return @$conf ? 'idx='.$conf->[0]->{'index'} : 'new=1';
	}
return undef;
}
