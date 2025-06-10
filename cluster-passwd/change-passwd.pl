#!/usr/local/bin/perl
# change-passwd.pl
# Changes a user's password on all cluster servers. Also changes
# the password in other modules.

$no_acl_check++;
$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
if ($0 =~ /^(.*\/)[^\/]+$/) {
	chdir($1);
	}
chop($pwd = `pwd`);
$0 = "$pwd/change-passwd.pl";
do './cluster-passwd-lib.pl';

if ($ARGV[0] eq "--old" || $ARGV[0] eq "-old") {
	$askold = 1;
	shift(@ARGV);
	}
@ARGV == 1 || &errordie("usage: change-passwd.pl [-old] <username>");
if (&foreign_installed("cluster-useradmin") != 1) {
	&errordie("Cluster Users and Groups module is not available");
	}

# Find the user
@hosts = &cluster_useradmin::list_useradmin_hosts();
@ulist = &get_all_users(\@hosts);
($user) = grep { $_->{'user'} eq $ARGV[0] } @ulist;
$user || &errordie("User $ARGV[0] does not exist");

$| = 1;
if ($askold) {
	# Ask for the old password
	print "(current) UNIX password: ";
	$old = <STDIN>;
	$old =~ s/\r|\n//g;
	&unix_crypt($old, $user->{'pass'}) eq $user->{'pass'} ||
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

# Do it on all servers
&modify_on_hosts(\@hosts, $user->{'user'}, $pass, 1, \&print_func);

# All done
exit(0);

sub errordie
{
print STDERR @_,"\n";
exit(1);
}

# print_func(mode, message)
sub print_func
{
if ($_[0] == -1) {
	print "$_[1]\n\n";
	$indent = "    ";
	}
elsif ($_[0] == -2) {
	print "$indent$_[1]\n";
	}
elsif ($_[0] == -3) {
	print "$indent$_[1]\n\n";
	}
elsif ($_[0] == -4) {
	$indent = "";
	print "\n";
	}
elsif ($_[0] > 0) {
	print "$indent$_[1]\n\n";
	$indent = "";
	}
}
