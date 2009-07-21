# hpux-lib.pl
# Functions for hpux format last output

# passfiles_type()
# Returns 0 for old-style passwords (/etc/passwd only), 1 for FreeBSD-style
# (/etc/master.passwd) and 2 for SysV (/etc/passwd & /etc/shadow)
sub passfiles_type
{
return 0;
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
open($fh, "last -R $user |");
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
	if ($line =~ /system boot/) { next; }
	if ($line =~ /^(\S+)\s+(\S+)\s+(\S+)?\s+(\S+\s+\S+\s+\d+\s+\d+:\d+)\s+\-\s+(\d+:\d+)\s+\((\d+:\d+)\)/) {
		return ($1, $2, $3, $4, $5, $6);
		}
	elsif ($line =~ /^(\S+)\s+(\S+)\s+(\S+)?\s+(\S+\s+\S+\s+\d+\s+\d+:\d+)\s+still/) {
		return ($1, $2, $3, $4);
		}
	}
}

1;

