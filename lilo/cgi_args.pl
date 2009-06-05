
do 'lilo-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_image.cgi') {
	my $conf = &get_lilo_conf();
	my @images = ( &find("image", $conf), &find("other", $conf) );
	return @images ? 'idx='.$images[0]->{'index'} : 'new=1';
	}
return undef;
}
