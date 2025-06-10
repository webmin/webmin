
do 'man-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'search.cgi') {
	return 'for=ssh&type=1&section=man';
	}
elsif ($cgi eq 'view_man.cgi') {
	return 'page=ssh&sec=1';
	}
return undef;
}
