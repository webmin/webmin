
require 'webmin-lib.pl';

sub module_install
{
# Update cache of which module's underlying servers are installed 
&build_installed_modules();

# Pick a random update time
if (!defined($config{'uphour'}) ||
    $config{'uphour'} == 3 && $config{'upmins'} == 0 && !$config{'update'}) {
	&seed_random();
	$config{'uphour'} = int(rand()*24);
	$config{'upmins'} = int(rand()*60);
	&save_module_config();
	}

# Figure out the preferred cipher mode
&lock_file("$config_directory/miniserv.conf");
my %miniserv;
&get_miniserv_config(\%miniserv);
if (!defined($miniserv{'cipher_list_def'})) {
	my $clist = $miniserv{'ssl_cipher_list'};
	my $cmode = !$clist ? 1 :
		    $clist eq $strong_ssl_ciphers ? 2 :
		    $clist eq $pfs_ssl_ciphers ? 3 :
		    0;
	$miniserv{'cipher_list_def'} = $cmode;
	&put_miniserv_config(\%miniserv);
	}
else {
	# XXX set actual ciphers based on mode
	}
&unlock_file("$config_directory/miniserv.conf");
}

