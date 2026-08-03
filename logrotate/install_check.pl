
do 'logrotate-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if Logrotate is installed, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not.
sub is_installed
{
# Accept the vendor main config when the optional local override is absent.
my $main = &get_main_config_file();
return 0 if (!-r $main && !-r $config{'sample_conf'});
return 0 if (!&has_command($config{'logrotate'}));
return $_[0] ? 2 : 1;
}

