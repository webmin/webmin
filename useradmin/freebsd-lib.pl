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

# open_last_command(handle, user, [max])
sub open_last_command
{
my ($fh, $user, $max) = @_;
my $quser = quotemeta($user);
$max = " -n $max" if ($max);
open($fh, "(last -w$max $quser || last$max $quser) |");
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
	if ($line =~ /^(\S+)\s+(\S+)\s+(\S+)?\s+(\S+\s+\S+\s+\d+\s+\d+:\d+)\s+\-\s+(\S+)\s+\((.*?\d+:\d+.*?)\)/) {
		# root       pts/0    10.211.55.2            Tue Nov 22 21:06 - 23:16  (02:10:00)
		# root       pts/1    10.211.55.2            Wed Jun 29 13:13 - shutdown (7+00:01:20)
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
	$md5 = 2 if (/passwd_format\s*=\s*blowfish/);
	$md5 = 3 if (/passwd_format\s*=\s*sha512/);
	$md5 = 4 if (/passwd_format\s*=\s*yescrypt/);
	}
close(CONF);
&open_readfile(CONF, "/etc/auth.conf");
while(<CONF>) {
	s/\r|\n//g;
	s/#.*$//;
	$md5 = 1 if (/crypt_default\s*=\s*md5/);
	$md5 = 2 if (/crypt_default\s*=\s*blowfish/);
	$md5 = 3 if (/crypt_default\s*=\s*sha512/);
	$md5 = 4 if (/crypt_default\s*=\s*yescrypt/);
	}
close(CONF);
return $md5;
}

1;

