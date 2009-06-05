
do 'raid-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'view_raid.cgi') {
	my $conf = &get_raidtab();
	return @$conf ? 'index='.$conf->[0]->{'index'} : 'none';
	}
elsif ($cgi eq 'raid_form.cgi') {
	return 'level=0';
	}
return undef;
}
