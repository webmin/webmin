
do 'cpan-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_mod.cgi') {
	return 'idx=0&midx=0';
	}
return undef;
}
