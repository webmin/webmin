# freebsd-lib.pl
# Functions for freebsd format last output

$netinfo_domain = $config{'netinfo_domain'} || ".";

# passfiles_type()
# Returns 6 for macos netinfo user storage
sub passfiles_type
{
return 6;
}

# groupfiles_type()
# Returns 5 for  macos netinfo group storage
sub groupfiles_type
{
return 5;
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

1;

