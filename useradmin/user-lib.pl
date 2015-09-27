=head1 user-lib.pl

Functions for Unix user and group management.

 foreign_require("useradmin", "user-lib.pl");
 @users = useradmin::list_users();
 @groups = useradmin::list_groups();
 ($joe) = grep { $_->{'user'} eq 'joe' } @users;
 if ($joe) {
   $joe->{'pass'} = useradmin::encrypt_password('smeg');
   useradmin::making_changes()
   useradmin::modify_user($joe, $joe);
   useradmin::made_changes()
 }

=cut

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
if ($gconfig{'os_type'} =~ /-linux$/) {
	do "linux-lib.pl";
	}
else {
	do "$gconfig{'os_type'}-lib.pl";
	}
do "md5-lib.pl";
%access = &get_module_acl();

@random_password_chars = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9' );
$disable_string = $config{'lock_prepend'} eq "" ? "!" : $config{'lock_prepend'};

# Search types
$match_modes = [ [ 0, $text{'index_equals'} ], [ 4, $text{'index_contains'} ],
		 [ 1, $text{'index_matches'} ], [ 2, $text{'index_nequals'} ],
		 [ 5, $text{'index_ncontains'} ], [ 3, $text{'index_nmatches'}],
		 [ 6, $text{'index_lower'} ], [ 7, $text{'index_higher'} ] ];

=head2 password_file(file)

Returns true if some file looks like a valid Unix password file

=cut
sub password_file
{
my ($file) = @_;
if (!$file) {
	return 0;
	}
my $rv = $password_file_cache{$file};
if (defined($rv)) {
	return $rv;
	}
if (&open_readfile(SHTEST, $_[0])) {
	my $line = <SHTEST>;
	close(SHTEST);
	$rv = $line =~ /^\S+:\S*:/ ? 1 : 0;
	}
else {
	$rv = 0;
	}
$password_file_cache{$file} = $rv;
return $rv;
}

=head2 list_users

Returns an array of hash references, each containing info about one user. Each
hash will always contain the keys :

=item user - The Unix username.

=item pass - Encrypted password, perhaps using MD5 or DES.

=item uid - User's ID.

=item gid - User's primary group's ID.

=item real - Real name for the user. May also contain office phone, home phone and office location, comma-separated.

=item home - User's home directory.

=item shell - Shell command to run when the user logs in.

In addition, if the system supports shadow passwords it may also have the keys :

=item change - Days since 1970 the password was last changed.

=item min - Days before password may be changed.

=item max - Days after which password must be changed.

=item warn - Days before password is to expire that user is warned.

=item inactive - Days after password expires that account is disabled.

=item expire - Days since Jan 1, 1970 that account is disabled.

Or if it supports FreeBSD master.passwd info, it will also have keys :

=item class - User's login class.

=item change - Unix time at which the password was last changed.

=item expire - Unix time at which the password will expire.

