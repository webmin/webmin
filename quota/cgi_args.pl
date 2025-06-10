
do 'quota-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my ($fs) = grep { $_->[5] && &can_edit_filesys($_->[0]) } &list_filesystems();
my @uinfo = getpwnam($remote_user);
if ($cgi eq 'list_users.cgi' || $cgi eq 'list_groups.cgi') {
	# First filesystem
	return $fs ? 'dir='.&urlize($fs->[0]) : 'none';
	}
elsif ($cgi eq 'edit_user_quota.cgi') {
	# First editable user
	my $n = &filesystem_users($fs->[0]);
	return $n ? 'filesys='.&urlize($fs->[0]).
		    '&user='.&urlize($user{0,'user'}) : 'none';
	}
elsif ($cgi eq 'edit_group_quota.cgi') {
	# First editable group
	my $n = &filesystem_groups($fs->[0]);
	return $n ? 'filesys='.&urlize($fs->[0]).
		    '&group='.&urlize($group{0,'group'}) : 'none';
	}
elsif ($cgi eq 'user_filesys.cgi' || $cgi eq 'copy_user_form.cgi') {
	return scalar(@uinfo) ?
		'user='.&urlize($remote_user) : 'user=root';
	}
elsif ($cgi eq 'group_filesys.cgi' || $cgi eq 'copy_group_form.cgi') {
	if (scalar(@uinfo)) {
		my @ginfo = getgrgid($uinfo[3]);
		return 'group='.&urlize($ginfo[0]) if (scalar(@ginfo));
		}
	return 'group=bin';
	}
return undef;
}
