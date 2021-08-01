#!/usr/local/bin/perl
# change-passwd.pl
# Changes a user's password using the Users and Groups module. Also changes
# the password in other modules.

$no_acl_check++;
$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
if ($0 =~ /^(.*\/)[^\/]+$/) {
	chdir($1);
	}
chop($pwd = `pwd`);
$0 = "$pwd/change-passwd.pl";
do './passwd-lib.pl';

if ($ARGV[0] eq "--old" || $ARGV[0] eq "-old") {
	$askold = 1;
	shift(@ARGV);
	}
@ARGV == 1 || &errordie("usage: change-passwd.pl [-old] <username>");
if (&foreign_installed("useradmin") != 1) {
	&errordie("Users and Groups module is not supported on this OS");
	}

# Find the user, either in local password file or LDAP
$user = &find_user($ARGV[0]);
$user || &errordie("User $ARGV[0] does not exist");

$| = 1;
if ($askold) {
	# Ask for the old password
	&foreign_require("useradmin");
	print "(current) UNIX password: ";
	$old = <STDIN>;
	$old =~ s/\r|\n//g;
	&useradmin::validate_password($old, $user->{'pass'}) ||
		&errordie("Old password is incorrect");
	}

# Ask for password
print "New password: ";
$pass = <STDIN>;
$pass =~ s/\r|\n//g;
print "Retype new password: ";
$again = <STDIN>;
$again =~ s/\r|\n//g;
$pass eq $again || &errordie("Passwords don't match");

# Check password sanity
$err = &useradmin::check_password_restrictions($pass, $ARGV[0], $user);
&errordie($err) if ($err);

# Do the change!
&change_password($user, $pass, 1);

# All done
exit(0);

sub errordie
{
print STDERR @_,"\n";
exit(1);
}

