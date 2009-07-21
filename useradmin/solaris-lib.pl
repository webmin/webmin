# solaris-lib.pl
# Functions for solaris password file format

# passfiles_type()
# Returns 0 for old-style passwords (/etc/passwd only), 1 for FreeBSD-style
# (/etc/master.passwd) and 2 for SysV (/etc/passwd & /etc/shadow)
sub passfiles_type
{
return &password_file($config{'shadow_file'}) ? 2 : 0;
}

# groupfiles_type()
# Returns 0 for normal group file (/etc/group only) and 2 for shadowed
# (/etc/group and /etc/gshadow)
sub groupfiles_type
{
return 0;
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
local $fh = $_[0];
while(1) {
	chop($line = <$fh>);
	if (!$line) { return (); }
	if ($line =~ /system boot/) { next; }
	if ($line =~ /^(\S+)\s+(\S+)\s+(\S+)?\s+(\S+\s+\S+\s+\d+\s+\d+:\d+)\s+\-\s+(\d+:\d+)\s+\((\d+:\d+)\)/) {
		return ($1, $2, $3, $4, $5, $6);
		}
	elsif ($line =~ /^(\S+)\s+(\S+)\s+(\S+)?\s+(\S+\s+\S+\s+\d+\s+\d+:\d+)\s+still/) {
		return ($1, $2, $3, $4);
		}
	}
}

# logged_in_users()
# Returns a list of hashes containing details of logged-in users
sub logged_in_users
{
local @rv;
open(WHO, "who |");
while(<WHO>) {
	if (/^(\S+)\s+(\S+)\s+(\S+\s+\d+\s+\d+:\d+)\s+(\((\S+)\))?/) {
		push(@rv, { 'user' => $1, 'tty' => $2,
			    'when' => $3, 'from' => $5 });
		}
	}
close(WHO);
return @rv;
}

# use_md5()
# Returns 1 if MD5 encryption should be used, 2 if blowfish
sub use_md5
{
local $lref = &read_file_lines("/etc/security/policy.conf");
local $l;
foreach $l (@$lref) {
	if ($l =~ /^CRYPT_DEFAULT\s*=\s*"([^"]*)"/ ||
	    $l =~ /^CRYPT_DEFAULT\s*=\s*'([^']*)'/ ||
	    $l =~ /^CRYPT_DEFAULT\s*=\s*(\S+)/) {
		return 1 if ($1 eq "1");
		return 2 if ($1 eq "2a");
		}
	}
return 0;
}

1;

