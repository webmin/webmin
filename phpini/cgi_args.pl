
do 'phpini-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my @files = &list_php_configs();
if ($cgi eq 'list_ini.cgi' || $cgi eq 'edit_manual.cgi' ||
    $cgi =~ /^edit_/) {
	return @files ? 'file='.&urlize($files[0]->[0]) : 'none';
	}
return undef;
}
