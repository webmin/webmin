
do 'htaccess-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my @dirs = grep { &can_access_dir($_->[0]) } &list_directories();
if ($cgi eq 'edit_dir.cgi') {
	return @dirs ? 'dir='.&urlize($dirs[0]->[0]) : 'new=1';
	}
elsif ($cgi eq 'edit_user.cgi') {
	if (!@dirs) {
		return 'none';
		}
	else {
		my $d = $dirs[0];
		my $users = $d->[2] == 3 ? &list_digest_users($d->[1])
				         : &list_users($d->[1]);
		return @$users ? 'dir='.&urlize($d->[0]).
				 '&idx='.$users->[0]->{'index'}
			       : 'dir='.&urlize($d->[0]).'&new=1';
		}
	}
elsif ($cgi eq 'edit_group.cgi') {
	my ($d) = grep { $_->[4] } @dirs;
	if (!$d) {
		return 'none';
		}
	else {
		my $groups = &list_groups($d->[4]);
		return @$groups ? 'dir='.&urlize($d->[0]).
				  '&idx='.$groups->[0]->{'index'}
			        : 'dir='.&urlize($d->[0]).'&new=1';
		}
	}
return undef;
}
