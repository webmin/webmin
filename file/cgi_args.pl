
do 'file-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
# None of this module's CGIs can be linked to
return $cgi eq 'index.cgi' ? '' : 'none';
}
