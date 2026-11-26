# uninstall.pl
# Called when webmin is uninstalled

require 'webmin-lib.pl';

sub module_uninstall
{
# Remove the link from /usr/local/bin/webmin if it points to this install
my $lnk = "/usr/local/bin/webmin";
if (readlink($lnk) eq $root_directory."/bin/webmin") {
	unlink($lnk);
	}
}

1;

