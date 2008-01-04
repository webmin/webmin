#!/usr/local/bin/perl
# changepass.pl
# Script for the user to change their webmin password

# Check command line arguments
usage() if (@ARGV != 3);
($config, $user, $pass) = @ARGV;
if (!-d $config) {
	print STDERR "The config directory $config does not exist\n";
	exit 2;
	}
if (!open(CONF, "$config/miniserv.conf")) {
	print STDERR "Failed to open $config/miniserv.conf : $!\n";
	print STDERR "Maybe $config is not the Webmin config directory.\n";
	exit 3;
	}
while(<CONF>) {
	if (/^([^=]+)=(\S+)/) { $config{$1} = $2; }
	}
close(CONF);

# Update the users file
if (!open(USERS, $config{'userfile'})) {
	print STDERR "Failed to open Webmin users file $config{'userfile'} : $!\n";
	exit 4;
	}
while(<USERS>) {
	s/\r|\n//g;
	local @user = split(/:/, $_);
	if (@user) {
		$users{$user[0]} = \@user;
		push(@users, $user[0]);
		}
	}
close(USERS);
if (!defined($users{$user})) {
	print STDERR "The Webmin user $user does not exist\n";
	print STDERR "The users on your system are: ",join(" ", @users),"\n";
	exit 5;
	}
$salt = substr(time(), 0, 2);
$users{$user}->[1] = crypt($pass, $salt);
if (!open(USERS, "> $config{'userfile'}")) {
	print STDERR "Failed to open Webmin users file $config{'userfile'} : $!\n";
	exit 6;
	}
foreach $v (values %users) {
	print USERS join(":", @$v),"\n";
	}
close(USERS);
print "Updated password of Webmin user $user\n";

# Send a signal to have miniserv reload it's config
if (open(PID, $config{'pidfile'})) {
	<PID> =~ /(\d+)/; $pid = $1;
	close(PID);
	kill('USR1', $pid);
	}

sub usage
{
print STDERR <<EOF;
usage: changepass.pl <config-dir> <login> <password>

This program allows you to change the password of a user in the Webmin
password file. For example, to change the password of the admin user
to foo, you would run:
	changepass.pl /etc/webmin admin foo
This assumes that /etc/webmin is the Webmin configuration directory.
EOF
exit 1;
}

