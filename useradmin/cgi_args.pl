
do 'user-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_user.cgi') {
	# Link to first available user
	my @allulist = &list_users();
	my @ulist = &list_allowed_users(\%access, \@allulist);
	return @ulist ? "num=".&urlize($ulist[0]->{'num'}) : "none";
	}
elsif ($cgi eq 'edit_group.cgi') {
	my @allglist = &list_groups();
	my @glist = &list_allowed_groups(\%access, \@allglist);
	return @glist ? "num=".&urlize($glist[0]->{'num'}) : "none";
	}
return undef;
}
