
do 'ldap-useradmin-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_user.cgi') {
	# Link to first available user
	my @allulist = &list_users();
	my @ulist = &useradmin::list_allowed_users(\%access, \@allulist);
	return @ulist ? "dn=".&urlize($ulist[0]->{'dn'}) : "new=1";
	}
elsif ($cgi eq 'edit_group.cgi') {
	my @allglist = &list_groups();
	my @glist = &useradmin::list_allowed_groups(\%access, \@allglist);
	return @glist ? "dn=".&urlize($glist[0]->{'dn'}) : "new=1";
	}
return undef;
}
