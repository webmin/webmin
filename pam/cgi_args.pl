
do 'pam-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my @pams = &get_pam_config();
if ($cgi eq 'edit_pam.cgi') {
	return @pams ? 'idx='.$pams[0]->{'index'} : 'new=1';
	}
elsif ($cgi eq 'edit_mod.cgi') {
	return @pams ? 'idx='.$pams[0]->{'index'}.'&midx=0' : 'new=1';
	}
return undef;
}
