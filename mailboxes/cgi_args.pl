
do 'mailboxes-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my @users = &list_mail_users(1, \&can_user);
if ($cgi eq 'list_mail.cgi') {
	# First allowed user
	return @users ? 'user='.&urlize($users[0]->[0]) : 'none';
	}
elsif ($cgi eq 'view_mail.cgi') {
	# First mail, if any
	return 'none' if (!@users);
	my @folders = &list_user_folders(@{$users[0]});
	my ($f) = grep { &mailbox_folder_size($_, 1) } @folders;
	return $f ? 'user='.&urlize($users[0]->[0]).
		    '&idx=0&folder='.$f->{'index'} : 'none';
	}
return undef;
}
