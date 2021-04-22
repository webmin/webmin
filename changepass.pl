#!/usr/local/bin/perl
# changepass.pl
# Script for the user to change their webmin password

# Get Webmin directory
my $cwd = $0;
$cwd =~ s/(.*)\/.*/$1/;

# Check command line arguments
usage() if (@ARGV != 3);

my ($config, $user, $pass) = @ARGV;
my $status = system("$cwd/bin/webmin passwd --config $config --user $user --pass $pass");
if ($status != 0) {
	if ($! =~ /no such file/i) {
		print "Error: Webmin CLI command cannot be found\n";
		}
	else {
		print "Error: $!\n";		
		}
	}
exit $status;

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
