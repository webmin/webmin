
do 'spam-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi =~ /^edit_/) {
	# First allowed file, if any
	return $access{'file'} ? 'file='.&urlize($access{'file'}) : '';
	}
return undef;
}
