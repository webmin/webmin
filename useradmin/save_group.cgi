#!/usr/local/bin/perl
# save_group.cgi
# Saves or creates a new group

require './user-lib.pl';
use Time::Local;
&error_setup($text{'gsave_err'});
&ReadParse();

if ($in{'delete'}) {
	# Redirect to deletion page
	&redirect("delete_group.cgi?group=".&urlize($in{'old'}));
	return;
	}
elsif ($in{'clone'}) {
	&redirect("edit_group.cgi?clone=".&urlize($in{'old'}));
	return;
	}

# Build list of used GIDs
&build_group_used(\%gused);

# Strip out \n characters in inputs
$in{'group'} =~ s/\r|\n//g;
$in{'pass'} =~ s/\r|\n//g;
$in{'encpass'} =~ s/\r|\n//g;
$in{'gid'} =~ s/\r|\n//g;

&lock_user_files();
@glist = &list_groups();
if ($in{'old'} ne "") {
	# get old group
	@glist = &list_groups();
	($ginfo_hash) = grep { $_->{'group'} eq $in{'old'} } @glist;
	$ginfo_hash || &error($text{'gedit_egone'});
	%ogroup = %$ginfo_hash;
	$group{'group'} = $ogroup{'group'};
	&can_edit_group(\%access, \%ogroup) || &error($text{'gsave_eedit'});
	}
else {
	# check group name
	$access{'gcreate'}==1 || &error($text{'gsave_ecreate'});
	$in{'group'} =~ /^[^:\t]+$/ ||
		&error(&text('gsave_ebadname', $in{'group'}));
	$config{'max_length'} && length($in{'group'}) > $config{'max_length'} &&
		&error(&text('gsave_elength', $config{'max_length'}));
	&my_getgrnam($in{'group'}) &&
		&error(&text('gsave_einuse', $in{'group'}));
	$group{'group'} = $in{'group'};
	}

# Validate and save inputs
if (!$in{'gid_def'} || $in{'old'} ne '') {
	# Only do GID checks if not automatic
	$in{'gid'} =~ /^[0-9]+$/ || &error(&text('gsave_egid', $in{'gid'}));
	!$access{'lowgid'} || $in{'gid'} >= $access{'lowgid'} ||
		&error(&text('usave_elowgid', $access{'lowgid'}));
	!$access{'higid'} || $in{'gid'} <= $access{'higid'} ||
		&error(&text('usave_ehigid', $access{'higid'}));
	if (!$access{'ggid'} && %ogroup && $ogroup{'gid'} != $in{'gid'}) {
		&error($text{'gsave_eggid'});
		}
	if (!$access{'gmultiple'}) {
		foreach $og (@glist) {
			if ($og->{'gid'} == $in{'gid'} &&
			    $og->{'group'} ne $ogroup{'group'}) {
				&error(&text('usave_egidused',
					     $og->{'group'}, $in{'gid'}));
				}
			}
		}
	}
elsif ( $in{'gid_def'} eq '1' ) {
	# Can assign GID here
	$in{'gid'} = int($config{'base_gid'} > $access{'lowgid'} ?
			 $config{'base_gid'} : $access{'lowgid'});
	while($gused{$in{'gid'}}) {
		$in{'gid'}++;
		}
	if ($access{'higid'} && $in{'gid'} > $access{'higid'}) {
		# Out of GIDs!
		&error($text{'gsave_eallgid'});
		}
	}

elsif ( $in{'gid_def'} eq '2' ) {
	# Can calculate GID here
        if ( $config{'gid_calc'} ) {
            $in{'gid'} = &mkgid($in{'group'});
        } else {
            $in{'gid'} = &berkeley_cksum($in{'group'});
        }
        &error("Unable to calculate GID, invalid group name specified") if ( $in{'gid'} lt 0 );

	while($used{$in{'gid'}}) {
		$in{'gid'}++;
		}
	if ($access{'higid'} && $in{'gid'} > $access{'higid'}) {
		# Out of GIDS!
		&error($text{'gsave_eallgid'});
		}
	}

@mems = split(/\r?\n/, $in{'members'});
$group{'members'} = join(',', @mems);
$group{'gid'} = $in{'gid'};

$salt = chr(int(rand(26))+65) . chr(int(rand(26))+65);
if ($in{'passmode'} == 0) { $group{'pass'} = ""; }
elsif ($in{'passmode'} == 1) { $group{'pass'} = $in{'encpass'}; }
elsif ($in{'passmode'} == 2) { $group{'pass'} = &unix_crypt($in{'pass'}, $salt); }

if (%ogroup) {
	# Force defaults for save options if necessary
	$in{'chgid'} = !$access{'chgid'} if ($access{'chgid'} != 1);
	$in{'others'} = !$access{'mothers'} if ($access{'mothers'} != 1);

	# Run the pre-change command
	&set_group_envs(\%group, 'MODIFY_GROUP');
	$merr = &making_changes();
	&error(&text('usave_emaking', "<tt>$merr</tt>")) if (defined($merr));

	if ($group{'gid'} != $ogroup{'gid'} && $in{'chgid'}) {
		# Change GID on files if needed
		if ($in{'chgid'} == 1) {
			# Do all the home directories of users in this group
			&change_all_home_groups($ogroup{'gid'}, $group{'gid'},
					        \@mems);
			}
		else {
			# Do all files in this group from the root dir
			&recursive_change("/", -1, $ogroup{'gid'},
					       -1, $group{'gid'});
			}
		}

	# Save the group
	&modify_group(\%ogroup, \%group);
	}
else {
	# Force defaults for save options if necessary
	$in{'others'} = !$access{'cothers'} if ($access{'cothers'} != 1);

	# Creating a new group
	&set_group_envs(\%group, 'CREATE_GROUP');
	$merr = &making_changes();
	&error(&text('usave_emaking', "<tt>$merr</tt>")) if (defined($merr));

	&create_group(\%group);
	}
&made_changes();
&unlock_user_files();

# Run other module's scripts
if ($in{'others'}) {
	local $error_must_die = 1;
	eval {
		if (%ogroup) {
			&other_modules("useradmin_modify_group",
				       \%group, \%ogroup);
			}
		else {
			&other_modules("useradmin_create_group", \%group);
			}
		};
	$others_err = $@;
	}

delete($in{'pass'});
delete($in{'encpass'});
&webmin_log(%ogroup ? 'modify' : 'create', 'group', $group{'group'}, \%in);

# Bounce back to the list, if successful
&error(&text('gsave_eothers', $others_err)) if ($others_err);
&redirect("index.cgi?mode=groups");

