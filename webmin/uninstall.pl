# uninstall.pl
# Called when webmin is uninstalled

require 'webmin-lib.pl';

sub module_uninstall
{
# Remove the link from /usr/sbin/webmin
my $bindir = "/usr/sbin";
my $lnk = $bindir."/webmin";
if (-l $lnk) {
	unlink($lnk);
	}
}

1;

