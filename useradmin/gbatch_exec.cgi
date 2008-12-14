#!/usr/local/bin/perl
# Execute create/modify/delete group commands in a batch file

require './user-lib.pl';
$access{'batch'} || &error($text{'gbatch_ecannot'});
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
	open(LOCAL, $in{'local'}) || &error($text{'batch_elocal'});
	while(<LOCAL>) {
		$data .= $_;
		}
	close(LOCAL);
	}
elsif ($in{'source'} == 2) {
	$data = $in{'text'};
	$data =~ /\S/ || &error($text{'batch_etext'});
	}

&ui_print_unbuffered_header(undef, $text{'gbatch_title'}, "");

# Force defaults for save options
$in{'chgid'} = 1 if (!$access{'chgid'});

# Work out a good base GID for new groups
&build_group_used(\%gused, \%gtaken);
$newgid = int($config{'base_gid'} > $access{'lowgid'} ?
	      $config{'base_gid'} : $access{'lowgid'});

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
	local %group;
	if ($line[0] eq 'create') {
		# Creating a new group

		# Validate line
		if (!$line[1]) {
			print &text('batch_eline', $lnum),"\n";
			next;
			}
		if (@line != 5) {
			print &text('batch_elen', $lnum, 5),"\n";
			next;
			}
		if ($line[1] !~ /^[^:\t]+$/) {
			print &text('gbatch_egroupname', $lnum),"\n";
			next;
			}
		$group{'group'} = $line[1];

		if ($gtaken{$group{'group'}}) {
			print &text('gbatch_egroup', $lnum,
				    $group{'group'}),"\n";
			next;
			}
		if ($line[3] !~ /^\d+$/) {
			# make up a GID
			while($gused{$newgid}) {
				$newgid++;
				}
			$group{'gid'} = $newgid;
			}
		else {
			# use the given UID
			if ($gused{$line[3]} && !$access{'gmultiple'}) {
				print &text('gbatch_ecaccess', $lnum,
					    $text{'gsave_egidused2'}),"\n";
				next;
				}
			$group{'gid'} = $line[3];
			}
		$gused{$group{'gid'}}++;
		$group{'members'} = $line[4];

		# Check access control restrictions
		if (!$access{'gcreate'}) {
			print &text('gbatch_ecaccess', $lnum,
				    $text{'gsave_ecreate'});
			next;
			}
		local $ch = &check_group(\%group);
		if ($ch) {
			print &text('gbatch_ecaccess', $lnum, $ch),"\n";
			next;
			}

		if ($line[2] eq '') {
			# No password needed
			$group{'pass'} = '';
			$group{'passmode'} = 0;
			}
		else {
			# Normal password
			$group{'pass'} = &encrypt_password($line[2]);
			$group{'passmode'} = 3;
			$group{'plainpass'} = $line[2];
			}

		# Run the before command
		&set_user_envs(\%group, 'CREATE_GROUP');
		$merr = &making_changes();
		&error(&text('gsave_emaking', "<tt>$merr</tt>"))
			if (defined($merr));

		# Create the group!
		&create_group(\%group);

		# All done
		&made_changes();

		# Call other modules, ignoring any failures
		$error_must_die = 1;
		eval {
			&other_modules("useradmin_create_group", \%group)
				if ($access{'cothers'} == 1 && $in{'others'} ||
				    $access{'cothers'} == 0);
			};
		$other_err = $@;
		$error_must_die = 0;

		print "<b>",&text('gbatch_created', $group{'group'}),"</b>\n";
		print "<b><i>",&text('batch_eother', $other_err),"</i></b>\n"
			if ($other_err);
		$created++;
		}
	elsif ($line[0] eq 'delete') {
		# Deleting an existing group
		if (@line != 2) {
			print &text('batch_elen', $lnum, 2),"\n";
			next;
			}
		local @glist = &list_groups();
		local ($group) = grep { $_->{'group'} eq $line[1] } @glist;
		if (!$group) {
			print &text('gbatch_enogroup', $lnum, $line[1]),"\n";
			next;
			}

		# Check if deletion is allowed
		if (!&can_edit_group(\%access, $group)) {
			print &text('gbatch_edaccess', $lnum,
				    $text{'gdel_egroup'}),"\n";
			next;
			}
		if (!$config{'delete_root'} && $group->{'gid'} <= 10) {
			print &text('gbatch_edaccess', $lnum,
				    $text{'gdel_egroup'}),"\n";
			next;
			}

		# Check if has primary members
		local $prim;
		foreach $u (&list_users()) {
			if ($u->{'gid'} == $group->{'gid'}) {
				$prim = $u;
				last;
				}
			}
		if ($prim) {
			print &text('gbatch_eprimary', $lnum,
				    $prim->{'user'}),"\n";
			next;
			}

		# Run the before command
		&set_user_envs($group, 'DELETE_GROUP');
		$merr = &making_changes();
		&error(&text('usave_emaking', "<tt>$merr</tt>"))
			if (defined($merr));

		# Delete from other modules, ignoring errors
		$error_must_die = 1;
		eval {
			&other_modules("useradmin_delete_group", $group)
				if ($access{'dothers'} == 1 && $in{'others'} ||
				    $access{'dothers'} == 0);
			};
		$other_err = $@;
		$error_must_die = 0;

		# Delete the user entry
		&delete_group($group);

		&made_changes();

		print "<b>",&text('gbatch_deleted',$group->{'group'}),"</b>\n";
		print "<b><i>",&text('batch_eother', $other_err),"</i></b>\n"
			if ($other_err);
		$deleted++;
		}
	elsif ($line[0] eq 'modify') {
		# Modifying an existing group
		if (@line != 6) {
			print &text('batch_elen', $lnum, 6),"\n";
			next;
			}
		local @glist = &list_groups();
		local ($group) = grep { $_->{'group'} eq $line[1] } @glist;
		if (!$group) {
			print &text('gbatch_enogroup', $lnum, $line[1]),"\n";
			next;
			}
		%oldgroup = %group = %$group;
		$user{'olduser'} = $user->{'user'};
		if (!&can_edit_group(\%access, \%group)) {
			print &text('gbatch_emaccess', $lnum,
				    $text{'gsave_eedit'}),"\n";
			next;
			}

		# Update supplied fields
		if ($line[2] ne '') {
			if (!$access{'grename'}) {
				print &text('gbatch_erename',
					    $lnum, $line[1]),"\n";
				}
			$group{'group'} = $line[2];
			}
		if ($line[3] ne '') {
			# New normal password
			$group{'pass'} = &encrypt_password($line[3]);
			$group{'passmode'} = 3;
			$group{'plainpass'} = $line[3];
			}
		else {
			# No change
			$group{'passmode'} = 4;
			}
		$group{'gid'} = $line[4] if ($line[4] ne '');
		if ($line[5] =~ /^\s+$/ || $line[5] eq 'NONE') {
			# No members
			$group{'members'} = '';
			}
		elsif ($line[5]) {
			$group{'members'} = $line[5];
			}

		# Check access control restrictions
		local $ch = &check_group(\%group, \%oldgroup);
		if ($ch) {
			print &text('gbatch_emaccess', $lnum, $ch),"\n";
			next;
			}

		# Run the before command
		&set_user_envs(\%group, 'MODIFY_GROUP');
		$merr = &making_changes();
		&error(&text('usave_emaking', "<tt>$merr</tt>"))
			if (defined($merr));

		# Change GIDs
		if ($oldgroup{'gid'} != $group{'gid'} && $in{'chgid'}) {
			if ($in{'chgid'} == 1) {
				# Do all the home directories of members
				&change_all_home_groups(
					$oldgroup{'gid'}, $group{'gid'},
					[ split(/,/, $group{'members'}) ]);
				}
			else {
				# Do all files in this group from the root dir
				&recursive_change("/", -1, $oldgroup{'gid'},
						       -1, $group{'gid'});
				}
			}

		# Actually modify the group
		&modify_group(\%oldgroup, \%group);
		&made_changes();

		# Modify in other modules, ignoring errors
		$error_must_die = 1;
		eval {
			&other_modules("groupadmin_modify_group",
				       \%group, \%oldgroup)
				if ($access{'mothers'} == 1 && $in{'others'} ||
				    $access{'mothers'} == 0);
			};
		$error_must_die = 0;
		$other_err = $@;

		print "<b>",&text('batch_modified',$oldgroup{'group'}),"</b>\n";
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
&webmin_log("gbatch", undef, $in{'source'} == 1 ? $in{'local'} : undef,
	    { 'created' => $created, 'modified' => $modified,
	      'deleted' => $deleted, 'lnum' => $lnum } );

&ui_print_footer("gbatch_form.cgi", $text{'batch_return'},
		 "index.cgi?mode=groups", $text{'index_return'});

# check_group(\%group, [\%oldgroup])
# Check access control restrictions for a group
sub check_group
{
# check if gid is within range
if ($access{'lowgid'} && $_[0]->{'gid'} < $access{'lowgid'}) {
	return &text('usave_elowgid', $access{'lowuid'});
	}
if ($access{'hiuid'} && $_[0]->{'uid'} > $access{'hiuid'}) {
	return &text('usave_ehiuid', $access{'hiuid'});
	}
if ($_[1] && !$access{'ggid'} && $_[1]->{'gid'} != $_[0]->{'gid'}) {
	return $text{'gsave_eggid'};
	}
return undef;
}

