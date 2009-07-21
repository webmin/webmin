
do 'grub-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_title.cgi') {
	my $conf = &get_menu_config();
	my @titles = &find("title", $conf);
	return @titles ? 'idx='.$titles[0]->{'index'} : 'new=1';
	}
return undef;
}
