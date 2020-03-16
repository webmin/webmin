#!/usr/local/bin/perl
# batch_exec.cgi
# Execute create/modify/delete commands in a batch file

require './ldap-useradmin-lib.pl';
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

$ldap = &ldap_connect();
$schema = $ldap->schema();
$pft = $schema->attribute("shadowLastChange") ? 2 : 0;
&lock_user_files();

# Work out a good base UID for new users
$newuid = $mconfig{'base_uid'};
$newgid = $mconfig{'base_gid'};
@glist = &list_groups();

# Process the file
$lnum = $created = $modified = $deleted = 0;
print "<pre>\n";
LINE: foreach $line (split(/[\r\n]+/, $data)) {
	$lnum++;
	$line =~ s/^\s*#.*$//;
	next if ($line !~ /\S/);
	local @line = split(/:/, $line, -1);
	local %user;
	if ($line[0] eq 'create') {
		# Creating a new user
		local @attrs;
		if ($pft == 2) {
			# SYSV-style passwd and shadow information
			if (@line < 13) {
				print &text('batch_elen', $lnum, 13),"\n";
				next;
				}
			$user{'min'} = $line[8];
			$user{'max'} = $line[9];
			$user{'warn'} = $line[10];
			$user{'inactive'} = $line[11];
			$user{'expire'} = $line[12];
			if ($in{'forcechange'} == 1){
			    $user{'change'} = 0;
			} else {
			    $user{'change'} = $line[2] eq '' ? '' :
						int(time() / (60*60*24));
			}
			@attrs = @line[13 .. $#line];
			}
		else {
			# Classic passwd file information
			if (@line < 8) {
				print &text('batch_elen', $lnum, 8),"\n";
				next;
				}
			@attrs = @line[9 .. $#line];
			}

		# Parse common fields
		if (!$line[1]) {
			print &text('batch_eline', $lnum),"\n";
			next;
			}
		$user{'user'} = $line[1];
		$err = &useradmin::check_username_restrictions($user{'user'});
		if ($err) {
			print &text('batch_echeck', $lnum, $err),"\n";
			next;
			}
		if (&check_user_used($ldap, $user{'user'})) {
			print &text('batch_euser', $lnum, $user{'user'}),"\n";
			next;
			}
		if ($line[3] !~ /^\d+$/) {
			# make up a UID
			while(&check_uid_used($ldap, $newuid) ||
			      $mconfig{'new_user_gid'} &&
			      &check_gid_used($ldap, $newuid)) {
				$newuid++;
				}
			$user{'uid'} = $newuid;
			}
		else {
			# use the given UID
			if (&check_uid_used($ldap, $line[3])) {
				print &text('batch_ecaccess', $lnum,
					    $text{'usave_euidused2'}),"\n";
				next;
				}
			$user{'uid'} = $line[3];
			}
		if (!-r $line[7]) {
			print &text('batch_eshell', $lnum, $line[7]),"\n";
			next;
			}
		$user{'shell'} = $line[7];
		$user{'real'} = $line[5];
		local @gids = split(/[ ,]+/, $line[4]);
		$user{'gid'} = $gids[0];
		local $grp = &all_getgrgid($gids[0]);

		if ($line[6] eq '' && $mconfig{'home_base'}) {
			# Choose home dir automatically
			$user{'home'} = &auto_home_dir(
				$mconfig{'home_base'}, $user{'user'}, $user{'gid'});
			}
		elsif ($line[6] !~ /^\//) {
			print &text('batch_ehome', $lnum,$line[6]),"\n";
			next;
			}
		else {
			# Use given home dir
			$user{'home'} = $line[6];
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

		# Work out password
		if ($in{'crypt'}) {
			$user{'pass'} = $line[2];
			$user{'passmode'} = 2;
			}
		elsif ($line[2] eq 'x') {
			# No login allowed
			$user{'pass'} = $mconfig{'lock_string'};
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

		$user{'ldap_attrs'} ||= [ ];
		if ($in{'samba'}) {
			# Add Samba-specific properties
			push(@{$user{'ldap_class'}}, $config{'samba_class'});
			&samba_properties(1, \%user, $user{'passmode'},
					  $user{'plainpass'}, $schema,
					  $user{'ldap_attrs'}, $ldap);
			}

		# Add extra LDAP attrs
		foreach $a (@attrs) {
			next if (!$a);
			if ($a =~ /^([^=]+)=(.*)/) {
				push(@{$user{'ldap_attrs'}}, $1, $2);
				}
			else {
				print &text('batch_eattr', $lnum, $a),"\n";
				next LINE;
				}
			}

		# Run the before command
		&set_user_envs(\%user, 'CREATE_USER', $user{'plainpass'},
			       [ map { $_->{'gid'} } @secs ]);
		$merr = &making_changes();
		&error(&text('usave_emaking', "<tt>$merr</tt>"))
			if (defined($merr));

		if ($user{'gid'} !~ /^\d+$/) {
			# Need to create a new group for the user
			if (&check_group_used($ldap, $user{'user'})) {
				print &text('batch_egtaken', $lnum,
					    $user{'user'}),"\n";
				next;
				}

			if ($mconfig{'new_user_gid'}) {
				$newgid = $user{'uid'};
				}
			else {
				while(&check_gid_used($ldap, $newgid)) {
					$newgid++;
					}
				}
			local %group;
			$group{'group'} = $user{'user'};
			$user{'gid'} = $group{'gid'} = $newgid;
			&create_group(\%group);
			}

		# Create home directory
		if ($in{'makehome'} && !-d $user{'home'}) {
			&lock_file($user{'home'});
			if (!mkdir($user{'home'}, oct($mconfig{'homedir_perms'}))) {
				print &text('batch_emkdir', $user{'home'}, $!),"\n";
				}
			chmod(oct($mconfig{'homedir_perms'}), $user{'home'});
			chown($user{'uid'}, $user{'gid'}, $user{'home'});
			&unlock_file($user{'home'});
			}

		# Create the user!
		&create_user(\%user);

		# Add user to some secondary groups
		local $group;
		foreach $group (@secs) {
			local @mems = split(/,/ , $group->{'members'});
			push(@mems, $user{'user'});
			$group->{'members'} = join(",", @mems);
			&modify_group($group, $group);
			}

		# Re-get the new user object
		$base = &get_user_base();
		$newdn = "uid=$user{'user'},$base";
		$rv = $ldap->search(base => $newdn,
				    scope => 'base',
				    filter => &user_filter());
		($uinfo) = $rv->all_entries;
		%user = &dn_to_hash($uinfo);

		# Call the post command
		&set_user_envs(\%user, 'CREATE_USER', $user{'plainpass'},
			       [ map { $_->{'gid'} } @secs ]);
		&made_changes();

		# Call other modules, ignoring any failures
		$error_must_die = 1;
		eval {
			&other_modules("useradmin_create_user", \%user)
				if ($in{'others'});
			};
		$other_err = $@;
		$error_must_die = 0;

		if ($in{'copy'} && $in{'makehome'}) {
			# Copy files to user's home directory
			local $uf = $mconfig{'user_files'};
			local $shell = $user{'shell'}; $shell =~ s/^(.*)\///g;
			if ($group = &all_getgrgid($user{'gid'})) {
				$uf =~ s/\$group/$group/g;
				}
			$uf =~ s/\$gid/$user{'gid'}/g;
			$uf =~ s/\$shell/$shell/g;
			&useradmin::copy_skel_files($uf, $user{'home'},
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
		if (!$mconfig{'delete_root'} && $user->{'uid'} <= 10) {
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
				if ($in{'others'});
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

		# Delete his addressbook entry
		if ($config{'addressbook'}) {
			&delete_ldap_subtree($ldap,
				"ou=$user->{'user'}, $config{'addressbook'}");
			}

		# Delete his home directory
		if ($in{'delhome'} && $user->{'home'} !~ /^\/+$/) {
			if ($mconfig{'delete_only'}) {
				&lock_file($user->{'home'});
				&system_logged("find \"$user->{'home'}\" ! -type d -user $user->{'uid'} | xargs rm -f >/dev/null 2>&1");
				&system_logged("find \"$user->{'home'}\" -type d -user $user->{'uid'} | xargs rmdir >/dev/null 2>&1");
				rmdir($user->{'home'});
				&unlock_file($user->{'home'});
				}
			else {
				&system_logged("rm -rf \"$user->{'home'}\" >/dev/null 2>&1");
				}
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
		if (@line < $wlen) {
			print &text('batch_elen', $lnum, $wlen),"\n";
			next;
			}
		local @attrs = @line[$wlen .. $#line];
		local @ulist = &list_users();
		local ($user) = grep { $_->{'user'} eq $line[1] } @ulist;
		if (!$user) {
			print &text('batch_enouser', $lnum, $line[1]),"\n";
			next;
			}
		%olduser = %user = %$user;
		$user{'olduser'} = $user->{'user'};

		# Update supplied fields
		$user{'user'} = $line[2] if ($line[2] ne '');
		if ($in{'crypt'} && $line[3] ne '') {
			# Changing to pre-encrypted password
			$user{'pass'} = $line[3];
			$user{'passmode'} = 2;
			}
		elsif ($line[3] eq 'x') {
			# No login allowed
			$user{'pass'} = $mconfig{'lock_string'};
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

		if ($pft == 2) {
			# SYSV-style passwd and shadow information
			$user{'min'}=$line[9] if ($line[9] ne '');
			$user{'max'}=$line[10] if ($line[10] ne '');
			$user{'warn'}=$line[11] if ($line[11] ne '');
			$user{'inactive'}=$line[12]
				if ($line[12] ne '');
			$user{'expire'}=$line[13] if ($line[13] ne '');
			if ($in{'forcechange'} == 1){
			    $user{'change'} = 0;
			} elsif ($line[3] ne ''){
			    $user{'change'}= int(time() / (60*60*24));
			    }
			}

		# Work out Samba properties
		$wassamba = &indexof($config{'samba_class'},
				     @{$user{'ldap_class'}}) >= 0;
		$user{'ldap_attrs'} ||= [ ];
		if ($wassamba) {
			# Need to update Samba attributes
			&samba_properties(0, \%user, $user{'passmode'},
					  $user{'plainpass'}, $schema,
					  $user{'ldap_attrs'});
			}

		# Set extra LDAP attrs
		foreach $a (@attrs) {
			next if (!$a);
			if ($a =~ /^([^=]+)=(.*)/) {
				push(@{$user{'ldap_attrs'}}, $1, $2);
				}
			else {
				print &text('batch_eattr', $lnum, $a),"\n";
				next LINE;
				}
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
				&useradmin::recursive_change(
					$user{'home'}, $olduser{'uid'},
					$olduser{'gid'}, -1, $user{'gid'});
				}
			else {
				&useradmin::recursive_change(
					"/", $olduser{'uid'},
					$olduser{'gid'}, -1, $user{'gid'});
				}
			}
		if ($olduser{'uid'} != $user{'uid'} && $in{'chuid'}) {
			if ($in{'chuid'} == 1) {
				&useradmin::recursive_change(
					$user{'home'}, $olduser{'uid'},
					-1, $user{'uid'}, -1);
				}
			else {
				&useradmin::recursive_change(
					"/", $olduser{'uid'},
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
				if ($in{'others'});
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
	local $ng = &all_getgrgid($_[0]->{'gid'});
	local $ni = &can_use_group(\%access, $ng);
	if ($_[1]) {
		if ($_[1]->{'gid'} != $_[0]->{'gid'}) {
			local $og = &all_getgrgid($_[1]->{'gid'});
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

