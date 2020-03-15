#!/usr/local/bin/perl
# batch_exec.cgi
# Execute create/modify/delete commands in a batch file

require './user-lib.pl';
$access{'batch'} || &error($text{'batch_ecannot'});
if ($ENV{'REQUEST_METHOD'} eq 'GET') {
	&ReadParse();
	}
else {
	&ReadParseMime();
	}
if ($in{'source'} == 0) {
	$data = $in{'file'};
	$data =~ /\S/ || &error($text{'batch_efile'});
	}
elsif ($in{'source'} == 1) {
	open(LOCAL, "<$in{'local'}") || &error($text{'batch_elocal'});
	while(<LOCAL>) {
		$data .= $_;
		}
	close(LOCAL);
	}
elsif ($in{'source'} == 2) {
	$data = $in{'text'};
	$data =~ /\S/ || &error($text{'batch_etext'});
	}

&ui_print_unbuffered_header(undef, $text{'batch_title'}, "");

# Force defaults for save options
$in{'makehome'} = 1 if (!$access{'makehome'});
$in{'copy'} = 1 if (!$access{'copy'} && $config{'user_files'} =~ /\S/);
$in{'movehome'} = 1 if (!$access{'movehome'});
$in{'chuid'} = 1 if (!$access{'chuid'});
$in{'chgid'} = 1 if (!$access{'chgid'});

# Work out a good base UID for new users
&build_user_used(\%used, undef, \%taken);
$newuid = int($config{'base_uid'} > $access{'lowuid'} ?
	      $config{'base_uid'} : $access{'lowuid'});

# Work out a good base GID for new groups
&build_group_used(\%gused, \%gtaken);
if ($config{'new_user_gid'}) {
	%used = ( %used, %gused );
	}
$newgid = int($config{'base_gid'} > $access{'lowgid'} ?
	      $config{'base_gid'} : $access{'lowgid'});
@glist = &list_groups();

