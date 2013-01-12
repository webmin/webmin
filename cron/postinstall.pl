
require 'cron-lib.pl';

sub module_install
{
# Create a Webmin cron job to delete old files in /tmp/.webmin
eval {
	$main::error_must_die = 1;
	&foreign_require("webmincron");
	local $cron = { 'module' => $module_name,
		        'func' => 'cleanup_temp_files',
			'interval' => 3600 };
	&webmincron::create_webmin_cron($cron, $temp_delete_cmd);
	};
if ($@) {
	print STDERR "Failed to setup /tmp cleanup cron job : $@\n";
	}
}


