
do 'ldap-server-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_browser.cgi') {
	# Defaults to top of tree
	return '';
	}
elsif ($cgi eq 'edit_sfile.cgi' || $cgi eq 'view_sfile.cgi') {
	# First schema file, if possible
	my @files = &list_schema_files();
	return @files ? 'file='.&urlize($files[0]->{'file'}) : 'none';
	}
return undef;
}
