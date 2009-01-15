# freebsd-lib.pl
# Functions for freebsd format last output

# passfiles_type()
# Returns 0 for old-style passwords (/etc/passwd only), 1 for FreeBSD-style
# (/etc/master.passwd) and 2 for SysV (/etc/passwd & /etc/shadow)
sub passfiles_type
{
return 1;
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

# use_md5()
# Returns 1 if pam is set up to use MD5 encryption
sub use_md5
{
local $md5 = 0;
&open_readfile(CONF, "/etc/login.conf");
while(<CONF>) {
	s/\r|\n//g;
	s/#.*$//;
	$md5 = 1 if (/passwd_format\s*=\s*md5/);
	}
close(CONF);
&open_readfile(CONF, "/etc/auth.conf");
while(<CONF>) {
	s/\r|\n//g;
	s/#.*$//;
	$md5 = 1 if (/crypt_default\s*=\s*md5/);
	}
close(CONF);
return $md5;
}

1;