=cut
sub list_users
{
return @list_users_cache if (scalar(@list_users_cache));

# read the password file
local (@rv, $_, %idx, $lnum, @pw, $p, $i, $j);
local $pft = &passfiles_type();
if ($pft == 1) {
	# read the master.passwd file only
	$lnum = 0;
	&open_readfile(PASSWD, $config{'master_file'});
	while(<PASSWD>) {
		s/\r|\n//g;
		if (/\S/ && !/^[#\+\-]/) {
			@pw = split(/:/, $_, -1);
			push(@rv, { 'user' => $pw[0],	'pass' => $pw[1],
				    'uid' => $pw[2],	'gid' => $pw[3],
				    'class' => $pw[4],	'change' => $pw[5],
				    'expire' => $pw[6],	'real' => $pw[7],
				    'home' => $pw[8],	'shell' => $pw[9],
				    'line' => $lnum,	'num' => scalar(@rv) });
			}
		$lnum++;
		}
	close(PASSWD);
	}
elsif ($pft == 6) {
	# Read netinfo dump
	&open_execute_command(PASSWD, "nidump passwd '$netinfo_domain'", 1);
	while(<PASSWD>) {
		s/\r|\n//g;
		if (/\S/ && !/^[#\+\-]/) {
			@pw = split(/:/, $_, -1);
			push(@rv, { 'user' => $pw[0],	'pass' => $pw[1],
				    'uid' => $pw[2],	'gid' => $pw[3],
				    'class' => $pw[4],	'change' => $pw[5],
				    'expire' => $pw[6],	'real' => $pw[7],
				    'home' => $pw[8],	'shell' => $pw[9],
				    'num' => scalar(@rv) });
			}
		}
	close(PASSWD);
	}
elsif ($pft == 7) {
	# Read directory services dump of users
	&open_execute_command(PASSWD,
		"dscl '$netinfo_domain' readall /Users", 1);
	local $user;
	local $ls = $config{'lock_string'};
	while(<PASSWD>) {
		s/\r|\n//g;
		if ($_ eq "-") {
			# End of the current user
			$user = undef;
			}
		elsif (/^(\S+):\s*(.*)$/) {
			# Value for a user
			if (!$user) {
				$user = { 'num' => scalar(@rv) };
				push(@rv, $user);
				}
			local ($n, $v) = ($1, $2);
			if ($n ne 'RealName' && $v eq '') {
				# Multi-line value
				$v = <PASSWD>;
				$v =~ s/^ //;
				}
			local $p = $user_properties_map{$n};
			if ($p) {
				# Some OSX users have two names, like _foo foo
				$v =~ s/\s.*$// if ($p eq 'user');
				$user->{$p} = $v;
				}
			elsif ($n eq "GeneratedUID") {
				# Given the UID, we can get the password hash
				$user->{'pass'} = &get_macos_password_hash($v);
				$user->{'uuid'} = $v;
				if (substr($user->{'pass'}, 0,
					   length($ls)) eq $ls) {
					# Account locked
					$user->{'pass'} = $ls;
					}
				}
			}
		}
	close(PASSWD);
	}
else {
	# start by reading /etc/passwd
	$lnum = 0;
	&open_readfile(PASSWD, $config{'passwd_file'});
	while(<PASSWD>) {
		s/\r|\n//g;
		if (/\S/ && !/^[#\+\-]/) {
			@pw = split(/:/, $_, -1);
			push(@rv, { 'user' => $pw[0],	'pass' => $pw[1],
				    'uid' => $pw[2],	'gid' => $pw[3],
				    'real' => $pw[4],	'home' => $pw[5],
				    'shell' => $pw[6],	'line' => $lnum,
				    'num' => scalar(@rv) });
			$idx{$pw[0]} = $rv[$#rv];
			}
		$lnum++;
		}
	close(PASSWD);
	if ($pft == 2 || $pft == 5) {
		# read the shadow file data
		$lnum = 0;
		&open_readfile(SHADOW, $config{'shadow_file'});
		while(<SHADOW>) {
			s/\r|\n//g;
			if (/\S/ && !/^[#\+\-]/) {
				@pw = split(/:/, $_, -1);
				$p = $idx{$pw[0]};
				$p->{'pass'} = $pw[1];
				$p->{'change'} = $pw[2] < 0 ? "" : $pw[2];
				$p->{'min'} = $pw[3] < 0 ? "" : $pw[3];
				$p->{'max'} = $pw[4] < 0 ? "" : $pw[4];
				$p->{'warn'} = $pw[5] < 0 ? "" : $pw[5];
				$p->{'inactive'} = $pw[6] < 0 ? "" : $pw[6];
				$p->{'expire'} = $pw[7] < 0 ? "" : $pw[7];
				$p->{'sline'} = $lnum;
				}
			$lnum++;
			}
		close(SHADOW);
		for($i=0; $i<@rv; $i++) {
			if (!defined($rv[$i]->{'sline'})) {
				# not in shadow!
				for($j=$i; $j<@rv; $j++) { $rv[$j]->{'num'}--; }
				splice(@rv, $i--, 1);
				}
			}
		}
	elsif ($pft == 4) {
		# read the AIX security passwd file
		local $lastuser;
		local $lnum = 0;
		&open_readfile(SECURITY, $config{'shadow_file'});
		while(<SECURITY>) {
			s/\s*$//;
			if (/^\s*(\S+):/) {
				$lastuser = $idx{$1};
				$lastuser->{'sline'} = $lnum;
				}
			elsif (/^\s*([^=\s]+)\s*=\s*(.*)/) {
				if ($1 eq 'password') {
					$lastuser->{'pass'} = $2;
					}
				elsif ($1 eq 'lastupdate') {
					$lastuser->{'change'} = $2;
					}
				elsif ($1 eq 'flags') {
					map { $lastuser->{lc($_)}++ }
					    split(/[,\s]+/, $2);
					}
				$lastuser->{'seline'} = $lnum;
				}
			$lnum++;
			}
		close(SECURITY);

		# read the AIX security user file
		&open_readfile(USER, $config{'aix_user_file'});
		while(<USER>) {
			s/\s*$//;
			if (/^\s*(\S+):/) {
				$lastuser = $idx{$1};
				}
			elsif (/^\s*([^=\s]+)\s*=\s*(.*)/) {
				if ($1 eq 'expires') {
					$lastuser->{'expire'} = $2;
					}
				elsif ($1 eq 'minage') {
					$lastuser->{'min'} = $2;
					}
				elsif ($1 eq 'maxage') {
					$lastuser->{'max'} = $2;
					}
				elsif ($1 eq 'pwdwarntime') {
					$lastuser->{'warn'} = $2;
					}
				}
			}
		close(USER);
		}
	}
@list_users_cache = @rv;
return @rv;
}

=head2 create_user(&details)

Creates a new user with the given details, supplied in a hash ref. This must
be in the same format as returned by list_users, and must contain at a minimum
the user, uid, gid, pass, shell, home and real keys.

=cut
sub create_user
{
local $lref;
local $pft = &passfiles_type();
if ($pft == 1) {
	# just need to add to master.passwd
	$lref = &read_file_lines($config{'master_file'});
	$_[0]->{'line'} = &nis_index($lref);
	splice(@$lref, $_[0]->{'line'}, 0,
	       "$_[0]->{'user'}:$_[0]->{'pass'}:$_[0]->{'uid'}:".
	       "$_[0]->{'gid'}:$_[0]->{'class'}:$_[0]->{'change'}:".
	       "$_[0]->{'expire'}:$_[0]->{'real'}:$_[0]->{'home'}:".
	       "$_[0]->{'shell'}");
	if (scalar(@list_users_cache)) {
		map { $_->{'line'}++ if ($_->{'line'} >= $_[0]->{'line'}) }
		    @list_users_cache;
		}
	}
elsif ($pft == 3) {
	# Just invoke the useradd command
	&system_logged("useradd -u $_[0]->{'uid'} -g $_[0]->{'gid'} -c \"$_[0]->{'real'}\" -d $_[0]->{'home'} -s $_[0]->{'shell'} $_[0]->{'user'}");
	# And set the password
	&system_logged("echo ".quotemeta($_[0]->{'pass'}).
		       " | /usr/lib/scoadmin/account/password.tcl ".
		       "$_[0]->{'user'} >/dev/null 2>&1");
	}
elsif ($pft == 6) {
	# Use the niutil command
	&system_logged("niutil -create '$netinfo_domain' '/users/$_[0]->{'user'}'");
	&set_netinfo($_[0]);
	}
elsif ($pft == 7) {
	# Add to directory services
	&execute_dscl_command("create", "/Users/$_[0]->{'user'}");
	local $out = &execute_dscl_command("read", "/Users/$_[0]->{'user'}");
	if ($out =~ /GeneratedUID:\s+(\S+)/) {
		$_[0]->{'uuid'} = $1;
		}
	&set_user_dirinfo($_[0]);
	}
else {
	# add to /etc/passwd
	$lref = &read_file_lines($config{'passwd_file'});
	$_[0]->{'line'} = &nis_index($lref);
	if (scalar(@list_users_cache)) {
		map { $_->{'line'}++ if ($_->{'line'} >= $_[0]->{'line'}) }
		    @list_users_cache;
		}
	splice(@$lref, $_[0]->{'line'}, 0,
	       "$_[0]->{'user'}:".
	       ($pft == 2 || $pft == 5 ? "x" : $pft == 4 ? "!" :
			$_[0]->{'pass'}).
	       ":$_[0]->{'uid'}:$_[0]->{'gid'}:$_[0]->{'real'}:".
	       "$_[0]->{'home'}:$_[0]->{'shell'}");
	if ($pft == 2 || $pft == 5) {
		# Find correct place to insert in shadow file
		$lref = &read_file_lines($config{'shadow_file'});
		$_[0]->{'sline'} = &nis_index($lref);
		if (scalar(@list_users_cache)) {
			map { $_->{'sline'}++
			      if ($_->{'sline'} >= $_[0]->{'sline'}) }
			    @list_users_cache;
			}
		}
	if ($pft == 2) {
		# add to shadow as well..
		splice(@$lref, $_[0]->{'sline'}, 0,
		       "$_[0]->{'user'}:$_[0]->{'pass'}:$_[0]->{'change'}:".
		       "$_[0]->{'min'}:$_[0]->{'max'}:$_[0]->{'warn'}:".
		       "$_[0]->{'inactive'}:$_[0]->{'expire'}:");
		}
	elsif ($pft == 5) {
		# add to SCO shadow file
		splice(@$lref, $_[0]->{'sline'}, 0,
	       	    "$_[0]->{'user'}:$_[0]->{'pass'}:$_[0]->{'change'}:".
		    "$_[0]->{'min'}:$_[0]->{'max'}");
		}
	elsif ($pft == 4) {
		# add to AIX security passwd file as well..
		local @flags;
		push(@flags, 'ADMIN') if ($_[0]->{'admin'});
		push(@flags, 'ADMCHG') if ($_[0]->{'admchg'});
		push(@flags, 'NOCHECK') if ($_[0]->{'nocheck'});
		$lref = &read_file_lines($config{'shadow_file'});
		push(@$lref, "", "$_[0]->{'user'}:",
			     "\tpassword = $_[0]->{'pass'}",
			     "\tlastupdate = $_[0]->{'change'}",
			     "\tflags = ".join(",", @flags));
		
		# add to AIX security user file as well..
		$lref = &read_file_lines($config{'aix_user_file'});
		if ($_[0]->{'expire'} || $_[0]->{'min'} ||
		    $_[0]->{'max'} || $_[0]->{'warn'} ) {
			push(@$lref, "$_[0]->{'user'}:");
			push(@$lref, "\texpires = $_[0]->{'expire'}")
				if ($_[0]->{'expire'});
			push(@$lref, "\tminage = $_[0]->{'min'}")
				if ($_[0]->{'min'});
			push(@$lref, "\tmaxage = $_[0]->{'max'}")
				if ($_[0]->{'max'});
			push(@$lref, "\tpwdwarntime = $_[0]->{'warn'}")
				if ($_[0]->{'warn'});
			push(@$lref, "");
			}
		}
	}
&flush_file_lines() if (!$batch_mode);
push(@list_users_cache, $_[0]) if (scalar(@list_users_cache));
&refresh_nscd() if (!$batch_mode);
}

=head2 modify_user(&old, &details)

Update an existing Unix user with new details. The user to change must be
in &old, and the new values are in &details. These can be references to the
same hash if you like.

=cut
sub modify_user
{
$_[0] || &error("Missing parameter to modify_user");
local(@passwd, @shadow, $lref);
local $pft = &passfiles_type();
if ($pft == 1) {
	# just need to update master.passwd
	$_[0]->{'line'} =~ /^\d+$/ || &error("Missing user line to modify");
	$lref = &read_file_lines($config{'master_file'});
	$lref->[$_[0]->{'line'}] = 
	      "$_[1]->{'user'}:$_[1]->{'pass'}:$_[1]->{'uid'}:".
	      "$_[1]->{'gid'}:$_[1]->{'class'}:$_[1]->{'change'}:".
	      "$_[1]->{'expire'}:$_[1]->{'real'}:$_[1]->{'home'}:".
	      "$_[1]->{'shell'}";
	}
elsif ($pft == 3) {
	# Just use the usermod command
	&system_logged("usermod -u $_[1]->{'uid'} -g $_[1]->{'gid'} -c \"$_[1]->{'real'}\" -d $_[1]->{'home'} -s $_[1]->{'shell'} $_[1]->{'user'}");
	&system_logged("echo ".quotemeta($_[1]->{'pass'})." | /usr/lib/scoadmin/account/password.tcl $_[1]->{'user'}");
	}
elsif ($pft == 6) {
	# Just use the niutil command to update
	if ($_[0]->{'user'} && $_[0]->{'user'} ne $_[1]->{'user'}) {
		# Need to delete and re-create!
		&system_logged("niutil -destroy '$netinfo_domain' '/users/$_[0]->{'user'}'");
		&system_logged("niutil -create '$netinfo_domain' '/users/$_[1]->{'user'}'");
		}
	&set_netinfo($_[1]);
	}
elsif ($pft == 7) {
	# Call directory services to update the user
	if ($_[0]->{'user'} && $_[0]->{'user'} ne $_[1]->{'user'}) {
		# Need to rename
		&execute_dscl_command("change", "/Users/$_[0]->{'user'}",
			      "RecordName", $_[0]->{'user'}, $_[1]->{'user'});
		}
	$_[1]->{'uuid'} = $_[0]->{'uuid'};
	&set_user_dirinfo($_[1]);
	}
else {
	# update /etc/passwd
	$lref = &read_file_lines($config{'passwd_file'});
	$_[0]->{'line'} =~ /^\d+$/ || &error("Missing user line to modify");
	$lref->[$_[0]->{'line'}] =
		"$_[1]->{'user'}:".
		($pft == 2 || $pft == 5 ? "x" : $pft == 4 ? "!" :
		 $_[1]->{'pass'}).
		":$_[1]->{'uid'}:$_[1]->{'gid'}:$_[1]->{'real'}:".
		"$_[1]->{'home'}:$_[1]->{'shell'}";
	if ($pft == 2) {
		# update shadow file as well..
		$_[0]->{'sline'} =~ /^\d+$/ ||
			&error("Missing user line to modify");
		$lref = &read_file_lines($config{'shadow_file'});
		$lref->[$_[0]->{'sline'}] =
			"$_[1]->{'user'}:$_[1]->{'pass'}:$_[1]->{'change'}:".
			"$_[1]->{'min'}:$_[1]->{'max'}:$_[1]->{'warn'}:".
			"$_[1]->{'inactive'}:$_[1]->{'expire'}:";
		}
	elsif ($pft == 5) {
		# update SCO shadow
		$_[0]->{'sline'} =~ /^\d+$/ ||
			&error("Missing user line to modify");
		$lref = &read_file_lines($config{'shadow_file'});
		$lref->[$_[0]->{'sline'}] =
		   "$_[1]->{'user'}:$_[1]->{'pass'}:$_[1]->{'change'}:".
		   "$_[1]->{'min'}:$_[1]->{'max'}";
		}
	elsif ($pft == 4) {
		# update AIX shadow passwd file as well..
		if (defined($_[0]->{'sline'})) {
			local @flags;
			push(@flags, 'ADMIN') if ($_[1]->{'admin'});
			push(@flags, 'ADMCHG') if ($_[1]->{'admchg'});
			push(@flags, 'NOCHECK') if ($_[1]->{'nocheck'});
			local $lref = &read_file_lines($config{'shadow_file'});
			splice(@$lref, $_[0]->{'sline'},
			     $_[0]->{'seline'} - $_[0]->{'sline'} + 1,
			     "$_[1]->{'user'}:", "\tpassword = $_[1]->{'pass'}",
			     "\tlastupdate = $_[1]->{'change'}",
			     "\tflags = ".join(",", @flags));
			&flush_file_lines();	# have to flush on AIX
			}

		# update AIX security user file as well..
		# use chuser command because it's easier than working
		# with the complexity issues of the file.
		&system_logged("chuser expires=$_[1]->{'expire'} minage=$_[1]->{'min'} maxage=$_[1]->{'max'} pwdwarntime=$_[1]->{'warn'} $_[1]->{'user'}");
		}
	}
if ($_[0] ne $_[1] && &indexof($_[0], @list_users_cache) != -1) {
	# Update old object in cache
	$_[1]->{'line'} = $_[0]->{'line'} if (defined($_[0]->{'line'}));
	$_[1]->{'uuid'} = $_[0]->{'uuid'} if (defined($_[0]->{'uuid'}));
	$_[1]->{'sline'} = $_[0]->{'sline'} if (defined($_[0]->{'sline'}));
	$_[1]->{'seline'} = $_[0]->{'seline'} if (defined($_[0]->{'seline'}));
	%{$_[0]} = %{$_[1]};
	}
if (!$batch_mode) {
	&flush_file_lines();
	&refresh_nscd();
	}
}

=head2 delete_user(&details)

Delete an existing user. The &details hash must be user information as
returned by list_users.

=cut
sub delete_user
{
local $lref;
$_[0] || &error("Missing parameter to delete_user");
local $pft = &passfiles_type();
if ($pft == 1) {
	# Delete from BSD master.passwd file
	$_[0]->{'line'} =~ /^\d+$/ || &error("Missing user line to delete");
	$lref = &read_file_lines($config{'master_file'});
	splice(@$lref, $_[0]->{'line'}, 1);
	map { $_->{'line'}-- if ($_->{'line'} > $_[0]->{'line'}) }
	    @list_users_cache;
	}
elsif ($pft == 3) {
	# Just invoke the userdel command
	&system_logged("userdel -n0 $_[0]->{'user'}");
	}
elsif ($pft == 4) {
	# Just invoke the rmuser command
	&system_logged("rmuser -p $_[0]->{'user'}");
	}
elsif ($pft == 6) {
	# Just delete with the niutil command
	&system_logged("niutil -destroy '$netinfo_domain' '/users/$_[0]->{'user'}'");
	}
elsif ($pft == 7) {
	# Delete from directory services
	&execute_dscl_command("delete", "/Users/$_[0]->{'user'}");
	}
else {
	# XXX doesn't delete from AIX file!
	$_[0]->{'line'} =~ /^\d+$/ || &error("Missing user line to delete");
	$lref = &read_file_lines($config{'passwd_file'});
	splice(@$lref, $_[0]->{'line'}, 1);
	map { $_->{'line'}-- if ($_->{'line'} > $_[0]->{'line'}) }
	    @list_users_cache;
	if ($pft == 2 || $pft == 5) {
		if (defined($_[0]->{'sline'})) {
			$lref = &read_file_lines($config{'shadow_file'});
			splice(@$lref, $_[0]->{'sline'}, 1);
			map { $_->{'sline'}--
				if ($_->{'sline'} > $_[0]->{'sline'}) }
			    @list_users_cache;
			}
		}
	}
@list_users_cache = grep { $_->{'user'} ne $_[0]->{'user'} } @list_users_cache
	if (scalar(@list_users_cache));
if (!$batch_mode) {
	&flush_file_lines();
	&refresh_nscd();
	}
}

=head2 list_groups

Returns a list of all the local groups as an array of hashes. Each will
contain the keys :

=item group - The group name.

=item pass - Rarely-used encrypted password, in DES or MD5 format.

=item gid - Unix ID for the group.

=item members - A comma-separated list of secondary group members.

=cut
sub list_groups
{
return @list_groups_cache if (scalar(@list_groups_cache));

local(@rv, $lnum, $_, %idx, $g, $i, $j, @gr);
$lnum = 0;
local $gft = &groupfiles_type();
if ($gft == 5) {
	# Get groups from netinfo
	&open_execute_command(GROUP, "nidump group '$netinfo_domain'", 1);
	while(<GROUP>) {
		s/\r|\n//g;
		if (/\S/ && !/^[#\+\-]/) {
			@gr = split(/:/, $_, -1);
			push(@rv, { 'group' => $gr[0],	'pass' => $gr[1],
				    'gid' => $gr[2],
				    'members' => join(",",split(/\s+/,$gr[3])),
				    'num' => scalar(@rv) });
			}
		}
	close(GROUP);
	}
elsif ($gft == 7) {
	# Read directory services dump of groups
	&open_execute_command(PASSWD,
		"dscl '$netinfo_domain' readall /Groups", 1);
	local $group;
	while(<PASSWD>) {
		s/\r|\n//g;
		if ($_ eq "-") {
			# End of the current group
			$group = undef;
			}
		elsif (/^(\S+):\s*(.*)$/) {
			# Value for a group
			if (!$group) {
				$group = { 'num' => scalar(@rv) };
				push(@rv, $group);
				}
			local ($n, $v) = ($1, $2);
			if ($n ne 'GroupMembership' && $v eq '') {
				# Multi-line value
				$v = <PASSWD>;
				$v =~ s/^ //;
				}
			local $p = $group_properties_map{$n};
			if ($p) {
				# Convert spaces in members list to ,
				$v =~ s/ /,/g if ($p eq 'members');
				# Some OSX groups have two names, like _foo foo
				$v =~ s/\s.*$// if ($p eq 'group');
				$group->{$p} = $v;
				}
			elsif ($n eq "GeneratedUID") {
				# Given the UUID, we can get the password hash
				$group->{'pass'} = &get_macos_password_hash($v);
				$group->{'uuid'} = $v;
				}
			}
		}
	close(PASSWD);
	}
else {
	# Read the standard group file
	&open_readfile(GROUP, $config{'group_file'});
	while(<GROUP>) {
		s/\r|\n//g;
		if (/\S/ && !/^[#\+\-]/) {
			@gr = split(/:/, $_, -1);
			push(@rv, { 'group' => $gr[0],	'pass' => $gr[1],
				    'gid' => $gr[2],	'members' => $gr[3],
				    'line' => $lnum,	'num' => scalar(@rv) });
			$idx{$gr[0]} = $rv[$#rv];
			}
		$lnum++;
		}
	close(GROUP);
	}
if ($gft == 2) {
	# read the gshadow file data
	$lnum = 0;
	&open_readfile(SHADOW, $config{'gshadow_file'});
	while(<SHADOW>) {
		s/\r|\n//g;
		if (/\S/ && !/^[#\+\-]/) {
			@gr = split(/:/, $_, -1);
			$g = $idx{$gr[0]};
			$g->{'pass'} = $gr[1];
			$g->{'sline'} = $lnum;
			}
		$lnum++;
		}
	close(SHADOW);
	#for($i=0; $i<@rv; $i++) {
	#	if (!defined($rv[$i]->{'sline'})) {
	#		# not in shadow!
	#		for($j=$i; $j<@rv; $j++) { $rv[$j]->{'num'}--; }
	#		splice(@rv, $i--, 1);
	#		}
	#	}
	}
elsif ($gft == 4) {
	# read the AIX group data
	local $lastgroup;
	local $lnum = 0;
	&open_readfile(SECURITY, $config{'gshadow_file'});
	while(<SECURITY>) {
		s/\s*$//;
		if (/^\s*(\S+):/) {
			$lastgroup = $idx{$1};
			$lastgroup->{'sline'} = $lnum;
			$lastgroup->{'seline'} = $lnum;
			}
		elsif (/^\s*([^=\s]+)\s*=\s*(.*)/) {
			$lastgroup->{'seline'} = $lnum;
			}
		$lnum++;
		}
	close(SECURITY);
	}
@list_groups_cache = @rv;
return @rv;
}

=head2 create_group(&details)

Create a new Unix group based on the given hash. Required keys are
gid - Unix group ID
group - Group name
pass - Encrypted password
members - Comma-separated list of members

=cut
sub create_group
{
local $gft = &groupfiles_type();
if ($gft == 5) {
	# Use niutil command
	&system_logged("niutil -create '$netinfo_domain' '/groups/$_[0]->{'group'}'");
	&set_group_netinfo($_[0]);
	}
elsif ($gft == 7) {
	# Use the dscl directory services command
	&execute_dscl_command("create", "/Groups/$_[0]->{'group'}");
	&set_group_dirinfo($_[0]);
	}
else {
	# Update group file(s)
	local $lref;
	$lref = &read_file_lines($config{'group_file'});
	$_[0]->{'line'} = &nis_index($lref);
	if (scalar(@list_groups_cache)) {
		map { $_->{'line'}++ if ($_->{'line'} >= $_[0]->{'line'}) }
		    @list_groups_cache;
		}
	splice(@$lref, $_[0]->{'line'}, 0,
	       "$_[0]->{'group'}:".
	       (&groupfiles_type() == 2 ? "x" : $_[0]->{'pass'}).
	       ":$_[0]->{'gid'}:$_[0]->{'members'}");
	if ($gft == 2) {
		$lref = &read_file_lines($config{'gshadow_file'});
		$_[0]->{'sline'} = &nis_index($lref);
		if (scalar(@list_groups_cache)) {
			map { $_->{'sline'}++
			      if ($_->{'sline'} >= $_[0]->{'sline'}) }
			    @list_groups_cache;
			}
		splice(@$lref, $_[0]->{'sline'}, 0,
		       "$_[0]->{'group'}:$_[0]->{'pass'}::$_[0]->{'members'}");
		}
	elsif ($gft == 4) {
		$lref = &read_file_lines($config{'gshadow_file'});
		$_[0]->{'sline'} = scalar(@$lref);
		push(@$lref, "", "$_[0]->{'group'}:", "\tadmin = false");
		}
	&flush_file_lines();
	}
&refresh_nscd();
push(@list_groups_cache, $_[0]) if (scalar(@list_groups_cache));
}

=head2 modify_group(&old, &details)

Update an existing Unix group specified in old based on the given details hash. 
These can both be references to the same hash if you like. The hash must be
in the same format as returned by list_groups.

=cut
sub modify_group
{
$_[0] || &error("Missing parameter to modify_group");
local $gft = &groupfiles_type();
if ($gft == 5) {
	# Call niutil to update the group
	if ($_[0]->{'group'} && $_[0]->{'group'} ne $_[1]->{'group'}) {
		# Need to delete and re-create!
		&system_logged("niutil -destroy '$netinfo_domain' '/groups/$_[0]->{'group'}'");
		&system_logged("niutil -create '$netinfo_domain' '/groups/$_[1]->{'group'}'");
		}
	&set_group_netinfo($_[1]);
	}
elsif ($gft == 7) {
	# Call dscl to update the group
	if ($_[0]->{'group'} && $_[0]->{'group'} ne $_[1]->{'group'}) {
		# Need to rename
		&execute_dscl_command("change", "/Groups/$_[0]->{'group'}",
			      "RecordName", $_[0]->{'group'}, $_[1]->{'group'});
		}
	$_[1]->{'uuid'} = $_[0]->{'uuid'};
	&set_group_dirinfo($_[1]);
	}
else {
	# Update in files
	local $gs = (&groupfiles_type() == 2 && $_[0]->{'sline'} ne '');
	&replace_file_line($config{'group_file'}, $_[0]->{'line'},
		   "$_[1]->{'group'}:".($gs ? "x" : $_[1]->{'pass'}).
		   ":$_[1]->{'gid'}:$_[1]->{'members'}\n");
	if ($gs) {
		&replace_file_line($config{'gshadow_file'}, $_[0]->{'sline'},
				   "$_[1]->{'group'}:$_[1]->{'pass'}::$_[1]->{'members'}\n");
		}
	elsif (&groupfiles_type() == 4) {
		&replace_file_line($config{'gshadow_file'},
				   $_[0]->{'sline'},
				   "$_[1]->{'group'}:\n");
		}
	}
if ($_[0] ne $_[1] && &indexof($_[0], @list_groups_cache) != -1) {
	$_[1]->{'line'} = $_[0]->{'line'} if (defined($_[0]->{'line'}));
	$_[1]->{'sline'} = $_[0]->{'sline'} if (defined($_[0]->{'sline'}));
	$_[1]->{'uuid'} = $_[0]->{'uuid'} if (defined($_[0]->{'uuid'}));
	%{$_[0]} = %{$_[1]};
	}
&refresh_nscd();
}

=head2 delete_group(&details)

Delete an existing Unix group, whose details are in the hash ref supplied.

=cut
sub delete_group
{
$_[0] || &error("Missing parameter to delete_group");
local $gft = &groupfiles_type();
if ($gft == 5) {
	# Call niutil to delete
	&system_logged("niutil -destroy '$netinfo_domain' '/groups/$_[0]->{'group'}'");
	}
elsif ($gft == 7) {
	# Delete from directory services
	&execute_dscl_command("delete", "/Groups/$_[0]->{'group'}");
	}
else {
	# Remove from group file(s)
	&replace_file_line($config{'group_file'}, $_[0]->{'line'});
	map { $_->{'line'}-- if ($_->{'line'} > $_[0]->{'line'}) }
	    @list_groups_cache;
	if ($gft == 2 && $_[0]->{'sline'} ne '') {
		&replace_file_line($config{'gshadow_file'}, $_[0]->{'sline'});
		map { $_->{'sline'}-- if ($_->{'sline'} > $_[0]->{'sline'}) }
		    @list_groups_cache;
		}
	elsif ($gft == 4) {
		local $lref = &read_file_lines($config{'gshadow_file'});
		splice(@$lref, $_[0]->{'sline'},
		       $_[0]->{'seline'} - $_[0]->{'sline'} + 1);
		&flush_file_lines();
		}
	}
@list_groups_cache = grep { $_ ne $_[0] } @list_groups_cache
	if (scalar(@list_groups_cache));
&refresh_nscd();
}


=head2 recursive_change(dir, olduid, oldgid, newuid, newgid)

Change the UID or GID of a directory and all files in it, if they match the
given old UID and/or GID. If either of the old IDs are -1, then they are
ignored for match purposes.

=cut
sub recursive_change
{
local(@list, $f, @stbuf);
local $real = &translate_filename($_[0]);
(@stbuf = stat($real)) || return;
(-l $real) && return;
if (($_[1] < 0 || $_[1] == $stbuf[4]) &&
    ($_[2] < 0 || $_[2] == $stbuf[5])) {
	# Found match..
	&set_ownership_permissions(
		$_[3] < 0 ? $stbuf[4] : $_[3],
	      	$_[4] < 0 ? $stbuf[5] : $_[4], undef, $_[0]);
	}
if (-d $real) {
	opendir(DIR, $real);
	@list = readdir(DIR);
	closedir(DIR);
	foreach $f (@list) {
		if ($f eq "." || $f eq "..") { next; }
		&recursive_change("$_[0]/$f", $_[1], $_[2], $_[3], $_[4]);
		}
	}
}

=head2 making_changes

Must be called before changes are made to the password or group file.

=cut
sub making_changes
{
if ($config{'pre_command'} =~ /\S/) {
	local $out = &backquote_logged("($config{'pre_command'}) 2>&1 </dev/null");
	return $? ? $out : undef;
	}
return undef;
}

=head2 made_changes

Must be called after the password or group file has been changed, to run the
post-changes command.

=cut
sub made_changes
{
if ($config{'post_command'} =~ /\S/) {
	local $out = &backquote_logged("($config{'post_command'}) 2>&1 </dev/null");
	return $? ? $out : undef;
	}
return undef;
}

=head2 other_modules(function, arg, ...)

Call some function in the useradmin_update.pl file in other modules. Should be
called after creating, deleting or modifying a user.

=cut
sub other_modules
{
return if (&is_readonly_mode());	# don't even try other modules
local($m, %minfo);
local $func = shift(@_);
foreach $m (&get_all_module_infos()) {
	local $mdir = &module_root_directory($m->{'dir'});
	if (&check_os_support($m) &&
	    -r "$mdir/useradmin_update.pl") {
		&foreign_require($m->{'dir'}, "useradmin_update.pl");
		local $pkg = $m->{'dir'};
		$pkg =~ s/[^A-Za-z0-9]/_/g;
		local $fullfunc = "${pkg}::${func}";
		if (defined(&$fullfunc)) {
			&foreign_call($m->{'dir'}, $func, @_);
			}
		}
	}
}

=head2 can_edit_user(&acl, &user)

Returns 1 if the given user hash can be edited by a Webmin user whose access
control permissions for this module are in the acl parameter.

=cut
sub can_edit_user
{
local $m = $_[0]->{'uedit_mode'};
local %u;
if ($m == 0) { return 1; }
elsif ($m == 1) { return 0; }
elsif ($m == 2 || $m == 3 || $m == 5) {
	map { $u{$_}++ } &split_quoted_string($_[0]->{'uedit'});
	if ($m == 5 && $_[0]->{'uedit_sec'}) {
		# Check secondary groups too
		return 1 if ($u{$_[1]->{'gid'}});
		foreach $g (&list_groups()) {
			local @m = split(/,/, $g->{'members'});
			return 1 if ($u{$g->{'gid'}} &&
				     &indexof($_[1]->{'user'}, @m) >= 0);
			}
		return 0;
		}
	else {
		return $m == 2 ? $u{$_[1]->{'user'}} :
		       $m == 3 ? !$u{$_[1]->{'user'}} :
				 $u{$_[1]->{'gid'}};
		}
	}
elsif ($m == 4) {
	return (!$_[0]->{'uedit'} || $_[1]->{'uid'} >= $_[0]->{'uedit'}) &&
	       (!$_[0]->{'uedit2'} || $_[1]->{'uid'} <= $_[0]->{'uedit2'});
	}
elsif ($m == 6) {
	return $_[1]->{'user'} eq $remote_user;
	}
elsif ($m == 7) {
	return $_[1]->{'user'} =~ /$_[0]->{'uedit_re'}/;
	}
return 0;
}

=head2 can_edit_group(&acl, &group)

Returns 1 if the given group hash can be edited by a Webmin user whose access
control permissions for this module are in the acl parameter.

=cut
sub can_edit_group
{
local $m = $_[0]->{'gedit_mode'};
local %g;
if ($m == 0) { return 1; }
elsif ($m == 1) { return 0; }
elsif ($m == 2 || $m == 3) {
	map { $g{$_}++ } &split_quoted_string($_[0]->{'gedit'});
	return $m == 2 ? $g{$_[1]->{'group'}}
		       : !$g{$_[1]->{'group'}};
	}
else { return (!$_[0]->{'gedit'} || $_[1]->{'gid'} >= $_[0]->{'gedit'}) &&
	      (!$_[0]->{'gedit2'} || $_[1]->{'gid'} <= $_[0]->{'gedit2'}); }
}

=head2 nis_index(&lines)

Internal function to return the line number on which NIS includes start
in a password or group file.

=cut
sub nis_index
{
local $i;
for($i=0; $i<@{$_[0]}; $i++) {
	last if ($_[0]->[$i] =~ /^[\+\-]/);
	}
return $i;
}

=head2 get_skel_directory(&user, groupname)

Returns the skeleton files directory for some user. The groupname parameter
must be the name of his primary group.

=cut
sub get_skel_directory
{
local ($user, $groupname) = @_;
local $uf = $config{'user_files'};
local $shell = $user->{'shell'};
$shell =~ s/^(.*)\///g;
if ($groupname ne '') {
	$uf =~ s/\$group/$groupname/g;
	}
$uf =~ s/\$gid/$user->{'gid'}/g;
$uf =~ s/\$shell/$shell/g;
return $uf;
}

=head2 copy_skel_files(source, dest, uid, gid)

Copies skeleton files from some source directory (such as /etc/skel) to a 
destination directory, typically a new user's home. The uid and gid are the
IDs of the new user, which determines file ownership.

=cut
sub copy_skel_files
{
local ($f, $df);
local @rv;
foreach $f (split(/\s+/, $_[0])) {
	if (-d $f && !-l $f) {
		# copy all files in a directory
		opendir(DIR, $f);
		foreach $df (readdir(DIR)) {
			if ($df eq "." || $df eq "..") { next; }
			push(@rv, &copy_file("$f/$df", $_[1], $_[2], $_[3]));
			}
		closedir(DIR);
		}
	elsif (-r $f) {
		# copy just one file
		push(@rv, &copy_file($f, $_[1], $_[2], $_[3]));
		}
	}
return @rv;
}

=head2 copy_file(file, destdir, uid, gid)

Copy a file or directory and chown it, preserving symlinks and special files.
Mainly for internal use by copy_skel_files.

=cut
sub copy_file
{
local($base, $subs);
$_[0] =~ /\/([^\/]+)$/; $base = $1;
if ($config{"files_remap_$base"}) {
	$base = $config{"files_remap_$base"};
	}
$subs = $config{'files_remove'};
$base =~ s/$subs//g if ($subs);
local ($opts, $nochown);
local @rv = ( "$_[1]/$base" );
if (-b $_[0] || -c $_[0]) {
	# Looks like a device file .. re-create it
	local @st = stat($_[0]);
	local $maj = int($st[6] / 256);
	local $min = $st[6] % 256;
	local $typ = ($st[2] & 00170000) == 0020000 ? 'c' : 'b';
	&system_logged("mknod ".quotemeta("$_[1]/$base")." $typ $maj $min");
	&set_ownership_permissions($_[2], $_[3], undef, "$_[1]/$base");
	$nochown++;
	}
elsif (-l $_[0] && !$config{'copy_symlinks'}) {
	# A symlink .. re-create it
	local $l = readlink($_[0]);
	&system_logged("ln -s ".quotemeta($l)." ".quotemeta("$_[1]/$base")." >/dev/null 2>/dev/null");
	$opts = "-h";
	}
elsif (-d $_[0]) {
	# A directory .. copy it recursively
	&system_logged("cp -Rp ".quotemeta($_[0])." ".quotemeta("$_[1]/$base")." >/dev/null 2>/dev/null");
	push(@rv, &recursive_find_files("$_[1]/$base", 1));
	}
else {
	# Just a normal file .. copy it
	local @st = stat(&translate_filename($_[0]));
	&system_logged("cp ".quotemeta($_[0])." ".quotemeta("$_[1]/$base")." >/dev/null 2>/dev/null");
	&set_ownership_permissions($_[2], $_[3], $st[2], "$_[1]/$base");
	$nochown++;
	}
&system_logged("chown $opts -R $_[2]:$_[3] ".quotemeta("$_[1]/$base").
	       " >/dev/null 2>/dev/null") if (!$nochown);
return @rv;
}

=head2 recursive_find_files

Returns a list of all files under some directory, with recursion

=cut
sub recursive_find_files
{
my ($dir, $exclude_links) = @_;
my @rv;
if (-l $dir) {
	push(@rv, $dir) if (!$exclude_links);
	}
elsif (!-d $dir) {
	push(@rv, $dir);
	}
else {
	opendir(DIR, $dir);
	my @files = readdir(DIR);
	closedir(DIR);
	foreach my $f (@files) {
		next if ($f eq "." || $f eq "..");
		push(@rv, &recursive_find_files("$dir/$f"));
		}
	}
return @rv;
}

=head2 lock_user_files

Lock all password, shadow and group files. Should be called before performing
any user or group operations.

=cut
sub lock_user_files
{
&lock_file($config{'passwd_file'});
&lock_file($config{'group_file'});
&lock_file($config{'shadow_file'});
&lock_file($config{'gshadow_file'});
&lock_file($config{'master_file'});
}

=head2 unlock_user_files

Unlock all password, shadow and group files. Should be called after all user
or group operations are complete.

=cut
sub unlock_user_files
{
&unlock_file($config{'passwd_file'});
&unlock_file($config{'group_file'});
&unlock_file($config{'shadow_file'});
&unlock_file($config{'gshadow_file'});
&unlock_file($config{'master_file'});
}

=head2 my_setpwent

The same as Perl's setpwent function, but may read from /etc/passwd directly.

=cut
sub my_setpwent
{
if ($config{'from_files'}) {
	@setpwent_cache = &list_users();
	$setpwent_pos = 0;
	}
else { return setpwent(); }
}

=head2 my_getpwent

The same as Perl's getpwent function, but may read from /etc/passwd directly.

=cut
sub my_getpwent
{
if ($config{'from_files'}) {
	my_setpwent() if (!@setpwent_cache);
	if ($setpwent_pos >= @setpwent_cache) {
		return wantarray ? () : undef;
		}
	else {
		return &pw_user_rv($setpwent_cache[$setpwent_pos++],
				   wantarray, 'user');
		}
	}
else { return getpwent(); }
}

=head2 my_endpwent

Should be called when you are done with my_setpwent and my_getpwent.

=cut
sub my_endpwent
{
if ($config{'from_files'}) {
	undef(@setpwent_cache);
	}
elsif ($gconfig{'os_type'} eq 'hpux') {
	# On hpux, endpwent() can crash perl!
	return 0;
	}
else { return endpwent(); }
}

=head2 my_getpwnam(username)

Looks up a user by name, like the getpwnam Perl function, but may read 
/etc/passwd directly.

=cut
sub my_getpwnam
{
if ($config{'from_files'}) {
	local $u;
	foreach $u (&list_users()) {
		return &pw_user_rv($u, wantarray, 'uid')
			if ($u->{'user'} eq $_[0]);
		}
	return wantarray ? () : undef;
	}
else { return getpwnam($_[0]); }
}

=head2 my_getpwuid(uid)

Looks up a user by ID, like the getpwnam Perl function, but may read 
/etc/passwd directly.

=cut
sub my_getpwuid
{
if ($config{'from_files'}) {
	foreach $u (&list_users()) {
		return &pw_user_rv($u, wantarray, 'user')
			if ($u->{'uid'} eq $_[0]);
		}
	return wantarray ? () : undef;
	}
else { return getpwuid($_[0]); }
}

=head2 pw_user_rv(&user, want-array, username-field)

Internal function to convert a user hash reference into a list in the format
return by the getpw* family of functions.

=cut
sub pw_user_rv
{
return $_[1] ? ( $_[0]->{'user'}, $_[0]->{'pass'}, $_[0]->{'uid'},
		 $_[0]->{'gid'}, undef, undef, $_[0]->{'real'},
		 $_[0]->{'home'}, $_[0]->{'shell'}, undef ) : $_[0]->{$_[2]};
}

=head2 my_setgrent

The same as Perl's setgrent function, but may read from /etc/group directly.

=cut
sub my_setgrent
{
if ($config{'from_files'}) {
	@setgrent_cache = &list_groups();
	$setgrent_pos = 0;
	}
else { return setgrent(); }
}

=head2 my_getgrent

The same as Perl's getgrent function, but may read from /etc/group directly.

=cut
sub my_getgrent
{
if ($config{'from_files'}) {
	my_setgrent() if (!@setgrent_cache);
	if ($setgrent_pos >= @setgrent_cache) {
		return ();
		}
	else {
		return &gr_group_rv($setgrent_cache[$setgrent_pos++],
				    wantarray, 'group');
		}
	}
else { return getgrent(); }
}

=head2 my_endgrent

Should be called when you are done with my_setgrent and my_getgrent.

=cut
sub my_endgrent
{
if ($config{'from_files'}) {
	undef(@setgrent_cache);
	}
elsif ($gconfig{'os_type'} eq 'hpux') {
	# On hpux, endpwent() can crash perl!
	return 0;
	}
else { return endgrent(); }
}

=head2 my_getgrnam(group)

Looks up a group by name, like the Perl getgrnam function.

=cut
sub my_getgrnam
{
if ($config{'from_files'}) {
	local $g;
	foreach $g (&list_groups()) {
		return &gr_group_rv($g, wantarray, 'gid')
			if ($g->{'group'} eq $_[0]);
		}
	return wantarray ? () : undef;
	}
else { return getgrnam($_[0]); }
}

=head2 my_getgrgid(gid)

Looks up a group by GID, like the Perl getgrgid function.

=cut
sub my_getgrgid
{
if ($config{'from_files'}) {
	foreach $g (&list_groups()) {
		return &gr_group_rv($g, wantarray, 'group')
			if ($g->{'gid'} eq $_[0]);
		}
	return wantarray ? () : undef;
	}
else { return getgrgid($_[0]); }
}

sub gr_group_rv
{
return $_[1] ? ( $_[0]->{'group'}, $_[0]->{'pass'}, $_[0]->{'gid'},
		 $_[0]->{'members'} ) : $_[0]->{$_[2]};
}

=head2 auto_home_dir(base, username, groupname)

Returns an automatically generated home directory, and creates needed
parent dirs. The parameters are :

=item base - Base directory, like /home.

=item username - The user's login name.

=item groupname - The user's primary group name.

=cut
sub auto_home_dir
{
local $pfx = $_[0] eq "/" ? "/" : $_[0]."/";
if ($config{'home_style'} == 0) {
	return $pfx.$_[1];
	}
elsif ($config{'home_style'} == 1) {
	&mkdir_if_needed($pfx.substr($_[1], 0, 1));
	return $pfx.substr($_[1], 0, 1)."/".$_[1];
	}
elsif ($config{'home_style'} == 2) {
	&mkdir_if_needed($pfx.substr($_[1], 0, 1));
	&mkdir_if_needed($pfx.substr($_[1], 0, 1)."/".
			 substr($_[1], 0, 2));
	return $pfx.substr($_[1], 0, 1)."/".
	       substr($_[1], 0, 2)."/".$_[1];
	}
elsif ($config{'home_style'} == 3) {
	&mkdir_if_needed($pfx.substr($_[1], 0, 1));
	&mkdir_if_needed($pfx.substr($_[1], 0, 1)."/".
			 substr($_[1], 1, 1));
	return $pfx.substr($_[1], 0, 1)."/".
	       substr($_[1], 1, 1)."/".$_[1];
	}
elsif ($config{'home_style'} == 4) {
	return $_[0];
	}
elsif ($config{'home_style'} == 5) {
	return $pfx.$_[2]."/".$_[1];
	}
}

sub mkdir_if_needed
{
-d $_[0] || &make_dir($_[0], 0755);
}

=head2 set_netinfo(&user)

Update a NetInfo user based on a Webmin user hash. Mainly for internal use.

=cut
sub set_netinfo
{
local %u = %{$_[0]};
&system_logged("niutil -createprop '$netinfo_domain' '/users/$u{'user'}' passwd '$u{'pass'}'");
&system_logged("niutil -createprop '$netinfo_domain' '/users/$u{'user'}' uid '$u{'uid'}'");
&system_logged("niutil -createprop '$netinfo_domain' '/users/$u{'user'}' gid '$u{'gid'}'");
&system_logged("niutil -createprop '$netinfo_domain' '/users/$u{'user'}' class '$u{'class'}'");
&system_logged("niutil -createprop '$netinfo_domain' '/users/$u{'user'}' change '$u{'change'}'");
&system_logged("niutil -createprop '$netinfo_domain' '/users/$u{'user'}' expire '$u{'expire'}'");
&system_logged("niutil -createprop '$netinfo_domain' '/users/$u{'user'}' realname '$u{'real'}'");
&system_logged("niutil -createprop '$netinfo_domain' '/users/$u{'user'}' home '$u{'home'}'");
&system_logged("niutil -createprop '$netinfo_domain' '/users/$u{'user'}' shell '$u{'shell'}'");
}

=head2 set_group_netinfo(&group)

Update a NetInfo group based on a Webmin group hash. Mainly for internal use.

=cut
sub set_group_netinfo
{
local %g = %{$_[0]};
local $mems = join(" ", map { "'$_'" } split(/,/, $g{'members'}));
&system_logged("niutil -createprop '$netinfo_domain' '/groups/$g{'group'}' gid '$g{'gid'}'");
&system_logged("niutil -createprop '$netinfo_domain' '/groups/$g{'group'}' passwd '$g{'pass'}'");
&system_logged("niutil -createprop '$netinfo_domain' '/groups/$g{'group'}' users $mems");
}

=head2 set_user_dirinfo(&user)

Update a user in OSX directive services based on a Webmin user hash.
Mainly for internal use.

=cut
sub set_user_dirinfo
{
local %u = %{$_[0]};
foreach my $k (keys %user_properties_map) {
	local $v = $u{$user_properties_map{$k}};
	if (defined($v)) {
		&execute_dscl_command("create", "/Users/$u{'user'}", $k, $v);
		}
	}
if ($u{'passmode'} == 3 && defined($u{'plainpass'}) ||
    $u{'passmode'} == 0) {
	# A new plain password was given - use it
	&execute_dscl_command("passwd", "/Users/$u{'user'}", $u{'plainpass'});
	if ($user->{'uuid'}) {
		$user->{'pass'} = &get_macos_password_hash($user->{'uuid'});
		}
	}
elsif ($u{'passmode'} == 4) {
	# Explicitly not changed, so do nothing
	}
elsif ($u{'passmode'} == 1 || $u{'pass'} eq $config{'lock_string'}) {
	# Account locked - set hash to match
	&set_macos_password_hash($u{'uuid'}, $u{'pass'});
	}
else {
	# Has the hash changed?
	local $oldpass = &get_macos_password_hash($u{'uuid'});
	if (defined($oldpass) && $u{'pass'} ne $oldpass) {
		# Yes .. so set it
		&set_macos_password_hash($u{'uuid'}, $u{'pass'});
		}
	}
}

=head2 set_group_dirinfo(&group)

Update a group in OSX directive services based on a Webmin group hash.
Mainly for internal use.

=cut
sub set_group_dirinfo
{
local %g = %{$_[0]};
$g{'members'} =~ s/,/ /g;
foreach my $k (keys %group_properties_map) {
	local $v = $g{$group_properties_map{$k}};
	if (defined($v)) {
		&execute_dscl_command("create", "/Groups/$g{'group'}", $k, $v);
		}
	}
}

=head2 check_password_restrictions(pass, username, [&user-hash|"none"])

Returns an error message if the given password fails length and other
checks, or undef if it is OK.

=cut
sub check_password_restrictions
{
local ($pass, $username, $uinfo) = @_;
return &text('usave_epasswd_min', $config{'passwd_min'})
	if (length($pass) < $config{'passwd_min'});
local $re = $config{'passwd_re'};
if ($re && !eval { $pass =~ /^$re$/ }) {
	return $config{'passwd_redesc'} || &text('usave_epasswd_re', $re);
	}
if ($config{'passwd_same'}) {
	return &text('usave_epasswd_same') if ($pass =~ /\Q$username\E/i);
	}
if ($config{'passwd_dict'} && $pass =~ /^[A-Za-z\'\-]+$/) {
	# Check if dictionary word
	return &text('usave_epasswd_dict') if (&is_dictionary_word($pass));
	}
if ($config{'passwd_prog'}) {
	local $out;
	if ($config{'passwd_progmode'} == 0) {
		# Run external validation program with user and password as args
		local $qu = quotemeta($username);
		local $qp = quotemeta($pass);
		$out = &backquote_command(
			"$config{'passwd_prog'} $qu $qp 2>&1 </dev/null");
		}
	else {
		# Run program with password as input on stdin
		local $temp = &transname();
		&open_tempfile(TEMP, ">$temp", 0, 1);
		&print_tempfile(TEMP, $username,"\n");
		&print_tempfile(TEMP, $pass,"\n");
		&close_tempfile(TEMP);
		$out = &backquote_command("$config{'passwd_prog'} <$temp 2>&1");
		}
	if ($?) {
		return $out || $text{'usave_epasswd_cmd'};
		}
	}
if ($config{'passwd_mindays'} && $uinfo ne "none") {
	# Check if password was changed too recently
	if (!$uinfo) {
		($uinfo) = grep { $_->{'user'} eq $username } &list_users();
		}
	if ($uinfo) {
		local $pft = &passfiles_type();
		local $when;
		if ($pft == 1 || $pft == 6) {
			# BSD (unix time)
			$when = $uinfo->{'change'};
			}
		elsif ($pft == 2 || $pft == 5) {
			# Linux (number of days)
			$when = $uinfo->{'change'} * 24*60*60;
			}
		elsif ($pft == 4) {
			# AIX (unix time)
			$when = $uinfo->{'change'};
			}
		if ($when && time() - $when <
				$config{'passwd_mindays'}*24*60*60) {
			return &text('usave_epasswd_mindays',
				     $config{'passwd_mindays'});
			}
		}
	}
return undef;
}

=head2 check_username_restrictions(username)

Returns an error message if a username fails some restriction, or undef if
it is OK.

=cut
sub check_username_restrictions
{
local ($username) = @_;
if ($config{'max_length'} && length($username) > $config{'max_length'}) {
	return &text('usave_elength', $config{'max_length'});
	}
local $re = $config{'username_re'};
return &text('usave_ere', $re)
	if ($re && !eval { $username =~ /^$re$/ });
return undef;
}

=head2 can_use_group(&acl, group)

Returns 1 if some group can be used as a primary or secondary, 0 if not.

=cut
sub can_use_group
{
return 1 if ($_[0]->{'ugroups'} eq '*');
local @sp = &split_quoted_string($_[0]->{'ugroups'});
if ($_[0]->{'uedit_gmode'} == 3) {
	return &indexof($_[1], @sp) < 0;
	}
elsif ($_[0]->{'uedit_gmode'} == 4) {
	local @ginfo = &my_getgrnam($_[1]);
	return (!$_[0]->{'ugroups'} || $ginfo[2] >= $_[0]->{'ugroups'}) &&
	       (!$_[0]->{'ugroups2'} || $ginfo[2] <= $_[0]->{'ugroups2'});
	}
else {
	return &indexof($_[1], @sp) >= 0;
	}
}

=head2 refresh_nscd

Sends a HUP signal to the nscd process, so that any caches are reloaded.

=cut
sub refresh_nscd
{
return if ($nscd_not_running);
if (!&find_byname("nscd")) {
	$nscd_not_running++;
	}
elsif ($config{'nscd_restart'}) {
	# Run the specified command
	&system_logged("$config{'nscd_restart'} >/dev/null 2>&1 </dev/null");
	}
elsif (&has_command("nscd")) {
	# Use nscd -i to reload
	&system_logged("nscd -i group >/dev/null 2>&1 </dev/null");
	&system_logged("nscd -i passwd >/dev/null 2>&1 </dev/null");
	}
else {
	# Send HUP signal
	local $rv = &kill_byname_logged("nscd", "HUP");
	if (!$rv) {
		$nscd_not_running++;
		}
	}
sleep(1);	# Give ncsd time to react
}

=head2 set_user_envs(&user, action, [plainpass], [secondaries], [&olduser], [oldplainpass])

Sets up the USERADMIN_ environment variables for a user update of some kind,
prior to calling making_changes or made_changes. The parameters are :

=item user - User details hash reference, in the same format as returned by list_users.

=item action - Must be one of CREATE_USER, MODIFY_USER or DELETE_USER.

=item plainpass - The user's un-encrypted password, if available.

=item secondaries - An array reference of secondary group names the user is a member of.

=item olduser - When modifying a user, the hash reference of it's old details.

=item oldplainpass - When modifying a user, it's old un-encrypted password, if available.

=cut
sub set_user_envs
{
local ($user, $action, $plainpass, $secs, $olduser, $oldpass) = @_;
&clear_envs();
$ENV{'USERADMIN_USER'} = $user->{'user'};
$ENV{'USERADMIN_UID'} = $user->{'uid'};
$ENV{'USERADMIN_REAL'} = $user->{'real'};
$ENV{'USERADMIN_SHELL'} = $user->{'shell'};
$ENV{'USERADMIN_HOME'} = $user->{'home'};
$ENV{'USERADMIN_GID'} = $user->{'gid'};
local $group = &my_getgrgid($user->{'gid'});
if ($group) {
	$ENV{'USERADMIN_GROUP'} = $group;
	}
$ENV{'USERADMIN_PASS'} = $plainpass if (defined($plainpass));
$ENV{'USERADMIN_SECONDARY'} = join(",", @{$secs}) if (defined($secs));
$ENV{'USERADMIN_ACTION'} = $action;
$ENV{'USERADMIN_SOURCE'} = $main::module_name;
if ($olduser) {
	$ENV{'USERADMIN_OLD_USER'} = $olduser->{'user'};
	$ENV{'USERADMIN_OLD_UID'} = $olduser->{'uid'};
	$ENV{'USERADMIN_OLD_REAL'} = $olduser->{'real'};
	$ENV{'USERADMIN_OLD_SHELL'} = $olduser->{'shell'};
	$ENV{'USERADMIN_OLD_HOME'} = $olduser->{'home'};
	$ENV{'USERADMIN_OLD_GID'} = $olduser->{'gid'};
	$ENV{'USERADMIN_OLD_PASS'} = $oldpass if (defined($oldpass));
	}
foreach my $f ("quota", "uquota", "mquota", "umquota") {
	$ENV{'USERADMIN_'.uc($f)} = $user->{$f};
	if ($olduser) {
		$ENV{'USERADMIN_OLD_'.uc($f)} = $olduser->{$f};
		}
	}
}

=head2 set_group_envs(&group, action, [&oldgroup])

Sets up the USERADMIN_ environment variables for a group update of some kind,
prior to calling making_changes or made_changes. The parameters are :

=item group - Group details hash reference, in the same format as returned by list_groups.

=item action - Must be one of CREATE_GROUP, MODIFY_GROUP or DELETE_GROUP.

=item oldgroup - When modifying a group, the hash reference of it's old details.

=cut
sub set_group_envs
{
local ($group, $action, $oldgroup) = @_;
&clear_envs();
$ENV{'USERADMIN_GROUP'} = $group->{'group'};
$ENV{'USERADMIN_GID'} = $group->{'gid'};
$ENV{'USERADMIN_MEMBERS'} = $group->{'members'};
$ENV{'USERADMIN_ACTION'} = $action;
$ENV{'USERADMIN_SOURCE'} = $main::module_name;
if ($oldgroup) {
	$ENV{'USERADMIN_OLD_GROUP'} = $oldgroup->{'group'};
	$ENV{'USERADMIN_OLD_GID'} = $oldgroup->{'gid'};
	$ENV{'USERADMIN_OLD_MEMBERS'} = $oldgroup->{'members'};
	}
}

=head2 clear_envs

Removes all variables set by set_user_envs and set_group_envs.

=cut
sub clear_envs
{
local $e;
foreach $e (keys %ENV) {
	delete($ENV{$e}) if ($e =~ /^USERADMIN_/);
	}
}

=head2 encrypt_password(password, [salt])

Encrypts a password using the encryption format configured for this system.
If the salt parameter is given, it will be used for hashing the password -
this is typically an already encrypted password, that you want to compare with
the result of this function to check that passwords match. If missing, a salt
will be randomly generated.

=cut
sub encrypt_password
{
local ($pass, $salt) = @_;
local $format = 0;
if ($gconfig{'os_type'} eq 'macos' && &passfiles_type() == 7) {
	# New OSX directory service uses SHA1 for passwords!
	$salt ||= chr(int(rand(26))+65).chr(int(rand(26))+65). 
		  chr(int(rand(26))+65).chr(int(rand(26))+65);
	if (&check_sha1()) {
		# Use Digest::SHA1 perl module
		return &encrypt_sha1_hash($pass, $salt);
		}
	elsif (&has_command("openssl")) {
		# Use openssl command
		local $temp = &transname();
		&open_execute_command(OPENSSL, "openssl dgst -sha1 >$temp", 0);
		print OPENSSL $salt,$pass;
		close(OPENSSL);
		local $rv = &read_file_contents($temp);
		&unlink_file($temp);
		$rv =~ s/\r|\n//g;
		return $rv;
		}
	else {
		&error("Either the Digest::SHA1 Perl module or openssl command is needed to hash passwords");
		}
	}
elsif ($config{'md5'} == 2) {
	# Always use MD5
	$format = 1;
	}
elsif ($config{'md5'} == 3) {
	# Always use blowfish
	$format = 2;
	}
elsif ($config{'md5'} == 4) {
	# Always use SHA512
	$format = 3;
	}
elsif ($config{'md5'} == 1 && !$config{'skip_md5'}) {
	# Up to system
	$format = &use_md5() if (defined(&use_md5));
	}

if ($no_encrypt_password) {
	# Some operating systems don't do any encryption!
	return $pass;
	}
elsif ($format == 1) {
	# MD5 encryption is selected .. use it if possible
	local $err = &check_md5();
	if ($err) {
		&error(&text('usave_edigestmd5',
		    "/config.cgi?$module_name",
		    "/cpan/download.cgi?source=3&cpan=$err", $err));
		}
	return &encrypt_md5($pass, $salt);
	}
elsif ($format == 2) {
	# Blowfish is selected .. use it if possible
	local $err = &check_blowfish();
	if ($err) {
		&error(&text('usave_edigestblowfish',
		    "/config.cgi?$module_name",
		    "/cpan/download.cgi?source=3&cpan=$err", $err));
		}
	return &encrypt_blowfish($pass, $salt);
	}
elsif ($format == 3) {
	# SHA512 is selected .. use it
	local $err = &check_sha512();
	if ($err) {
		&error($text{'usave_edigestsha512'});
		}
	return &encrypt_sha512($pass, $salt);
	}
else {
	# Just do old-style crypt() DES encryption
	if ($salt !~ /^[a-z0-9]{2}/i) {
		# Un-usable non-DES salt
		$salt = undef;
		}
	$salt ||= chr(int(rand(26))+65) . chr(int(rand(26))+65);
	return &unix_crypt($pass, $salt);
	}
}

=head2 build_user_used([&uid-hash], [&shell-list], [&username-hash])

Fills in hashes with used UIDs, shells and usernames, based on existing users.
Useful for allocating a new UID, with code like :

  my %used;
  useradmin::build_user_used(\%used);
  $newuid = useradmin::allocate_uid(\%used);

=cut
sub build_user_used
{
&my_setpwent();
local @u;
while(@u = &my_getpwent()) {
	$_[0]->{$u[2]}++ if ($_[0]);
	push(@{$_[1]}, $u[8]) if ($_[1] && $u[8]);
	$_[2]->{$u[0]}++ if ($_[2]);
	}
&my_endpwent();
local $u;
foreach $u (&list_users()) {
	$_[0]->{$u->{'uid'}}++ if ($_[0]);
	push(@{$_[1]}, $u->{'shell'}) if ($_[1] && $u->{'shell'});
	$_[2]->{$u->{'user'}}++ if ($_[2]);
	}
}

=head2 build_group_used([&gid-hash], [&groupname-hash])

Fills in hashes with used GIDs and group names, based on existing groups.
Useful for allocating a new GID, with code like :

  my %used;
  useradmin::build_group_used(\%used);
  $newgid = useradmin::allocate_gid(\%used);

=cut
sub build_group_used
{
&my_setgrent();
local @g;
while(@g = &my_getgrent()) {
	$_[0]->{$g[2]}++ if ($_[0]);
	$_[1]->{$g[0]}++ if ($_[1]);
	}
&my_endgrent();
local $g;
foreach $g (&list_groups()) {
	$_[0]->{$g->{'gid'}}++ if ($_[0]);
	$_[1]->{$g->{'group'}}++ if ($_[1]);
	}
}

=head2 allocate_uid(&uids-used)

Given a hash reference whose keys are UIDs already in use, returns a free UID
suitable for a new user.

=cut
sub allocate_uid
{
local $rv = int($config{'base_uid'} > $access{'lowuid'} ?
		$config{'base_uid'} : $access{'lowuid'});
while($_[0]->{$rv}) {
	$rv++;
	}
return $rv;
}

=head2 allocate_gid(&gids-used)

Given a hash reference whose keys are GIDs already in use, returns a free GID
suitable for a new group.

=cut
sub allocate_gid
{
local $rv = int($config{'base_gid'} > $access{'lowgid'} ?
		$config{'base_gid'} : $access{'lowgid'});
while($_[0]->{$rv}) {
	$rv++;
	}
return $rv;
}

=head2 list_allowed_users(&access, &allusers)

Returns a list of users to whom access is allowed. The parameters are :

=item access - A hash reference of Webmin user permissions, such as returned by get_module_acl.

=item allusers - List of all users to filter down.

=cut
sub list_allowed_users
{
local %access = %{$_[0]};
local @ulist = @{$_[1]};
if ($access{'uedit_mode'} == 1) {
	@ulist = ();
	}
elsif ($access{'uedit_mode'} == 2) {
	local %canu;
	map { $canu{$_}++ } &split_quoted_string($access{'uedit'});
	@ulist = grep { $canu{$_->{'user'}} } @ulist;
	}
elsif ($access{'uedit_mode'} == 3) {
	local %cannotu;
	map { $cannotu{$_}++ } &split_quoted_string($access{'uedit'});
	@ulist = grep { !$cannotu{$_->{'user'}} } @ulist;
	}
elsif ($access{'uedit_mode'} == 4) {
	@ulist = grep {
		(!$access{'uedit'} || $_->{'uid'} >= $access{'uedit'}) &&
		(!$access{'uedit2'} || $_->{'uid'} <= $access{'uedit2'})
			} @ulist;
	}
elsif ($access{'uedit_mode'} == 5) {
	local %cangid;
	map { $cangid{$_}++ } &split_quoted_string($access{'uedit'});
	if ($access{'uedit_sec'}) {
		# Match secondary groups too
		local @glist = &list_groups();
		local (@ucan, $g);
		foreach $g (@glist) {
			push(@ucan, split(/,/, $g->{'members'}))
				if ($cangid{$g->{'gid'}});
			}
		@ulist = grep { $cangid{$_->{'gid'}} ||
				&indexof($_->{'user'}, @ucan) >= 0 } @ulist;
		}
	else {
		@ulist = grep { $cangid{$_->{'gid'}} } @ulist;
		}
	}
elsif ($access{'uedit_mode'} == 6) {
	@ulist = grep { $_->{'user'} eq $remote_user } @ulist;
	}
elsif ($access{'uedit_mode'} == 7) {
	@ulist = grep { $_->{'user'} =~ /$access{'uedit_re'}/ } @ulist;
	}
elsif ($access{'uedit_mode'} == 8) {
	@ulist = grep {
		(!$access{'uedit'} || $_->{'gid'} >= $access{'uedit'}) &&
		(!$access{'uedit2'} || $_->{'gid'} <= $access{'uedit2'})
			} @ulist;
	}
if ($access{'view'}) {
	# Include non-editable users in results
	local @rv = @{$_[1]};
	local $u;
	foreach $u (@rv) {
		if (&indexof($u, @ulist) < 0) {
			$u->{'noedit'} = 1;
			}
		}
	return @rv;
	}
else {
	return @ulist;
	}
}

=head2 list_allowed_groups(&access, &allgroups)

Returns a list of groups to whom access is allowed. The parameters are :

=item access - A hash reference of Webmin user permissions, such as returned by get_module_acl.

=item allgroups - List of all Unix groups to filter down.

=cut
sub list_allowed_groups
{
local %access = %{$_[0]};
local @glist = @{$_[1]};
if ($access{'gedit_mode'} == 1) {
	@glist = ();
	}
elsif ($access{'gedit_mode'} == 2) {
	local %cang;
	map { $cang{$_}++ } &split_quoted_string($access{'gedit'});
	@glist = grep { $cang{$_->{'group'}} } @glist;
	}
elsif ($access{'gedit_mode'} == 3) {
	local %cannotg;
	map { $cannotg{$_}++ } &split_quoted_string($access{'gedit'});
	@glist = grep { !$cannotg{$_->{'group'}} } @glist;
	}
elsif ($access{'gedit_mode'} == 4) {
	@glist = grep {
		(!$access{'gedit'} || $_->{'gid'} >= $access{'gedit'}) &&
		(!$access{'gedit2'} || $_->{'gid'} <= $access{'gedit2'})
			} @glist;
	}
if ($access{'view'}) {
	# Include non-editable groups in results
	local @rv = @{$_[1]};
	local $g;
	foreach $g (@rv) {
		if (&indexof($g, @glist) < 0) {
			$g->{'noedit'} = 1;
			}
		}
	return @rv;
	}
else {
	return @glist;
	}
}

=head2 batch_start

Tells the create/modify/delete functions to only update files in memory,
not on disk.

=cut
sub batch_start
{
$batch_mode = 1;
}

=head2 batch_end

Flushes any user file changes

=cut
sub batch_end
{
$batch_mode = 0;
&flush_file_lines();
&refresh_nscd();
}

#################################################################

sub mkuid
{
#################################################################
#### 
#### Assumptions:
#### 
#### This subroutine assumes the usernames are standardized
#### using the format of 7 characters with 3 letters followed
#### by 4 digits, or 4 letters followed by 3 digits.  If
#### uppercase letters are used in the username, they will be
#### converted to lowercase and this subroutine will generate
#### a UID number identical to the usernames lowercase
#### equivalent. 
#### 
#### 3 letters, 4 digits   Lowest possible UID (aaa0000) =   1,000,000
#### 3 letters, 4 digits Hightest possible UID (zzz9999) = 176,759,999
#### 
#### 4 letters, 3 digits   Lowest possible UID (aaaa000) = 176,760,000
#### 4 letters, 3 digits Hightest possible UID (zzzz999) = 633,735,999
#### 
#################################################################
    my ${num_let} = 0;
    foreach (split(//,$_[0])) {
      ++${num_let} if ( m/[a-z]/i );
    }
    if ( length($_[0]) != 7 ) {
        print "ERROR: Number of characters in username $_[0] is not equal to 7\n";
        return -1;
    }
    if ( ${num_let} != 3 && ${num_let} != 4 ) {
        print "ERROR: Number of letters in username $_[0] is not equal to 3 or 4\n";
        return -1;
    }
    my ${mkuid_type} = 10 ** ( 7 - ${num_let} );
    my ${lowlimit} = 1000000;
    my %letters;
    my ${icnt} = -1;
    my ${lowuid};
    ${lowuid} = ( 26 ** ( ${num_let} - 1 ) * ${lowlimit}/100 ) + ${lowlimit};
    ${lowuid} = ${lowlimit} if ( ${num_let} == 3 );
    my ${base} = 26;

#################################################################
#### 
#### Establish an associative array containing all the
#### letters of the alphabet and assign a numeric value
#### to each letter from 1 - 26.
#### 
#################################################################
    $letters{'a'} = ++${icnt};
    $letters{'b'} = ++${icnt};
    $letters{'c'} = ++${icnt};
    $letters{'d'} = ++${icnt};
    $letters{'e'} = ++${icnt};
    $letters{'f'} = ++${icnt};
    $letters{'g'} = ++${icnt};
    $letters{'h'} = ++${icnt};
    $letters{'i'} = ++${icnt};
    $letters{'j'} = ++${icnt};
    $letters{'k'} = ++${icnt};
    $letters{'l'} = ++${icnt};
    $letters{'m'} = ++${icnt};
    $letters{'n'} = ++${icnt};
    $letters{'o'} = ++${icnt};
    $letters{'p'} = ++${icnt};
    $letters{'q'} = ++${icnt};
    $letters{'r'} = ++${icnt};
    $letters{'s'} = ++${icnt};
    $letters{'t'} = ++${icnt};
    $letters{'u'} = ++${icnt};
    $letters{'v'} = ++${icnt};
    $letters{'w'} = ++${icnt};
    $letters{'x'} = ++${icnt};
    $letters{'y'} = ++${icnt};
    $letters{'z'} = ++${icnt};

#################################################################
#### 
#### Initialize variables to be use while calculating the UID
#### number associated with the login name.
#### 
#### nvalue is used to store numeric characters that occurs
####     in the login name
#### ecnt is used to keep track of the base 26 exponent for 
####     each letter character that occurs in the login name
#### subtot is the sum of the calculated value for each
####     character position in the login name
#### mult is the total of the 26 ** ecnt at each iteration of 
####     the loop
#### 
#################################################################
    my ${kstring} = '';
    my ${nvalue} = '';
    my ${lvalue} = 0;
    my ${ecnt} = 0;
    my ${subtot} = 0;
    my ${tot} = 0;
    my ${mult} = 0;
#################################################################
#### 
#### each character position of the login name is split out
#### and used as an iteration of the foreach loop
#### 
#################################################################

    foreach (split(//,$_[0])) {

#################################################################
#### 
#### If the current character of the login name is a letter,
#### convert it to lower case, and obtain it's numeric value
#### from the associative array of letters, otherwise, if the
#### current character is a number, append the number to the
#### end of a buffer and save it for later processing.
#### 
#################################################################
      if ( m/[a-z]/i ) {
        $kstring = "\L${_}";
        ${lvalue} = ${letters{${kstring}}};
      } else {
        ${lvalue} = 0;
        ${nvalue} = "${nvalue}${_}";
      }
#################################################################
#### Calculate the multiplier for a base 26 calculation using
#### each iteration through the foreach loop as an increment
#### of the exponent.  The base 26 exponent starting at 0.
#################################################################

      ${mult} = ${base} ** ${ecnt};

#################################################################
#### 
#### Multiply the numeric value of the current character by
#### the multiplier and add this result to a running subtotal
#### of all characters of the login name.
#### 
#################################################################
      ${subtot} = ${subtot} + ( ${lvalue} * ${mult} );

#################################################################
#### 
#### Increment the base 26 exponent by one before iterating for
#### the next character of the login name.
#### 
#################################################################
      ++${ecnt}
    }

#################################################################
#### 
#### After all characters of the login name have be processed,
#### multiply the result by 1,000.  This is done because the 
#### username standard is 3 letters followed by 4 digits.  So
#### each 3 letter combination can have 1,000 possible combinations.
#### Then add the numeric values saved and any value to use
#### as the lowest UID number allowed through this calculated method.
#### 
#################################################################

    ${tot} = ( ${subtot} * ${mkuid_type} ) + int(${nvalue}) + ${lowuid};

#################################################################
#### 
#### Return the calculated UID number as the result of this
#### subroutine.
#### 
#################################################################

    return ${tot};
}
################################################################
sub berkeley_cksum {
    my($crc) = my($len) = 0;
    my($buf,$num,$i);
    my($buflen) = 4096; # buffer is "4k", you can up it if you want...

    $buf = $_[0];
    $num = length($buf);

    $len += $num;
    foreach ( unpack("C*", $buf) ) {
        $crc |= 0x10000 if ( $crc & 1 ); # get ready for rotating the 1 below
        $crc = (($crc>>1)+$_) & 0xffff; # keep to 16-bit
    }
    return sprintf("%lu",${crc});;
}

=head2 users_table(&users, [form], [no-last], [no-boxes], [&otherlinks], [&rightlinks])

Prints a table listing full user details, with checkboxes and buttons to
delete or disable multiple at once.

=cut
sub users_table
{
local ($users, $formno, $nolast, $noboxes, $links, $rightlinks) = @_;

local (@ginfo, %gidgrp);
&my_setgrent();
while(@ginfo = &my_getgrent()) {
	$gidgrp{$ginfo[2]} = $ginfo[0];
	}
&my_endgrent();

# Work out if any users can be edited
local $anyedit;
foreach my $u (@$users) {
	if (!$u->{'noedit'}) {
		$anyedit = 1;
		last;
		}
	}
$anyedit = 0 if ($noboxes);
local $lshow = !$nolast && $config{'last_show'};

local $buttons;
$buttons .= &ui_submit($text{'index_mass'}, "delete") if ($access{'udelete'});
$buttons .= &ui_submit($text{'index_mass2'}, "disable");
$buttons .= &ui_submit($text{'index_mass3'}, "enable");
$buttons .= "<br>" if ($buttons);
local @linksrow;
if ($anyedit) {
	print &ui_form_start("mass_delete_user.cgi", "post");
	push(@linksrow, &select_all_link("d", $_[1]),
			&select_invert_link("d", $_[1]));
	}
push(@linksrow, @$links);
local @grid = ( &ui_links_row(\@linksrow), &ui_links_row($rightlinks) );
print &ui_grid_table(\@grid, 2, 100, [ "align=left", "align=right" ]);

local @tds = $anyedit ? ( "width=5" ) : ( );
push(@tds, "width=15%", "width=10%");
print &ui_columns_start([
	$anyedit ? ( "" ) : ( ),
	$text{'user'},
	$text{'uid'},
	$text{'gid'},
	$text{'real'},
	$text{'home'},
	$text{'shell'},
	$lshow ? ( $text{'lastlogin'} ) : ( )
	], 100, 0, \@tds);
local $llogin;
if ($lshow) {
	$llogin = &get_recent_logins();
	if (&foreign_check("mailboxes")) {
		&foreign_require("mailboxes");
		}
	}
local $u;
foreach $u (@$users) {
	$u->{'real'} =~ s/,.*$// if ($config{'extra_real'} ||
				     $u->{'real'} =~ /,$/);
	local @cols;
	push(@cols, "") if ($anyedit && $u->{'noedit'});
	push(@cols, &user_link($u));
	push(@cols, $u->{'uid'});
	push(@cols, &html_escape($gidgrp{$u->{'gid'}} || $u->{'gid'}));
	push(@cols, &html_escape($u->{'real'}));
	push(@cols, &html_escape($u->{'home'}));
	push(@cols, &html_escape($u->{'shell'}));
	if ($lshow) {
		# Show last login, in local format after Unix time conversion
		my $ll = $llogin->{$u->{'user'}};
		if (defined(&mailboxes::parse_mail_date)) {
			my $tm = &mailboxes::parse_mail_date($ll);
			if ($tm) {
				$ll = &make_date($tm);
				}
			}
		push(@cols, &html_escape($ll));
		}
	if ($u->{'noedit'}) {
		print &ui_columns_row(\@cols, \@tds);
		}
	else {
		print &ui_checked_columns_row(\@cols, \@tds, "d", $u->{'user'});
		}
	}
print &ui_columns_end();
print &ui_links_row(\@linksrow);
if ($anyedit) {
	print $buttons;
	print &ui_form_end();
	}
}

=head2 groups_table(&groups, [form], [no-buttons], [&otherlinks], [&rightlinks])

Prints a table of groups, possibly with checkboxes and a delete button

=cut
sub groups_table
{
local ($groups, $formno, $noboxes, $links, $rightlinks) = @_;

# Work out if any groups can be edited or have descriptions
local $anyedit;
local $anydesc;
foreach my $g (@$groups) {
	if (!$g->{'noedit'}) {
		$anyedit = 1;
		}
	if ($g->{'desc'}) {
		$anydesc = 1;
		}
	}
$anyedit = 0 if ($noboxes);

local @linksrow;
if ($anyedit && $access{'gdelete'}) {
	print &ui_form_start("mass_delete_group.cgi", "post");
	push(@linksrow, &select_all_link("gd", $formno),
			&select_invert_link("gd", $formno) );
	}
push(@linksrow, @$links);
local @grid = ( &ui_links_row(\@linksrow), &ui_links_row($rightlinks) );
print &ui_grid_table(\@grid, 2, 100, [ "align=left", "align=right" ]);

local @tds = $anyedit ? ( "width=5" ) : ( );
push(@tds, "width=15%", "width=10%");
print &ui_columns_start([
	$anyedit ? ( "" ) : ( ),
	$text{'gedit_group'},
	$text{'gedit_gid'},
	$anydesc ? ( $text{'gedit_desc'} ) : ( ),
	$text{'gedit_members'} ], 100, 0, \@tds);
local $g;
foreach $g (@$groups) {
	local $members = join(" ", split(/,/, $g->{'members'}));
	local @cols;
	if ($anyedit && ($g->{'noedit'} || !$access{'gdelete'})) {
		# Need an explicity blank first column
		push(@cols, "");
		}
	push(@cols, &group_link($g));
	push(@cols, $g->{'gid'});
	if ($anydesc) {
		push(@cols, &html_escape($g->{'desc'}));
		}
	push(@cols, &html_escape($members));
	if ($g->{'noedit'} || !$access{'gdelete'}) {
		print &ui_columns_row(\@cols, \@tds);
		}
	else {
		print &ui_checked_columns_row(\@cols, \@tds, "gd",
					      $g->{'group'});
		}
	}
print &ui_columns_end();
print &ui_links_row(\@linksrow);
if ($anyedit && $access{'gdelete'}) {
	print &ui_submit($text{'index_gmass'}, "delete"),"<br>\n";
	print &ui_form_end();
	}
}

=head2 date_input(day, month, year, prefix)

Returns HTML for selecting a date

=cut
sub date_input
{
local ($d, $m, $y, $prefix) = @_;
local $rv;
$rv .= &ui_textbox($prefix."d", $d, 3)."/";
$rv .= &ui_select($prefix."m", $m,
		[ map { [ $_, $text{"smonth_".$_} ] } (1..12) ])."/";
$rv .= &ui_textbox($prefix."y", $y, 5);
$rv .= &date_chooser_button($prefix."d", $prefix."m", $prefix."y");
return $rv;
}

=head2 list_last_logins([user], [max])

Returns a list of array references, each containing the details of a login.

=cut
sub list_last_logins
{
local @rv;
&open_last_command(LAST, $_[0]);
while(@last = &read_last_line(LAST)) {
	push(@rv, [ @last ]);
	if ($_[1] && scalar(@rv) >= $_[1]) {
		last;	# reached max
		}
	}
close(LAST);
return @rv;
}

=head2 get_recent_logins()

Returns a hash ref from username to most recent login time/date

=cut
sub get_recent_logins
{
if (defined(&os_most_recent_logins)) {
	return &os_most_recent_logins();
	}
else {
	my %rv;
	foreach my $l (&list_last_logins()) {
		$rv{$l->[0]} ||= $l->[3];
		}
	return \%rv;
	}
}

=head2 user_link(&user)

Returns a link to a user editing form. Mainly for internal use.

=cut
sub user_link
{
if ($_[0]->{'pass'} =~ /^\Q$disable_string\E/) {
	$dis = "<i>".&html_escape($_[0]->{'user'})."</i>";
	}
else {
	$dis = &html_escape($_[0]->{'user'});
	}
if ($_[0]->{'noedit'}) {
	return $dis;
	}
elsif ($_[0]->{'dn'}) {
	return &ui_link("edit_user.cgi?dn=".&urlize($_[0]->{'dn'}), $dis);
	}
else {
	return &ui_link("edit_user.cgi?user=".&urlize($_[0]->{'user'}), $dis);
	}
}

=head2 group_link(&group)

Returns a link to a group editing form. Mainly for internal use.

=cut
sub group_link
{
if ($_[0]->{'noedit'}) {
	return &html_escape($_[0]->{'group'});
	}
elsif ($_[0]->{'dn'}) {
	return &ui_link("edit_group.cgi?dn=".&urlize($_[0]->{'dn'}), &html_escape($_[0]->{'group'}) );
	}
else {
	return &ui_link("edit_group.cgi?group=".&urlize($_[0]->{'group'}), &html_escape($_[0]->{'group'}) );
	}
}

=head2 sort_users(&users, mode)

Sorts a list of users according to the user's preference for this module,
and returns the results.

=cut
sub sort_users
{
local ($users, $mode) = @_;
local @ulist = @$users;
if ($mode == 1) {
	@ulist = sort { $a->{'user'} cmp $b->{'user'} } @ulist;
	}
elsif ($mode == 2) {
	@ulist = sort { lc($a->{'real'}) cmp lc($b->{'real'}) } @ulist;
	}
elsif ($mode == 3) {
	@ulist = sort { @wa = split(/\s+/, $a->{'real'});
			@wb = split(/\s+/, $b->{'real'});
			lc($wa[@wa-1]) cmp lc($wb[@wb-1]) } @ulist;
	}
elsif ($mode == 4) {
	@ulist = sort { $a->{'shell'} cmp $b->{'shell'} } @ulist;
	}
elsif ($mode == 5) {
	@ulist = sort { $a->{'uid'} <=> $b->{'uid'} } @ulist;
	}
elsif ($mode == 6) {
	@ulist = sort { $a->{'home'} cmp $b->{'home'} } @ulist;
	}
return @ulist;
}

=head2 sort_groups(&groups, mode)

Sorts a list of groups according to the user's preference for this module,
and returns the results.

=cut
sub sort_groups
{
local ($groups, $mode) = @_;
local @glist = @$groups;
if ($mode == 5) {
	@glist = sort { $a->{'gid'} <=> $b->{'gid'} } @glist;
	}
elsif ($mode == 1) {
	@glist = sort { $a->{'group'} cmp $b->{'group'} } @glist;
	}
return @glist;
}

=head2 create_home_directory(&user, [real-dir])

Creates and chmod's the home directory for a user, or calls error on failure.

=cut
sub create_home_directory
{
local ($user, $home) = @_;
$home ||= $user->{'home'};
&lock_file($home);
&make_dir($home, oct($config{'homedir_perms'}), 1) ||
	&error(&text('usave_emkdir', $!));
&set_ownership_permissions($user->{'uid'}, $user->{'gid'},
			   oct($config{'homedir_perms'}), $home) ||
	&error(&text('usave_echmod', $!));
if ($config{'selinux_con'} && &is_selinux_enabled() && &has_command("chcon")) {
	if ($config{'selinux_con'} eq "*") {
		# Restore default context
		&system_logged("restorecon -r ".
			       quotemeta($home)." >/dev/null 2>&1");
		}
	else {
		# Use specific context
		&system_logged("chcon ".quotemeta($config{'selinux_con'}).
			       " ".quotemeta($home)." >/dev/null 2>&1");
		}
	}
&unlock_file($home);
}

=head2 delete_home_directory(&user)

Deletes some users home directory.

=cut
sub delete_home_directory
{
local ($user) = @_;
if ($user->{'home'} && -d $user->{'home'}) {
	local $realhome = &resolve_links($user->{'home'});
	local $qhome = quotemeta($realhome);
	if ($config{'delete_only'}) {
		&system_logged("find $qhome ! -type d -user $user->{'uid'} | xargs rm -f >/dev/null 2>&1");
		&system_logged("find $qhome -type d -user $user->{'uid'} | xargs rmdir >/dev/null 2>&1");
		&unlink_file($realhome);
		}
	else {
		&system_logged("rm -rf $qhome >/dev/null 2>&1");
		}
	unlink($user->{'home'});	# in case of links
	}
}

=head2 supports_temporary_disable

Returns 1 if temporary locking of passwords (with an ! at the start of the
hash) is supported on this OS.

=cut
sub supports_temporary_disable
{
return &passfiles_type() != 7;    # Not on OSX, which has a fixed-size hash
}

=head2 change_all_home_groups(old-gid, new-gid, &members)

Change the GID on all files in the home directories of users whose GID is the
old GID.

=cut
sub change_all_home_groups
{
local ($oldgid, $gid, $mems) = @_;
&my_setpwent();
while(my @uinfo = &my_getpwent()) {
	if ($uinfo[3] == $oldgid || &indexof($uinfo[0], @$mems) >= 0) {
		&recursive_change($uinfo[7], -1, $oldgid, -1, $gid);
		}
	}
&my_endpwent();
}

=head2 generate_random_password()

Returns a randomly generated 15 character password

=cut
sub generate_random_password
{
&seed_random();
my $rv;
foreach (1 .. 15) {
	$rv .= $random_password_chars[rand(scalar(@random_password_chars))];
	}
return $rv;
}

1;
