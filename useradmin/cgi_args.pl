
do 'user-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_user.cgi') {
	# Link to first available user
	my @allulist = &list_users();
	my @ulist = &list_allowed_users(\%access, \@allulist);
	return @ulist ? "user=".&urlize($ulist[0]->{'user'}) : "none";
	}
elsif ($cgi eq 'edit_group.cgi') {
	my @allglist = &list_groups();
	my @glist = &list_allowed_groups(\%access, \@allglist);
	return @glist ? "group=".&urlize($glist[0]->{'group'}) : "none";
	}
return undef;
}
