
do 'cron-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my @jobs = grep { &can_edit_user(\%access, $_->{'user'}) } &list_cron_jobs();
if ($cgi eq 'edit_cron.cgi') {
	my @cmds = grep { !$_->{'name'} } @jobs;
	return @cmds ? 'idx='.$cmds[0]->{'index'} : 'new=1';
	}
elsif ($cgi eq 'edit_env.cgi') {
	my @envs = grep { $_->{'name'} } @jobs;
	return @envs ? 'idx='.$envs[0]->{'index'} : 'new=1';
	}
return undef;
}
