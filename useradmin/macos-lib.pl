# freebsd-lib.pl
# Functions for freebsd format last output

$netinfo_domain = $config{'netinfo_domain'} || ".";

# Mapping from OSX user properties to Webmin user hash keys
%user_properties_map = (
	'RecordName' => 'user',
	'UniqueID' => 'uid',
	'PrimaryGroupID' => 'gid',
	'RealName' => 'real',
	'NFSHomeDirectory' => 'home',
	'UserShell' => 'shell',
	);

# And to group hash keys
%group_properties_map = (
	'RecordName' => 'group',
	'PrimaryGroupID' => 'gid',
	'GroupMembership' => 'members',
	);

# passfiles_type()
# Returns 6 for macos netinfo user storage, 7 for new directory service
sub passfiles_type
{
if (-x "/usr/bin/nidump") {
	# Old netinfo format users DB
	return 6;
	}
elsif (-x "/usr/bin/dscl") {
	# New directory service DB
	return 7;
	}
else {
	return 0;
	}
}

# groupfiles_type()
# Returns 5 for macos netinfo group storage, 7 for new directory service
sub groupfiles_type
{
if (-x "/usr/bin/nidump") {
	# Old netinfo format groups DB
	return 5;
	}
elsif (-x "/usr/bin/dscl") {
	# New directory service DB
	return 7;
	}
else {
	return 0;
	}
}

# open_last_command(handle, user)
sub open_last_command
{
local ($fh, $user) = @_;
open($fh, "last $user |");
}

# read_last_line(handle)
# Parses a line of output from last into an array of
#  user, tty, host, login, logout, period
sub read_last_line
{
$fh = $_[0];
while(1) {
	chop($line = <$fh>);
	if (!$line) { return (); }
	if ($line =~ /^(reboot|shutdown)/) { next; }
	if ($line =~ /^(\S+)\s+(\S+)\s+(\S+)?\s+(\S+\s+\S+\s+\d+\s+\d+:\d+)\s+\-\s+(\S+)\s+\((\d+:\d+)\)/) {
		return ($1, $2, $3, $4, $5 eq "shutdown" ? "Shutdown" :
					$5 eq "crash" ? "Crash" : $5, $6);
		}
	elsif ($line =~ /^(\S+)\s+(\S+)\s+(\S+)?\s+(\S+\s+\S+\s+\d+\s+\d+:\d+)\s+still/) {
		return ($1, $2, $3, $4);
		}
	}
}

# execute_dscl_command(command, arg, ...)
# Executes some batch command with dscl, and calls error on failure
sub execute_dscl_command
{
local ($cmd, @args) = @_;
local $fullcmd = "dscl '$netinfo_domain' ".quotemeta($cmd);
foreach my $a (@args) {
	$fullcmd .= " ".($a eq '' ? "''" : quotemeta($a));
	}
local $out = &backquote_command("$fullcmd 2>&1 </dev/null");
if ($?) {
	&error("<tt>".&html_escape($fullcmd)."</tt> failed : ".
	       "<tt>".&html_escape($out)."</tt>");
	}
return $out;
}

# get_macos_password_hash(uid)
# Given a user's ID, return the password hash. This is in SHA1 format, and the
# first 4 bytes are the salt
sub get_macos_password_hash
{
local ($uuid) = @_;
return undef if (!$uuid);
local $hashfile = &read_file_contents("/var/db/shadow/hash/$uuid");
if ($hashfile) {
	return substr($hashfile, 169, 48);
	}
return undef;
}

# set_macos_password_hash(uuid, hash)
# Updates the password hash for some OSX user
sub set_macos_password_hash
{
local ($uuid, $pass) = @_;
print STDERR "uuid=$uuid hash=$pass\n";
return 0 if (!$uuid);
local $hashfile = &read_file_contents("/var/db/shadow/hash/$uuid");
if ($hashfile) {
	if (length($pass) > 48) {
		$pass = substr($pass, 0, 48);
		}
	elsif (length($pass) < 48) {
		$pass .= ("0" x (48-length($pass)));
		}
	substr($hashfile, 169, 48) = $pass;
	&open_tempfile(HASHFILE, ">/var/db/shadow/hash/$uuid");
	&print_tempfile(HASHFILE, $hashfile);
	&close_tempfile(HASHFILE);
	return 1;
	}
return 0;
}

1;

