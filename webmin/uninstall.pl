# uninstall.pl
# Called when webmin is uninstalled

require 'webmin-lib.pl';

sub module_uninstall
{
# Remove the update cron job, if enabled
if ($config{'update'}) {
	&foreign_require("cron");
	$cron_cmd = "$module_config_directory/update.pl";
	foreach $j (&cron::list_cron_jobs()) {
		if ($j->{'user'} eq 'root' &&
		    $j->{'command'} eq $cron_cmd) {
			&cron::delete_cron_job($j);
			}
		}
	}

# Remove the link from /usr/sbin/webmin
my $bindir = "/usr/sbin";
my $lnk = $bindir."/webmin";
if (-l $lnk) {
	unlink($lnk);
	}
}

1;

