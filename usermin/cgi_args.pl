
do 'usermin-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi =~ /^edit_/ || $cgi eq 'index.cgi') {
	# No args needed for sure
	return '';
	}
return 'none';
}
