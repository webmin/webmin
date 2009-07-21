
do 'acl-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_user.cgi') {
	local ($u) = grep { &can_edit_user($u->{'name'}) }
			  &list_users();
	return $u ? 'user='.&urlize($u->{'name'}) :
	       $access{'create'} ? '' : 'none';
	}
elsif ($cgi eq 'edit_group.cgi') {
	local ($u) = grep { &can_edit_group($u->{'name'}) }
			  &list_groups();
	return $u ? 'group='.&urlize($u->{'name'}) :
	       $access{'groups'} ? '' : 'none';
	}
elsif ($cgi eq 'edit_acl.cgi') {
	local ($u) = grep { &can_edit_user($u->{'name'}) }
			  &list_users();
	if ($u && @{$u->{'modules'}}) {
		return 'user='.&urlize($u->{'name'}).
		       '&mod='.$u->{'modules'}->[0];
		}
	return 'none';
	}
return undef;
}
