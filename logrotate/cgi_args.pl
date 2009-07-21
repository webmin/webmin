
do 'logrotate-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_log.cgi') {
	my $conf = &get_config();
	my ($l) = grep { $_->{'members'} } @$conf;
	return $l ? 'idx='.$l->{'index'} : 'new=1';
	}
return undef;
}
