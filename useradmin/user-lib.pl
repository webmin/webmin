# user-lib.pl
# Common functions for Unix user management

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
if ($gconfig{'os_type'} =~ /-linux$/) {
	do "linux-lib.pl";
	}
else {
	do "$gconfig{'os_type'}-lib.pl";
	}
do "md5-lib.pl";

@random_password_chars = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9' );
$disable_string = $config{'lock_prepend'} eq "" ? "!" : $config{'lock_prepend'};

# password_file(file)
# Returns true if some file looks like a valid Unix password file
sub password_file
{
if (!$_[0]) { return 0; }
elsif (&open_readfile(SHTEST, $_[0])) {
	local($line);
	$line = <SHTEST>;
	close(SHTEST);
	return $line =~ /^\S+:\S*:/;
	}
else { return 0; }
}

# list_users()
# Returns an array of hashtable, each containing info about one user. Each hash
# will always contain the keys
#  user, pass, uid, gid, real, home, shell
# In addition, if the system supports shadow passwords it may also have:
#  change, min, max, warn, inactive, expire
# Or if it supports FreeBSD master.passwd info, it will also have
#  class, change, expire
sub list_users
{
return @list_users_cache if (defined(@list_users_cache));

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
					$lastuser->{'expire'} =~ s/^0$//;
					}
				elsif ($1 eq 'minage') {
					$lastuser->{'min'} = $2;
					$lastuser->{'min'} =~ s/^0$//;
					}
				elsif ($1 eq 'maxage') {
					$lastuser->{'max'} = $2;
					$lastuser->{'max'} =~ s/^0$//;
					}
				elsif ($1 eq 'pwdwarntime') {
					$lastuser->{'warn'} = $2;
					$lastuser->{'warn'} =~ s/^0$//; 
					}
				}
			}
		close(USER);
		}
	}
@list_users_cache = @rv;
return @rv;
}

# create_user(&details)
# Creates a new user with the given details
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
	if (defined(@list_users_cache)) {
		map { $_->{'line'}++ if ($_->{'line'} >= $_[0]->{'line'}) }
		    @list_users_cache;
		}
	}
elsif ($pft == 3) {
	# Just invoke the useradd command
	&system_logged("useradd -u $_[0]->{'uid'} -g $_[0]->{'gid'} -c \"$_[0]->{'real'}\" -d $_[0]->{'home'} -s $_[0]->{'shell'} $_[0]->{'user'}");
	# And set the password
	&system_logged("echo $_[0]->{'pass'} | /usr/lib/scoadmin/account/password.tcl $_[0]->{'user'} >/dev/null 2>&1");
	}
elsif ($pft == 6) {
	# Use the niutil command
	&system_logged("niutil -create '$netinfo_domain' '/users/$_[0]->{'user'}'");
	&set_netinfo($_[0]);
	}
