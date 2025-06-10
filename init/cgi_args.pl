
do 'init-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_action.cgi') {
	# Link to init script
	return 'none' if ($init_mode ne 'init');
	my @iacts = &list_actions();
	my @ac = split(/\s+/, $iacts[0]);
	return '0+'.$ac[0];
	}
elsif ($cgi eq 'edit_hostconfig.cgi') {
	return 'none' if ($init_mode ne 'osx');
	my @hconf_set = &hostconfig_settings();
	return '0+'.$hconf_set[0][0];
	}
elsif ($cgi eq 'edit_rc.cgi') {
	return 'none' if ($init_mode ne 'rc');
	my @rcs = &list_rc_scripts();
	return 'name='.&urlize($rcs[0]->{'name'});
	}
elsif ($cgi eq 'reboot.cgi' || $cgi eq 'shutdown.cgi') {
	# Link *without* confirm parameter
	return '';
	}
return undef;
}
