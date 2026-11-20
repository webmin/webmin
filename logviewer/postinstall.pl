
require 'logviewer-lib.pl';

# If other logs to view were defined in the syslog module but it isn't usable on this system,
# move them over
sub module_install
{
if (&foreign_check("syslog") && !&foreign_installed("syslog")) {
	&foreign_require("syslog");
	if ($syslog::config{'extras'} && !$config{'extras'}) {
		$config{'extras'} = $syslog::config{'extras'};
		delete($syslog::config{'extras'});
		&lock_file($module_config_file);
		&save_module_config();
		&unlock_file($module_config_file);
		&lock_file($syslog::module_config_file);
		&save_module_config(\%syslog::config, "syslog");
		&unlock_file($syslog::module_config_file);
		}
	}

# Older versions saved zero context lines as 0. An empty value means the
# same, and makes the settings page show it as None.
if ($config{'include_context'} eq '0') {
	$config{'include_context'} = '';
	&lock_file($module_config_file);
	&save_module_config();
	&unlock_file($module_config_file);
	}
}