# Process the file
&batch_start() if ($in{'batch'});
&lock_user_files();
$lnum = $created = $modified = $deleted = 0;
print "<pre>\n";
$pft = &passfiles_type();
foreach $line (split(/[\r\n]+/, $data)) {
	$lnum++;
	$line =~ s/^\s*#.*$//;
	next if ($line !~ /\S/);
	local @line = split(/:/, $line, -1);
	local %user;
	if ($line[0] eq 'create') {
		# Creating a new user
		if ($pft == 5) {
			# Openserver passwd and short shadow information
			if (@line != 10) {
				print &text('batch_elen', $lnum, 10),"\n";
				next;
				}
			$user{'min'} = $line[8];
			$user{'max'} = $line[9];
			}
		elsif ($pft == 4) {
			# AIX passwd and security information
			if (@line != 12) {
				print &text('batch_elen', $lnum, 12),"\n";
				next;
				}
			$user{'min'} = $line[8];
			$user{'max'} = $line[9];
			$user{'expire'} = $line[10];
			map { $user{$_}++ } split(/\s+/, $line[11]);
			}
		elsif ($pft == 2) {
			# SYSV-style passwd and shadow information
			if (@line != 13) {
				print &text('batch_elen', $lnum, 13),"\n";
				next;
				}
			$user{'min'} = $line[8];
			$user{'max'} = $line[9];
			$user{'warn'} = $line[10];
			$user{'inactive'} = $line[11];
			$user{'expire'} = $line[12];
			$user{'change'} = $line[2] eq '' ? '' :
						int(time() / (60*60*24));
			}
		elsif ($pft == 1 || $pft == 6) {
			# BSD master.passwd information
			if (@line != 11) {
				print &text('batch_elen', $lnum, 11),"\n";
				next;
				}
			$user{'class'} = $line[8];
			$user{'change'} = $line[9];
			$user{'expire'} = $line[10];
			}
		else {
			# Classic passwd file information (type 0 and 3)
			if (@line != 8) {
				print &text('batch_elen', $lnum, 8),"\n";
				next;
				}
			}

		# Make sure all min/max fields are numeric
		$err = &validate_batch_minmax(\%user, $lnum);
		if ($err) {
			print $err,"\n";
			next;
			}

		# Parse common fields
		if (!$line[1]) {
			print &text('batch_eline', $lnum),"\n";
			next;
			}
		$user{'user'} = $line[1];
		$err = &check_username_restrictions($user{'user'});
		if ($err) {
			print &text('batch_echeck', $lnum, $err),"\n";
			next;
			}
		if ($taken{$user{'user'}}) {
			print &text('batch_euser', $lnum, $user{'user'}),"\n";
			next;
			}
		if ($line[3] !~ /^\d+$/) {
			# make up a UID
			while($used{$newuid}) {
				$newuid++;
				}
			$user{'uid'} = $newuid;
			}
		else {
			# use the given UID
			if ($used{$line[3]} && !$access{'umultiple'}) {
				print &text('batch_ecaccess', $lnum,
					    $text{'usave_euidused2'}),"\n";
				next;
				}
			$user{'uid'} = $line[3];
			}
		$used{$user{'uid'}}++;
		if ($line[7] !~ /^\//) {
			print &text('batch_eshell', $lnum, $line[7]),"\n";
			next;
			}
		$user{'shell'} = $line[7];
		$user{'real'} = $line[5];
		local @gids = split(/[ ,]+/, $line[4]);
		$user{'gid'} = $gids[0];
		local $grp = &my_getgrgid($gids[0]);

		$real_home = undef;
		if ($access{'autohome'}) {
			# Assign home dir automatically based on ACL
			$user{'home'} = &auto_home_dir($access{'home'},
						       $user{'user'},
						       $grp);
			if ($config{'real_base'}) {
				$real_home = &auto_home_dir(
				    $config{'real_base'}, $user{'user'}, $grp);
				}
			}
		else {
			if ($line[6] eq '' && $config{'home_base'}) {
				# Choose home dir automatically based on
				# module config
				$user{'home'} = &auto_home_dir(
					$config{'home_base'}, $user{'user'},
					$user{'gid'});
				if ($config{'real_base'}) {
					$real_home = &auto_home_dir(
					    $config{'real_base'},
					    $user{'user'}, $grp);
					}
				}
			elsif ($line[6] !~ /^\//) {
				print &text('batch_ehome', $lnum,$line[6]),"\n";
				next;
				}
			else {
				# Use given home dir
				$user{'home'} = $line[6];
				}
			}
		$real_home ||= $user{'home'};

		# Check access control restrictions
		if (!$access{'ucreate'}) {
			print &text('batch_ecaccess', $lnum,
				    $text{'usave_ecreate'});
			next;
			}
		local $ch = &check_user(\%user);
		if ($ch) {
			print &text('batch_ecaccess', $lnum, $ch),"\n";
			next;
			}

		# Work out secondary group membership
		local @secs;
		if (@gids > 1) {
			local $i;
			for($i=1; $i<@gids; $i++) {
				local ($group) =
				    grep { $_->{'gid'} eq $gids[$i] } @glist;
				push(@secs, $group) if ($group);
				}
			}

		# Work out the password
		if ($in{'crypt'}) {
			$user{'pass'} = $line[2];
			$user{'passmode'} = 2;
			}
		elsif ($line[2] eq 'x') {
			# No login allowed
			$user{'pass'} = $config{'lock_string'};
			$user{'passmode'} = 1;
			}
		elsif ($line[2] eq '') {
			# No password needed
			$user{'pass'} = '';
			$user{'passmode'} = 0;
			}
		else {
			# Normal password
			$user{'pass'} = &encrypt_password($line[2]);
			$user{'passmode'} = 3;
			$user{'plainpass'} = $line[2];
			}

		# Run the before command
		&set_user_envs(\%user, 'CREATE_USER', $user{'plainpass'},
			       [ map { $_->{'gid'} } @secs ]);
		$merr = &making_changes();
		&error(&text('usave_emaking', "<tt>$merr</tt>"))
			if (defined($merr));

		if ($user{'gid'} !~ /^\d+$/) {
			# Need to create a new group for the user
			if (!$access{'gcreate'}) {
				print &text('batch_ecaccess', $lnum,
					    $text{'usave_egcreate'}),"\n";
				next;
				}
			if ($gtaken{$user{'user'}}) {
				print &text('batch_egtaken', $lnum,
					    $user{'user'}),"\n";
				next;
				}

			if ($config{'new_user_gid'}) {
				$newgid = $user{'uid'};
				}
			else {
				while($gused{$newgid}) {
					$newgid++;
					}
				}
			local %group;
			$group{'group'} = $user{'user'};
			$user{'gid'} = $group{'gid'} = $newgid;
			&create_group(\%group);
			$gused{$group{'gid'}}++;
			}

		# Create the user!
		if ($in{'makehome'} && !-d $user{'home'}) {
			&create_home_directory(\%user, $real_home);
			}
		&create_user(\%user);

		# Add user to some secondary groups
		local $group;
		foreach $group (@secs) {
			local @mems = split(/,/ , $group->{'members'});
			push(@mems, $user{'user'});
			$group->{'members'} = join(",", @mems);
			&modify_group($group, $group);
			}

		# All done
		&made_changes();

		# Call other modules, ignoring any failures
		$error_must_die = 1;
		eval {
			&other_modules("useradmin_create_user", \%user)
				if ($access{'cothers'} == 1 && $in{'others'} ||
				    $access{'cothers'} == 0);
			};
		$other_err = $@;
		$error_must_die = 0;

		if ($in{'copy'} && $in{'makehome'}) {
			# Copy files to user's home directory
			local $groupname = &my_getgrgid($user{'gid'});
			local $uf = &get_skel_directory(\%user, $groupname);
			&copy_skel_files($uf, $user{'home'},
					 $user{'uid'}, $user{'gid'});
			}

		print "<b>",&text('batch_created',$user{'user'}),"</b>\n";
		print "<b><i>",&text('batch_eother', $other_err),"</i></b>\n"
			if ($other_err);
		$created++;
		}
	elsif ($line[0] eq 'delete') {
		# Deleting an existing user
		if (@line != 2) {
			print &text('batch_elen', $lnum, 2),"\n";
			next;
			}
		local @ulist = &list_users();
		local ($user) = grep { $_->{'user'} eq $line[1] } @ulist;
		if (!$user) {
			print &text('batch_enouser', $lnum, $line[1]),"\n";
			next;
			}
		if (!&can_edit_user(\%access, $user)) {
			print &text('batch_edaccess', $lnum,
				    $text{'udel_euser'}),"\n";
			next;
			}
		if (!$config{'delete_root'} && $user->{'uid'} <= 10) {
			print &text('batch_edaccess', $lnum,
				    $text{'udel_eroot'}),"\n";
			next;
			}

		# Run the before command
		&set_user_envs($user, 'DELETE_USER', undef,
			       [ &secondary_groups($user->{'user'}) ]);
		$merr = &making_changes();
		&error(&text('usave_emaking', "<tt>$merr</tt>"))
			if (defined($merr));

		# Delete from other modules, ignoring errors
		$error_must_die = 1;
		eval {
			&other_modules("useradmin_delete_user", $user)
				if ($access{'dothers'} == 1 && $in{'others'} ||
				    $access{'dothers'} == 0);
			};
		$other_err = $@;
		$error_must_die = 0;

		# Delete the user entry
		&delete_user($user);

		# Delete the user from groups
		foreach $g (&list_groups()) {
			@mems = split(/,/, $g->{'members'});
			$idx = &indexof($user->{'user'}, @mems);
			if ($idx >= 0) {
				splice(@mems, $idx, 1);
				%newg = %$g;
				$newg{'members'} = join(',', @mems);
				&modify_group($g, \%newg);
				}
			$mygroup = $g if ($g->{'group'} eq $user->{'user'});
			}

		# Delete the user's group
		if ($mygroup && !$mygroup->{'members'}) {
			local $another;
			foreach $ou (&list_users()) {
				$another++
					if ($ou->{'gid'} == $mygroup->{'gid'});
				}
			if (!$another) {
				&delete_group($mygroup);
				}
			}
		&made_changes();

		# Delete his home directory
		if ($in{'delhome'} &&
		    $user->{'home'} &&
		    $user->{'home'} !~ /^\/+$/) {
			&delete_home_directory($user);
			}

		print "<b>",&text('batch_deleted',$user->{'user'}),"</b>\n";
		print "<b><i>",&text('batch_eother', $other_err),"</i></b>\n"
			if ($other_err);
		$deleted++;
		}
	elsif ($line[0] eq 'modify') {
		# Modifying an existing user
		local $wlen = $pft == 5 ? 11 :
			      $pft == 4 ? 13 :
			      $pft == 2 ? 14 :
			      $pft == 1 || $pft == 6 ? 12 : 9;
		if (@line != $wlen) {
			print &text('batch_elen', $lnum, $wlen),"\n";
			next;
			}
		local @ulist = &list_users();
		local ($user) = grep { $_->{'user'} eq $line[1] } @ulist;
		if (!$user) {
			print &text('batch_enouser', $lnum, $line[1]),"\n";
			next;
			}
		%olduser = %user = %$user;
		$user{'olduser'} = $user->{'user'};
		if (!&can_edit_user(\%access, \%user)) {
			print &text('batch_emaccess', $lnum,
				    $text{'usave_eedit'}),"\n";
			next;
			}

		# Update supplied fields
		if ($line[2] ne '') {
			if (!$access{'urename'}) {
				print &text('batch_erename', $lnum, $line[1]),"\n";
				}
			$user{'user'} = $line[2];
			}
		if ($in{'crypt'} && $line[3] ne '') {
			# Changing to pre-encrypted password
			$user{'pass'} = $line[3];
			$user{'passmode'} = 2;
			}
		elsif ($line[3] eq 'x') {
			# No login allowed
			$user{'pass'} = $config{'lock_string'};
			$user{'passmode'} = 1;
			}
		elsif ($line[3] ne '') {
			# Normal password
			$user{'pass'} = &encrypt_password($line[3]);
			$user{'passmode'} = 3;
			$user{'plainpass'} = $line[3];
			}
		else {
			# No change
			$user{'passmode'} = 4;
			}
		$user{'uid'} = $line[4] if ($line[4] ne '');
		$user{'gid'} = $line[5] if ($line[5] ne '');
		$user{'real'} = $line[6] if ($line[6] ne '');
		$user{'home'} = $line[7] if ($line[7] ne '');
		$user{'shell'} = $line[8] if ($line[8] ne '');
		if ($access{'peopt'}) {
			if ($pft == 5) {
				# Openserver password and short shadow
				$user{'min'}=$line[9] if ($line[9] ne '');
				$user{'max'}=$line[10] if ($line[10] ne '');
				$user{'change'}=int(time() / (60*60*24))
					if ($line[3] ne '');
				}
			elsif ($pft == 4) {
				# AIX password and security information
				$user{'min'}=$line[9] if ($line[9] ne '');
				$user{'max'}=$line[10] if ($line[10] ne '');
				$user{'expire'}=$line[11] if ($line[11] ne '');
				if ($line[12] ne '') {
					delete($user{'admin'});
					delete($user{'admchg'});
					delete($user{'nocheck'});
					map { $user{$_}++ }
					    split(/\s+/, $line[12]);
					}
				$user{'change'}=time() if ($line[3] ne '');
				}
			elsif ($pft == 2) {
				# SYSV-style passwd and shadow information
				$user{'min'}=$line[9] if ($line[9] ne '');
				$user{'max'}=$line[10] if ($line[10] ne '');
				$user{'warn'}=$line[11] if ($line[11] ne '');
				$user{'inactive'}=$line[12]
					if ($line[12] ne '');
				$user{'expire'}=$line[13] if ($line[13] ne '');
				$user{'change'}=int(time() / (60*60*24))
					if ($line[3] ne '');
				}
			elsif ($pft == 1 || $pft == 6) {
				# BSD master.passwd information
				$user{'class'}=$line[9] if ($line[9] ne '');
				$user{'change'}=$line[10] if ($line[10] ne '');
				$user{'expire'}=$line[11] if ($line[11] ne '');
				}
			}

		# Check access control restrictions
		local $ch = &check_user(\%user, \%olduser);
		if ($ch) {
			print &text('batch_emaccess', $lnum, $ch),"\n";
			next;
			}

		# Run the before command
		&set_user_envs(\%user, 'MODIFY_USER', $user{'plainpass'},
			       [ &secondary_groups($user{'user'}) ]);
		$merr = &making_changes();
		&error(&text('usave_emaking', "<tt>$merr</tt>"))
			if (defined($merr));

		# Move home directory if needed
		if ($olduser{'home'} ne $user{'home'} && $in{'movehome'} &&
		    $user{'home'} ne '/' && $olduser{'home'} ne '/') {
			if (-d $olduser{'home'} && !-e $user{'home'}) {
				local $out = &backquote_logged(
					"mv \"$olduser{'home'}\" ".
					"\"$user{'home'}\" 2>&1");
				if ($?) { &error(&text('batch_emove',
						 $lnum, $out)); }
				}
			}

		# Change UIDs and GIDs
		if ($olduser{'gid'} != $user{'gid'} && $in{'chgid'}) {
			if ($in{'chgid'} == 1) {
				&recursive_change($user{'home'},$olduser{'uid'},
					  $olduser{'gid'}, -1, $user{'gid'});
				}
			else {
				&recursive_change("/", $olduser{'uid'},
					  $olduser{'gid'}, -1, $user{'gid'});
				}
			}
		if ($olduser{'uid'} != $user{'uid'} && $in{'chuid'}) {
			if ($in{'chuid'} == 1) {
				&recursive_change($user{'home'},$olduser{'uid'},
						  -1, $user{'uid'}, -1);
				}
			else {
				&recursive_change("/", $olduser{'uid'},
						  -1, $user{'uid'}, -1);
				}
			}

		# Actually modify the user
		&modify_user(\%olduser, \%user);

		# If the user has been renamed, update any secondary groups
		if ($olduser{'user'} ne $user{'user'}) {
			foreach $group (@glist) {
				local @mems = split(/,/, $group->{'members'});
				local $idx = &indexof($olduser{'user'}, @mems);
				if ($idx >= 0) {
					$mems[$idx] = $user{'user'};
					$group->{'members'} = join(",", @mems);
					&modify_group($group, $group);
					}
				}
			}

		&made_changes();

		# Modify in other modules, ignoring errors
		$error_must_die = 1;
		eval {
			&other_modules("useradmin_modify_user",
				       \%user, \%olduser)
				if ($access{'mothers'} == 1 && $in{'others'} ||
				    $access{'mothers'} == 0);
			};
		$error_must_die = 0;
		$other_err = $@;

		print "<b>",&text('batch_modified',$olduser{'user'}),"</b>\n";
		print "<b><i>",&text('batch_eother', $other_err),"</i></b>\n"
			if ($other_err);
		$modified++;
		}
	else {
		print &text('batch_eaction', $lnum, $line[0]),"\n";
		next;
		}
	}
