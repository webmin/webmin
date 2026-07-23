#!/usr/local/bin/perl
# changepass.pl
# Script for the user to change their webmin password

# Get Webmin directory
my $cwd = $0;
$cwd =~ s/(.*)\/.*/$1/;

# Check command line arguments
usage() if (@ARGV != 3);

my ($config, $user, $pass) = @ARGV;
exec "$cwd/bin/webmin", "passwd", "--webmin-only",
	"--config", $config, "--user", $user, "--pass", $pass;
print STDERR "Error: Failed to execute Webmin CLI command: $!\n";
exit 1;

sub usage
{
print STDERR <<EOF;
usage: changepass.pl <config-dir> <login> <password>

This program allows you to change the password of a user in the Webmin
password file. For example, to change the password of the admin user
to foo, you would run:
  - changepass.pl /etc/webmin admin foo
This assumes that /etc/webmin is the Webmin configuration directory.
EOF
exit 1;
}