else {
	# add to /etc/passwd
	$lref = &read_file_lines($config{'passwd_file'});
	$_[0]->{'line'} = &nis_index($lref);
	if (defined(@list_users_cache)) {
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
		if (defined(@list_users_cache)) {
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
push(@list_users_cache, $_[0]) if (defined(@list_users_cache));
&refresh_nscd() if (!$batch_mode);
}

# modify_user(&old, &details)
sub modify_user
{
$_[0] || &error("Missing parameter to modify_user");
local(@passwd, @shadow, $lref);
local $pft = &passfiles_type();
if ($pft == 1) {
	# just need to update master.passwd
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
else {
	# update /etc/passwd
	$lref = &read_file_lines($config{'passwd_file'});
	$lref->[$_[0]->{'line'}] =
		"$_[1]->{'user'}:".
		($pft == 2 || $pft == 5 ? "x" : $pft == 4 ? "!" :
		 $_[1]->{'pass'}).
		":$_[1]->{'uid'}:$_[1]->{'gid'}:$_[1]->{'real'}:".
		"$_[1]->{'home'}:$_[1]->{'shell'}";
	if ($pft == 2) {
		# update shadow file as well..
		$lref = &read_file_lines($config{'shadow_file'});
		$lref->[$_[0]->{'sline'}] =
			"$_[1]->{'user'}:$_[1]->{'pass'}:$_[1]->{'change'}:".
			"$_[1]->{'min'}:$_[1]->{'max'}:$_[1]->{'warn'}:".
			"$_[1]->{'inactive'}:$_[1]->{'expire'}:";
		}
	elsif ($pft == 5) {
		# update SCO shadow
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
		$_[1]->{'expire'} = '' if (! $_[1]->{'expire'}); 
		$_[1]->{'min'} = '' if (! $_[1]->{'min'}); 
		$_[1]->{'max'} = '' if (! $_[1]->{'max'}); 
		$_[1]->{'warn'} = '' if (! $_[1]->{'warn'}); 
		&system_logged("chuser expires=$_[1]->{'expire'} minage=$_[1]->{'min'} maxage=$_[1]->{'max'} pwdwarntime=$_[1]->{'warn'} $_[1]->{'user'}");
		}
	}
if ($_[0] ne $_[1] && &indexof($_[0], @list_users_cache) != -1) {
	# Update old object in cache
	$_[1]->{'line'} = $_[0]->{'line'} if (defined($_[0]->{'line'}));
	$_[1]->{'sline'} = $_[0]->{'sline'} if (defined($_[0]->{'sline'}));
	$_[1]->{'seline'} = $_[0]->{'seline'} if (defined($_[0]->{'seline'}));
	%{$_[0]} = %{$_[1]};
	}
if (!$batch_mode) {
	&flush_file_lines();
	&refresh_nscd();
	}
}

# delete_user(&details)
sub delete_user
{
local $lref;
$_[0] || &error("Missing parameter to delete_user");
local $pft = &passfiles_type();
if ($pft == 1) {
	# Delete from BSD master.passwd file
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
else {
	# XXX doesn't delete from AIX file!
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
	if (defined(@list_users_cache));
if (!$batch_mode) {
	&flush_file_lines();
	&refresh_nscd();
	}
}

# list_groups()
# Returns a list of all the local groups as an array of hashtables. Each
# will contain group, pass, gid, members
sub list_groups
{
return @list_groups_cache if (defined(@list_groups_cache));

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

# create_group(&details)
sub create_group
{
local $gft = &groupfiles_type();
if ($gft == 5) {
	# Use niutil command
	&system_logged("niutil -create '$netinfo_domain' '/groups/$_[0]->{'group'}'");
	&set_group_netinfo($_[0]);
	}
else {
	# Update group file(s)
	local $lref;
	$lref = &read_file_lines($config{'group_file'});
	$_[0]->{'line'} = &nis_index($lref);
	if (defined(@list_groups_cache)) {
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
		if (defined(@list_groups_cache)) {
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
push(@list_groups_cache, $_[0]) if (defined(@list_groups_cache));
}

# modify_group(&old, &details)
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
	%{$_[0]} = %{$_[1]};
	}
&refresh_nscd();
}

# delete_group(&details)
sub delete_group
{
$_[0] || &error("Missing parameter to delete_group");
local $gft = &groupfiles_type();
if ($gft == 5) {
	# Call niutil to delete
	&system_logged("niutil -destroy '$netinfo_domain' '/groups/$_[0]->{'group'}'");
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
	if (defined(@list_groups_cache));
&refresh_nscd();
}


############################################################################
# Misc functions
############################################################################
# recursive_change(dir, olduid, oldgid, newuid, newgid)
# Change the UID or GID of a directory and all files in it, if they match the
# given UID/GID
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

# making_changes()
# Called before changes are made to the password or group file
sub making_changes
{
if ($config{'pre_command'} =~ /\S/) {
	local $out = &backquote_logged("($config{'pre_command'}) 2>&1 </dev/null");
	return $? ? $out : undef;
	}
return undef;
}

# made_changes()
# Called after the password or group file has been changed, to run the
# post-changes command.
sub made_changes
{
if ($config{'post_command'} =~ /\S/) {
	local $out = &backquote_logged("($config{'post_command'}) 2>&1 </dev/null");
	return $? ? $out : undef;
	}
return undef;
}

# other_modules(function, arg, ...)
# Call some function in the useradmin_update.pl file in other modules
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

# can_edit_user(&acl, &user)
sub can_edit_user
{
local $m = $_[0]->{'uedit_mode'};
local %u;
if ($m == 0) { return 1; }
elsif ($m == 1) { return 0; }
elsif ($m == 2 || $m == 3 || $m == 5) {
	map { $u{$_}++ } split(/\s+/, $_[0]->{'uedit'});
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

# can_edit_group(&acl, &group)
sub can_edit_group
{
local $m = $_[0]->{'gedit_mode'};
local %g;
if ($m == 0) { return 1; }
elsif ($m == 1) { return 0; }
elsif ($m == 2 || $m == 3) {
	map { $g{$_}++ } split(/\s+/, $_[0]->{'gedit'});
	return $m == 2 ? $g{$_[1]->{'group'}}
		       : !$g{$_[1]->{'group'}};
	}
else { return (!$_[0]->{'gedit'} || $_[1]->{'gid'} >= $_[0]->{'gedit'}) &&
	      (!$_[0]->{'gedit2'} || $_[1]->{'gid'} <= $_[0]->{'gedit2'}); }
}

# nis_index(&lines)
sub nis_index
{
local $i;
for($i=0; $i<@{$_[0]}; $i++) {
	last if ($_[0]->[$i] =~ /^[\+\-]/);
	}
return $i;
}

# get_skel_directory(&user, groupname)
# Returns the skeleton files directory for some user
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

# copy_skel_files(source, dest, uid, gid)
sub copy_skel_files
{
local ($f, $df);
local @rv;
foreach $f (split(/\s+/, $_[0])) {
	if (-d $f) {
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

# copy_file(file, destdir, uid, gid)
# Copy a file or directory and chown it
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
	@rv = glob("$_[1]/$base/*");
	}
else {
	# Just a normal file .. copy it
	local @st = stat(&translate_filename($_[0]));
	&system_logged("cp ".quotemeta($_[0])." ".quotemeta("$_[1]/$base")." >/dev/null 2>/dev/null");
	&set_ownership_permissions($_[2], $_[3], $st[2], "$_[1]/$base");
	$nochown++;
	}
&system_logged("chown $opts -R $_[2]:$_[3] \"$_[1]/$base\" >/dev/null 2>/dev/null") if (!$nochown);
return @rv;
}

# lock_user_files()
# Lock all password, shadow and group files
sub lock_user_files
{
&lock_file($config{'passwd_file'});
&lock_file($config{'group_file'});
&lock_file($config{'shadow_file'});
&lock_file($config{'gshadow_file'});
&lock_file($config{'master_file'});
}

# unlock_user_files()
# Unlock all password, shadow and group files
sub unlock_user_files
{
&unlock_file($config{'passwd_file'});
&unlock_file($config{'group_file'});
&unlock_file($config{'shadow_file'});
&unlock_file($config{'gshadow_file'});
&unlock_file($config{'master_file'});
}

# Functions similar to the standard password file ones, but which may
# use webmin's reading of the user/group files instead.

sub my_setpwent
{
if ($config{'from_files'}) {
	@setpwent_cache = &list_users();
	$setpwent_pos = 0;
	}
else { return setpwent(); }
}

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

sub pw_user_rv
{
return $_[0] ? ( $_[0]->{'user'}, $_[0]->{'pass'}, $_[0]->{'uid'},
		 $_[0]->{'gid'}, undef, undef, $_[0]->{'real'},
		 $_[0]->{'home'}, $_[0]->{'shell'}, undef ) : $_[0]->{$_[2]};
}

sub my_setgrent
{
if ($config{'from_files'}) {
	@setgrent_cache = &list_groups();
	$setgrent_pos = 0;
	}
else { return setgrent(); }
}

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

# auto_home_dir(base, username, groupname)
# Returns an automatically generated home directory, and creates needed
# parent dirs
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

sub set_group_netinfo
{
local %g = %{$_[0]};
local $mems = join(" ", map { "'$_'" } split(/,/, $g{'members'}));
&system_logged("niutil -createprop '$netinfo_domain' '/groups/$g{'group'}' gid '$g{'gid'}'");
&system_logged("niutil -createprop '$netinfo_domain' '/groups/$g{'group'}' passwd '$g{'pass'}'");
&system_logged("niutil -createprop '$netinfo_domain' '/groups/$g{'group'}' users $mems");
}

# check_password_restrictions(pass, username)
# Returns an error message if the given password fails length and other
# checks, or undef if it is OK
sub check_password_restrictions
{
return &text('usave_epasswd_min', $config{'passwd_min'})
	if (length($_[0]) < $config{'passwd_min'});
local $re = $config{'passwd_re'};
return &text('usave_epasswd_re', $re)
	if ($re && !eval { $_[0] =~ /^$re$/ });
if ($config{'passwd_same'}) {
	return &text('usave_epasswd_same') if ($_[0] =~ /\Q$_[1]\E/i);
	}
if ($config{'passwd_dict'} && $_[0] =~ /^[A-Za-z\'\-]+$/ &&
    (&has_command("ispell") || &has_command("spell"))) {
	# Call spell or ispell to check for dictionary words
	local $temp = &transname();
	open(TEMP, ">$temp");
	print TEMP $_[0],"\n";
	close(TEMP);
	if (&has_command("ispell")) {
		open(SPELL, "ispell -a <$temp |");
		while(<SPELL>) {
			if (/^(#|\&|\?)/) {
				$unknown++;
				}
			}
		close(SPELL);
		}
	else {
		open(SPELL, "spell <$temp |");
		local $line = <SPELL>;
		$unknown++ if ($line);
		close(SPELL);
		}
	unlink($temp);
	return &text('usave_epasswd_dict') if (!$unknown);
	}
if ($config{'passwd_prog'}) {
	# Run external validation program with username and password as args
	local $qu = quotemeta($_[1]);
	local $qp = quotemeta($_[0]);
	local $out = &backquote_command("$config{'passwd_prog'} $qu $qp 2>&1 </dev/null");
	if ($?) {
		return $out;
		}
	}
return undef;
}

# check_username_restrictions(username)
# Returns an error message if a username fails some restriction, or undef
sub check_username_restrictions
{
if ($config{'max_length'} && length($_[0]) > $config{'max_length'}) {
	return &text('usave_elength', $config{'max_length'});
	}
local $re = $config{'username_re'};
return &text('usave_ere', $re)
	if ($re && !eval { $_[0] =~ /^$re$/ });
return undef;
}

# can_use_group(&acl, group)
# Returns 1 if some group can be used as a primary or secondary, 0 if not
sub can_use_group
{
return 1 if ($_[0]->{'ugroups'} eq '*');
local @sp = split(/\s+/, $_[0]->{'ugroups'});
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

# refresh_nscd()
# Sends a HUP signal to the nscd process, so that any caches are reloaded
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
	&system_logged("nscd -i passwd -i group >/dev/null 2>&1 </dev/null");
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

# set_user_envs(&user, action, [plainpass], [secondaries],
#	        [&olduser], [oldplainpass])
# Sets up the USERADMIN_ environment variables for a user update of some kind,
# prior to calling making_changes or made_changes. action must be one of
# CREATE_USER, MODIFY_USER or DELETE_USER
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
$ENV{'USERADMIN_PASS'} = $plainpass if (defined($plainpass));
$ENV{'USERADMIN_SECONDARY'} = join(",", @{$secs}) if (defined($secs));
$ENV{'USERADMIN_ACTION'} = $action;
$ENV{'USERADMIN_SOURCE'} = $main::module_name;
if ($olduser) {
	$ENV{'USERADMIN_OLD_USER'} = $user->{'user'};
	$ENV{'USERADMIN_OLD_UID'} = $user->{'uid'};
	$ENV{'USERADMIN_OLD_REAL'} = $user->{'real'};
	$ENV{'USERADMIN_OLD_SHELL'} = $user->{'shell'};
	$ENV{'USERADMIN_OLD_HOME'} = $user->{'home'};
	$ENV{'USERADMIN_OLD_GID'} = $user->{'gid'};
	$ENV{'USERADMIN_OLD_PASS'} = $oldpass if (defined($oldpass));
	}
}

# set_group_envs(&group, action)
# Sets up the USERADMIN_ environment variables for a group update of some kind,
# prior to calling making_changes or made_changes. action must be one of
# CREATE_GROUP, MODIFY_GROUP or DELETE_GROUP
sub set_group_envs
{
&clear_envs();
$ENV{'USERADMIN_GROUP'} = $_[0]->{'group'};
$ENV{'USERADMIN_GID'} = $_[0]->{'gid'};
$ENV{'USERADMIN_MEMBERS'} = $_[0]->{'members'};
$ENV{'USERADMIN_ACTION'} = $_[1];
$ENV{'USERADMIN_SOURCE'} = $main::module_name;
}

# clear_envs()
# Removes all variables set by set_user_envs and set_group_envs
sub clear_envs
{
local $e;
foreach $e (keys %ENV) {
	delete($ENV{$e}) if ($e =~ /^USERADMIN_/);
	}
}

# encrypt_password(password, [salt])
# Encrypts a password using the encryption format configured for this system
sub encrypt_password
{
local ($pass, $salt) = @_;
local $md5 = 0;
if ($config{'md5'} == 2) {
	# Always use MD5
	$md5 = 1;
	}
elsif ($config{'md5'} == 1 && !$config{'skip_md5'}) {
	# Up to system
	$md5 = &use_md5() if (defined(&use_md5));
	}
if ($no_encrypt_password) {
	# Some operating systems don't do any encryption!
	return $pass;
	}
elsif ($md5) {
	# MD5 encryption is selected .. use it if possible
	local $err = &check_md5();
	if ($err) {
		&header($text{'error'}, "");
		print "<hr><p>\n";
		print &text('usave_edigestmd5',
		    "/config.cgi?$module_name",
		    "/cpan/download.cgi?source=3&cpan=$err"),
		    "<p>\n";
		print "<hr>\n";
		&footer("", $text{'index_return'});
		exit;
		}
	return &encrypt_md5($pass, $salt);
	}
else {
	# Just do old-style crypt() DES encryption
	$salt ||= chr(int(rand(26))+65) . chr(int(rand(26))+65);
	return &unix_crypt($pass, $salt);
	}
}

# build_user_used([&uid-hash], [&shell-list], [&username-hash])
# Fills in a hash with used UIDs and shells
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

# build_group_used([&uid-hash], [&groupname-hash])
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

# allocate_uid(&uids-used)
sub allocate_uid
{
local $rv = int($config{'base_uid'} > $access{'lowuid'} ?
		$config{'base_uid'} : $access{'lowuid'});
while($_[0]->{$rv}) {
	$rv++;
	}
return $rv;
}

# allocate_gid(&gids-used)
sub allocate_gid
{
local $rv = int($config{'base_gid'} > $access{'lowgid'} ?
		$config{'base_gid'} : $access{'lowgid'});
while($_[0]->{$rv}) {
	$rv++;
	}
return $rv;
}

# list_allowed_users(&access, &allusers)
# Returns a list of users to whom access is allowed
sub list_allowed_users
{
local %access = %{$_[0]};
local @ulist = @{$_[1]};
if ($access{'uedit_mode'} == 1) {
	@ulist = ();
	}
elsif ($access{'uedit_mode'} == 2) {
	local %canu;
	map { $canu{$_}++ } split(/\s+/, $access{'uedit'});
	@ulist = grep { $canu{$_->{'user'}} } @ulist;
	}
elsif ($access{'uedit_mode'} == 3) {
	local %cannotu;
	map { $cannotu{$_}++ } split(/\s+/, $access{'uedit'});
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
	map { $cangid{$_}++ } split(/\s+/, $access{'uedit'});
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

# list_allowed_groups(&access, &allgroups)
# Returns a list of groups to whom access is allowed
sub list_allowed_groups
{
local %access = %{$_[0]};
local @glist = @{$_[1]};
if ($access{'gedit_mode'} == 1) {
	@glist = ();
	}
elsif ($access{'gedit_mode'} == 2) {
	local %cang;
	map { $cang{$_}++ } split(/\s+/, $access{'gedit'});
	@glist = grep { $cang{$_->{'group'}} } @glist;
	}
elsif ($access{'gedit_mode'} == 3) {
	local %cannotg;
	map { $cannotg{$_}++ } split(/\s+/, $access{'gedit'});
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

# batch_start()
# Tells the create/modify/delete functions to only update files in memory,
# not on disk.
sub batch_start
{
$batch_mode = 1;
}

# batch_end()
# Flushes any user file changes
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
    if ( length($_[0]) ne 7 ) {
        print "ERROR: Number of characters in username $_[0] is not equal to 7\n";
        return -1;
    }
    if ( ${num_let} ne 3 && ${num_let} ne 4 ) {
        print "ERROR: Number of letters in username $_[0] is not equal to 3 or 4\n";
        return -1;
    }
    my ${mkuid_type} = 10 ** ( 7 - ${num_let} );
    my ${lowlimit} = 1000000;
    my %letters;
    my ${icnt} = -1;
    my ${lowuid};
    ${lowuid} = ( 26 ** ( ${num_let} - 1 ) * ${lowlimit}/100 ) + ${lowlimit};
    ${lowuid} = ${lowlimit} if ( ${num_let} eq 3 );
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

# users_table(&users, [form], [no-last], [no-boxes], [&otherlinks])
# Prints a table listing full user details, with checkboxes and buttons to
# delete or disable multiple at once.
sub users_table
{
local ($users, $formno, $nolast, $noboxes, $links) = @_;

local (@ginfo, %gidgrp);
&my_setgrent();
while(@ginfo = &my_getgrent()) {
	$gidgrp{$ginfo[2]} = $ginfo[0];
	}
&my_endgrent();
local ($anyedit) = grep { !$_->{'noedit'} } @$users;
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
	print $buttons;
	push(@linksrow, &select_all_link("d", $_[1]),
			&select_invert_link("d", $_[1]));
	}
push(@linksrow, @$links);
print &ui_links_row(\@linksrow);

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
local %llogin;
if ($lshow) {
	local $l;
	foreach $l (&list_last_logins()) {
		$llogin{$l->[0]} ||= $l->[3];
		}
	}
local $u;
foreach $u (@$users) {
	$u->{'real'} =~ s/,.*$// if ($config{'extra_real'});
	local @cols;
	push(@cols, "") if ($anyedit && $u->{'noedit'});
	push(@cols, &user_link($u));
	push(@cols, $u->{'uid'});
	push(@cols, $gidgrp{$u->{'gid'}}||$u->{'gid'});
	push(@cols, $u->{'real'});
	push(@cols, $u->{'home'});
	push(@cols, $u->{'shell'});
	push(@cols, $llogin{$u->{'user'}}) if ($lshow);
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

# groups_table(&groups, [form], [no-buttons], [&otherlinks])
sub groups_table
{
local ($groups, $formno, $noboxes, $links) = @_;

local ($anyedit) = grep { !$_->{'noedit'} } @$groups;
$anyedit = 0 if ($noboxes);

local @linksrow;
if ($anyedit && $access{'gdelete'}) {
	print &ui_form_start("mass_delete_group.cgi", "post");
	print &ui_submit($text{'index_gmass'}, "delete"),"<br>\n";
	push(@linksrow, &select_all_link("d", $formno),
			&select_invert_link("d", $formno) );
	}
push(@linksrow, @$links);
print &ui_links_row(\@linksrow);

local @tds = $anyedit ? ( "width=5" ) : ( );
push(@tds, "width=15%", "width=10%");
print &ui_columns_start([
	$anyedit ? ( "" ) : ( ),
	$text{'gedit_group'},
	$text{'gedit_gid'},
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
	push(@cols, &ifblank($members));
	if ($g->{'noedit'} || !$access{'gdelete'}) {
		print &ui_columns_row(\@cols, \@tds);
		}
	else {
		print &ui_checked_columns_row(\@cols, \@tds, "d",$g->{'group'});
		}
	}
print &ui_columns_end();
print &ui_links_row(\@linksrow);
if ($anyedit && $access{'gdelete'}) {
	print &ui_submit($text{'index_gmass'}, "delete"),"<br>\n";
	print &ui_form_end();
	}
}

sub ifblank
{
return $_[0] ? &html_escape($_[0]) : "&nbsp;";
}

# date_input(day, month, year, prefix)
sub date_input
{
print "<input name=$_[3]d size=3 value='$_[0]'>";
print "/<select name=$_[3]m>\n";
local $m;
foreach $m (1..12) {
	printf "<option value=%d %s>%s\n",
		$m, $_[1] eq $m ? 'selected' : '', $text{"smonth_$m"};
	}
print "</select>";
print "/<input name=$_[3]y size=5 value='$_[2]'>";
print &date_chooser_button("$_[3]d", "$_[3]m", "$_[3]y");
}

# list_last_logins([user], [max])
# Returns a list of array references, each containing the details of a login
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

# user_link(&user)
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
	return "<a href='edit_user.cgi?dn=".&urlize($_[0]->{'dn'})."'>".
	       "$dis</a>";
	}
else {
	return "<a href='edit_user.cgi?num=$_[0]->{'num'}'>".
	       "$dis</a>";
	}
}

# group_link(&group)
sub group_link
{
if ($_[0]->{'noedit'}) {
	return &html_escape($_[0]->{'group'});
	}
elsif ($_[0]->{'dn'}) {
	return "<a href='edit_group.cgi?dn=".&urlize($_[0]->{'dn'})."'>".
	       &html_escape($_[0]->{'group'})."</a>";
	}
else {
	return "<a href='edit_group.cgi?num=$_[0]->{'num'}'>".
	       &html_escape($_[0]->{'group'})."</a>";
	}
}

# sort_users(&users, mode)
# Sorts a list of users, and returns the results
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

# sort_groups(&groups, mode)
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

# create_home_directory(&user, [real-dir])
# Creates and chmod's the home directory for a user, or calls error on failure
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
&unlock_file($home);
}

# delete_home_directory(&user)
# Delete's some users home directory
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

1;