print "</pre>\n";
&batch_end() if ($in{'batch'});
&unlock_user_files();
&webmin_log("batch", undef, $in{'source'} == 1 ? $in{'local'} : undef,
	    { 'created' => $created, 'modified' => $modified,
	      'deleted' => $deleted, 'lnum' => $lnum } );

&ui_print_footer("batch_form.cgi", $text{'batch_return'},
		 "", $text{'index_return'});

# check_user(\%user, [\%olduser])
# Check access control restrictions for a user
sub check_user
{
# check if uid is within range
if ($access{'lowuid'} && $_[0]->{'uid'} < $access{'lowuid'}) {
	return &text('usave_elowuid', $access{'lowuid'});
	}
if ($access{'hiuid'} && $_[0]->{'uid'} > $access{'hiuid'}) {
	return &text('usave_ehiuid', $access{'hiuid'});
	}
if ($_[1] && !$access{'uuid'} && $_[1]->{'uid'} != $_[0]->{'uid'}) {
	return $text{'usave_euuid'};
	}

# make sure home dir is under the allowed root
if (!$access{'autohome'}) {
	$al = length($access{'home'});
	if (length($_[0]->{'home'}) < $al ||
	    substr($_[0]->{'home'}, 0, $al) ne $access{'home'}) {
		return &text('usave_ehomepath', $_[0]->{'home'});
		}
	}

# check for invalid shell
if ($access{'shells'} ne '*' &&
    &indexof($_[0]->{'shell'}, split(/\s+/, $access{'shells'})) < 0) {
	return &text('usave_eshell', $_[0]->{'shell'});
	}

# check for invalid primary group (unless one is dynamically assigned)
if ($user{'gid'} ne '') {
	local $ng = &my_getgrgid($_[0]->{'gid'});
	local $ni = &can_use_group(\%access, $ng);
	if ($_[1]) {
		if ($_[1]->{'gid'} != $_[0]->{'gid'}) {
			local $og = &my_getgrgid($_[1]->{'gid'});
			local $oi = &can_use_group(\%access, $og);
			if (!$ni) { return &text('usave_eprimary', $ng); }
			if (!$oi) { return &text('usave_eprimaryr', $og); }
			}
		}
	else {
		return &text('usave_eprimary', $ng) if (!$ni);
		}
	}
return undef;
}

sub secondary_groups
{
local @secs;
foreach $g (@glist) {
	@mems = split(/,/, $g->{'members'});
	if (&indexof($_[0], @mems) >= 0) {
		push(@secs, $g->{'gid'});
		}
	}
return @secs;
}

sub validate_batch_minmax
{
local ($user, $lnum) = @_;
foreach my $f ('min', 'max', 'warn', 'inactive', 'expire', 'change') {
	$user->{$f} =~ /^(\-|\+|)\d*$/ ||
		return &text('batch_e'.$f, $lnum, $user->{$f});
	}
return undef;
}

