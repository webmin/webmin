# uninstall.pl
# Called when webmin is uninstalled

require 'webmin-lib.pl';

sub module_uninstall
{
if ($config{'update'}) {
	&foreign_require("cron", "cron-lib.pl");
	$cron_cmd = "$module_config_directory/update.pl";
	foreach $j (&cron::list_cron_jobs()) {
		if ($j->{'user'} eq 'root' &&
		    $j->{'command'} eq $cron_cmd) {
			&cron::delete_cron_job($j);
			}
		}
	}
}

1;

