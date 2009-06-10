
do 'dovecot-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi =~ /^edit_/) {
	# All edit_*.cgi files can be linked to
	return '';
	}
return undef;
}
