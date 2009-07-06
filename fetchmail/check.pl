#!/usr/local/bin/perl
# check.pl
# Run fetchmail, and send the output somewhere

$no_acl_check++;
$ENV{'REMOTE_USER'} = getpwuid($<);
require './fetchmail-lib.pl';

# Parse command-line args
while(@ARGV > 0) {
	local $a = shift(@ARGV);
	if ($a eq "--mail") {
		$mail = shift(@ARGV);
		}
	elsif ($a eq "--file") {
		$file = shift(@ARGV);
		}
	elsif ($a eq "--output") {
		$output = 1;
		}
	elsif ($a eq "--user") {
		$user = shift(@ARGV);
		}
	elsif ($a eq "--errors") {
		$errors = 1;
		}
	elsif ($a eq "--owner") {
		$owner = 1;
		}
	}

if ($fetchmail_config) {
	# Just run once for a single config file
	&run_fetchmail($fetchmail_config, $user);
	}
else {
	# Run for all users
	setpwent();
	while(@uinfo = getpwent()) {
		next if ($donehome{$uinfo[7]}++);
		@conf = &parse_config_file("$uinfo[7]/.fetchmailrc");
		@conf = grep { $_->{'poll'} } @conf;
		if (@conf) {
			&run_fetchmail("$uinfo[7]/.fetchmailrc", $uinfo[0]);
			}
		}
	endpwent();
	}

# run_fetchmail(config, user)
sub run_fetchmail
{
local ($config, $user) = @_;

# Check if we have anything to do
local @conf = &parse_config_file($config);
@conf = grep { $_->{'poll'} } @conf;
return if (!@conf);

# Build the command
local $cmd = "$config{'fetchmail_path'} -v -f ".quotemeta($config);
if ($config{'mda_command'}) {
	$cmd .= " -m ".quotemeta($config{'mda_command'});
	}
if ($user && $user ne "root") {
	$cmd = &command_as_user($user, 0, $cmd);
	}

# Run it
local $out = &backquote_command("($cmd) 2>&1 </dev/null");
$ex = $? / 256;

# Handle the output
if ($owner) {
	# Force mailing to user
	$mail = $user."\@".&get_system_hostname();
	}
if ($errors && $ex <= 1) {
	# No error occurred, so do nothing
	}
elsif ($file) {
	# Just write to a file
	open(FILE, ">$file");
	print FILE $out;
	close(FILE);
	}
elsif ($mail) {
	# Capture output and email
	$mm = $module_info{'usermin'} ? "mailbox" : "mailboxes";
	if (&foreign_check($mm)) {
		&foreign_require($mm, "$mm-lib.pl");
		&foreign_require($mm, "boxes-lib.pl");
		if ($module_info{'usermin'}) {
			($froms, $doms) =
				&foreign_call($mm, "list_from_addresses");
			$fr = $froms->[0];
			}
		else {
			$fr = &foreign_call($mm, "get_from_address");
			}
		&foreign_call($mm, "send_text_mail", $fr, $mail, undef,
			      $ex <= 1 ? $text{'email_ok'}
				       : $text{'email_failed'},
			      $out);
		}
	else {
		print "$mm module not installed - could not email the following output :\n";
		print $out;
		}
	}
elsif ($output) {
	# Output goes to cron
	print STDERR $out;
	}
else {
	# Just throw away output
	}
}

