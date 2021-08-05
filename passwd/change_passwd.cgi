#!/usr/local/bin/perl
# Change a user's password knowing the old one. For user only via anonymous
# API calls.

$trust_unknown_referers = 1;
require './passwd-lib.pl';
&ReadParse();
print "Content-type: text/plain\n\n";

# Validate inputs
keys(%in) || &error_exit("Required parameters are 'user' (Unix username), 'old' (Old password) and 'new' (New password)");
my $err = &apply_rate_limit($ENV{'REMOTE_ADDR'});
&error_exit($err) if ($err);
$in{'user'} || &error_exit("Missing user parameter");
$in{'old'} || &error_exit("Missing old parameter");
$in{'new'} || &error_exit("Missing new parameter");
$ENV{'ANONYMOUS_USER'} || &error_exit("Can only be called in anonymous mode");
$ENV{'REQUEST_METHOD'} eq 'POST' ||
	&error_exit("Passwords can only be submitted via POST");
&foreign_installed("useradmin") ||
	&error_exit("Users and Groups module is not supported on this OS");

# Validate user and pass
my $err = &apply_rate_limit($in{'user'});
&error_exit($err) if ($err);
&foreign_require("useradmin");
my $user = &find_user($in{'user'});
$user || &error_exit("User does not exist");
&useradmin::validate_password($in{'old'}, $user->{'pass'}) ||
	&error_exit("Incorrect password");
my $err = &useradmin::check_password_restrictions(
	$in{'new'}, $in{'user'}, $user);
&error_exit("Invalid password : $err") if ($err);

# Do the change
&clear_rate_limit($ENV{'REMOTE_ADDR'});
&clear_rate_limit($in{'user'});
eval {
	local $main::error_must_die = 1;
	&change_password($user, $in{'new'}, 1);
	};
if ($@) {
	&error_exit($@);
	}
else {
	print "OK: Password changed for $in{'user'}\n";
	}

sub error_exit
{
print "FAILED: ",join("", @_),"\n";
exit(0);
}
