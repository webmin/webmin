
do 'fetchmail-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_poll.cgi' || $cgi eq 'edit_global.cgi') {
	my ($file, $user, @conf);
	if ($config{'config_file'}) {
		# Just one file
		$file = $config{'config_file'};
		}
	else {
		# Many users, pick first one with a config
		setpwent();
		while(@uinfo = getpwent()) {
			my $ufile = "$uinfo[7]/.fetchmailrc";
			if (-s $ufile) {
				@conf = grep { $_->{'poll'} }
					     &parse_config_file($ufile);
				if (@conf) {
					$file = $ufile;
					$user = $uinfo[0];
					last;
					}
				}
			}
		}
	return 'none' if (!$file);
	return 'file='.&urlize($file).'&idx='.$conf[0]->{'index'}.
	       '&user='.&urlize($user);
	}
return undef;
}
