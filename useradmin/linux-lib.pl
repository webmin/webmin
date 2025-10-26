# linux-lib.pl
# Functions for reading linux format last output

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
return &password_file($config{'gshadow_file'}) ? 2 : 0;
}

# open_last_command(handle, user, [max])
sub open_last_command
{
my ($fh, $user, $max) = @_;
if (&has_command("last")) {
	my $quser = quotemeta($user);
	$max = " -n $max" if ($max);
	open($fh, "(last -F -w$max $quser || last -w$max $quser) |");
	}
else {
	open($fh, "</dev/null");
	}
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
	if ($line =~ /^(\S+)\s+(\S+)\s+(\S+)?\s+(\S+\s+\S+\s+\d+\s+\d+:\d+)\s+\-\s+(\S+)\s+\((\d+:\d+)\)/) {
		# jcameron  pts/0  fudu Thu Feb 22 09:47 - 10:15
		return ($1, $2, $3, $4, $5 eq "down" ? "Shutdown" : $5, $6);
		}
	elsif ($line =~ /^(\S+)\s+(\S+)\s+(\S+)?\s+(\S+\s+\S+\s+\d+\s+\d+:\d+:\d+\s+\d+)\s+\-\s+(\S+\s+\S+\s+\d+\s+\d+:\d+:\d+\s+\d+)\s+\((.*?\d+:\d+)\)/) {
		# jcameron  pts/0  fudu Thu Feb 22 09:47 - 10:15
		# jcameron  pts/0  fudu Sun Feb  4 02:26:28 2024 - Wed Feb  7 18:25:09 2024 (3+15:58)
		return ($1, $2, $3, $4, $5 eq "down" ? "Shutdown" : $5, $6);
		}
	elsif ($line =~ /^(\S+)\s+(\S+)\s+(\S+)?\s+(\S+\s+\S+\s+\d+\s+\d+:\d+)\s+(still|gone)/ ||
	       $line =~ /^(\S+)\s+(\S+)\s+(\S+)?\s+(\S+\s+\S+\s+\d+\s+\d+:\d+:\d+\s+\d+)\s+(still|gone)/) {
		# root  pts/0  fudu  Fri Feb 23 18:46  still logged in
		# root  ftpd10 fudu  Thu Jun 20 11:19  gone - no logout
		# root  pts/0  fudu  Tue Jun 18 23:10:30 2024  still logged in
		return ($1, $2, $3, $4);
		}
	}
}

# os_most_recent_logins()
# Returns hash ref from username to the most recent login as time string
sub os_most_recent_logins
{
my %rv;
&clean_language();
open(LASTLOG, "lastlog |");
while(<LASTLOG>) {
	s/\r|\n//g;
	if (/^(\S+)/) {
		my $user = $1;
		if (/((\S+)\s+(\S+)\s+\d+\s+(\d+):(\d+):(\d+)\s+([\-\+]\d+)\s+(\d+))/) {
			# Have a date to parse
			$rv{$user} = $1;
			}
		else {
			$rv{$user} = undef;
			}
		}
	}
close(LASTLOG);
&reset_environment();
return \%rv;
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
# Returns 1 if pam is set up to use MD5 encryption, 2 for blowfish, 3 for SHA512
sub use_md5
{
if (defined($use_md5_cache)) {
	# Don't re-look this up
	return $use_md5_cache;
	}
local $md5 = 0;
if (&foreign_check("pam")) {
	# Use the PAM module if we can
	&foreign_require("pam", "pam-lib.pl");
	local @conf = &foreign_call("pam", "get_pam_config");
	local ($svc) = grep { $_->{'name'} eq 'passwd' } @conf;
	LOOP:
	foreach my $m (@{$svc->{'mods'}}) {
		if ($m->{'type'} eq 'password') {
			if ($m->{'args'} =~ /md5/) {
				$md5 = 1;
				}
			elsif ($m->{'args'} =~ /yescrypt/) {
				$md5 = 4;
				}
			elsif ($m->{'args'} =~ /sha512/) {
				$md5 = 3;
				}
			elsif ($m->{'args'} =~ /blowfish/) {
				$md5 = 2;
				}
			elsif ($m->{'module'} =~ /pam_stack\.so/ &&
			       $m->{'args'} =~ /service=(\S+)/) {
				# Referred to another service!
				($svc) = grep { $_->{'name'} eq $1 } @conf;
				if ($svc) { goto LOOP }
				else { last; }
				}
                        elsif ($m->{'control'} eq 'include') {
                                # Include another section
                                ($svc) = grep { $_->{'name'} eq $m->{'module'} }
					      @conf;
                                if ($svc) { goto LOOP }
                                else { last; }
                                }
			}
		elsif ($m->{'include'}) {
			# Include another section, with @ syntax
			($svc) = grep { $_->{'name'} eq $m->{'include'} } @conf;
			if ($svc) { goto LOOP }
			else { last; }
			}
		}
	}
if (!$md5 && &open_readfile(PAM, "/etc/pam.d/passwd")) {
	# Otherwise try to check the PAM file directly
	while(<PAM>) {
		s/#.*$//g;
		if (/^password.*md5/) { $md5 = 1; }
		elsif (/^password.*blowfish/) { $md5 = 2; }
		elsif (/^password.*sha512/) { $md5 = 3; }
		elsif (/^password.*yescrypt/) { $md5 = 4; }
		}
	close(PAM);
	}
if (!$md5 && (&open_readfile(PAM, "/etc/pam.d/common-password") ||
	      &open_readfile(PAM, "/etc/pam.d/system-auth"))) {
	# Then try reading common password config file
	while(<PAM>) {
		s/#.*$//g;
		if (/^password.*md5/) { $md5 = 1; }
		elsif (/^password.*blowfish/) { $md5 = 2; }
		elsif (/^password.*sha512/) { $md5 = 3; }
		elsif (/^password.*yescrypt/) { $md5 = 4; }
		}
	close(PAM);
	}
if (&open_readfile(DEFS, "/etc/login.defs")) {
	# The login.defs file is used on debian sometimes
	while(<DEFS>) {
		s/#.*$//g;
		$md5 = 1 if (/MD5_CRYPT_ENAB\s+yes/i);
		}
	close(DEFS);
	}
$use_md5_cache = $md5;
return $md5;
}

1;
