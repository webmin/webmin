#!/usr/local/bin/perl
# password_change.cgi
# Actually update a user's password by directly modifying /etc/shadow

$ENV{'MINISERV_INTERNAL'} || die "Can only be called by miniserv.pl";
require './web-lib.pl';
&init_config();
&ReadParse();
&get_miniserv_config(\%miniserv);
$miniserv{'passwd_mode'} == 2 || die "Password changing is not enabled!";
if (!$in{'pam'}) {
	$miniserv{'passwd_cindex'} ne '' && $miniserv{'passwd_mindex'} ne '' || 
		die "Missing password file configuration";
	}

# Validate inputs
$in{'new1'} ne '' || &pass_error($text{'password_enew1'});
$in{'new1'} eq $in{'new2'} || &pass_error($text{'password_enew2'});

if ($in{'pam'}) {
	# Use PAM to make the change..
	eval "use Authen::PAM;";
	if ($@) {
		&pass_error(&text('password_emodpam', $@));
		}

	# Check if the old password is correct
	$service = $miniserv{'pam'} ? $miniserv{'pam'} : "webmin";
	$pamh = new Authen::PAM($service, $in{'user'}, \&pam_check_func);
	$rv = $pamh->pam_authenticate();
	$rv == PAM_SUCCESS() ||
		&pass_error($text{'password_eold'});
	$pamh = undef;

	# Change the password with PAM, in a sub-process. This is needed because
	# the UID must be changed to properly signal to the PAM libraries that
	# the password change is not being done by the root user.
	$temp = &transname();
	$pid = fork();
	@uinfo = getpwnam($in{'user'});
	if (!$pid) {
		($>, $<) = (0, $uinfo[2]);
		$pamh = new Authen::PAM("passwd", $in{'user'}, \&pam_change_func);
		$rv = $pamh->pam_chauthtok();
		open(TEMP, ">$temp");
		print TEMP "$rv\n";
		print TEMP ($messages || $pamh->pam_strerror($rv)),"\n";
		close(TEMP);
		exit(0);
		}
	waitpid($pid, 0);
	open(TEMP, $temp);
	chop($rv = <TEMP>);
	chop($messages = <TEMP>);
	close(TEMP);
	unlink($temp);
	$rv == PAM_SUCCESS || &pass_error(&text('password_epam', $messages));
	$pamh = undef;
	}
else {
	# Directly update password file

	# Read shadow file and find user
	&lock_file($miniserv{'passwd_file'});
	$lref = &read_file_lines($miniserv{'passwd_file'});
	for($i=0; $i<@$lref; $i++) {
		@line = split(/:/, $lref->[$i], -1);
		local $u = $line[$miniserv{'passwd_uindex'}];
		if ($u eq $in{'user'}) {
			$idx = $i;
			last;
			}
		}
	defined($idx) || &pass_error($text{'password_euser'});

	# Validate old password
	&unix_crypt($in{'old'}, $line[$miniserv{'passwd_pindex'}]) eq
		$line[$miniserv{'passwd_pindex'}] ||
			&pass_error($text{'password_eold'});

	# Make sure new password meets restrictions
	if (&foreign_check("changepass")) {
		&foreign_require("changepass", "changepass-lib.pl");
		$err = &changepass::check_password($in{'new1'}, $in{'user'});
		&pass_error($err) if ($err);
		}
	elsif (&foreign_check("useradmin")) {
		&foreign_require("useradmin", "user-lib.pl");
		$err = &useradmin::check_password_restrictions(
				$in{'new1'}, $in{'user'});
		&pass_error($err) if ($err);
		}

	# Set new password and save file
	$salt = chr(int(rand(26))+65) . chr(int(rand(26))+65);
	$line[$miniserv{'passwd_pindex'}] = &unix_crypt($in{'new1'}, $salt);
	$days = int(time()/(24*60*60));
	$line[$miniserv{'passwd_cindex'}] = $days;
	$lref->[$idx] = join(":", @line);
	&flush_file_lines();
	&unlock_file($miniserv{'passwd_file'});
	}

# Show ok page
&header(undef, undef, undef, undef, 1, 1);

print "<center><h3>",&text('password_done', "/"),"</h3></center>\n";

&footer();

sub pass_error
{
&header(undef, undef, undef, undef, 1, 1);
print "<hr>\n";

print "<center><h3>",$text{'password_err'}," : ",@_,"</h3></center>\n";

print "<hr>\n";
&footer();
exit;
}

sub pam_check_func
{
my @res;
while ( @_ ) {
	my $code = shift;
	my $msg = shift;
	my $ans = "";

	$ans = $in{'user'} if ($code == PAM_PROMPT_ECHO_ON());
	$ans = $in{'old'} if ($code == PAM_PROMPT_ECHO_OFF());

	push @res, PAM_SUCCESS();
	push @res, $ans;
	}
push @res, PAM_SUCCESS();
return @res;
}

sub pam_change_func
{
my @res;
while ( @_ ) {
	my $code = shift;
	my $msg = shift;
	my $ans = "";
	$messages = $msg;

	if ($code == PAM_PROMPT_ECHO_ON()) {
		# Assume asking for username
		push @res, PAM_SUCCESS();
		push @res, $in{'user'};
		}
	elsif ($code == PAM_PROMPT_ECHO_OFF()) {
		# Assume asking for a password (old first, then new)
		push @res, PAM_SUCCESS();
		if ($msg =~ /old|current/i) {
			push @res, $in{'old'};
			}
		else {
			push @res, $in{'new1'};
			}
		}
	else {
		# Some message .. ignore it
		push @res, PAM_SUCCESS();
		push @res, undef;
		}
	}
push @res, PAM_SUCCESS();
return @res;
}

