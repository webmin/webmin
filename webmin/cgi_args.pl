
do 'webmin-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi =~ /^edit_/) {
	# No args needed for sure
	return '';
	}
return 'none';
}
