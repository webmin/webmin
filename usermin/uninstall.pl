# uninstall.pl
# Called when webmin is uninstalled

require 'usermin-lib.pl';

sub module_uninstall
{
&foreign_require("cron", "cron-lib.pl");
my $cron_cmd = "$module_config_directory/update.pl";
foreach my $j (&cron::list_cron_jobs()) {
	if ($j->{'user'} eq 'root' &&
	    $j->{'command'} eq $cron_cmd) {
		&cron::delete_cron_job($j);
		}
	}
}

1;

