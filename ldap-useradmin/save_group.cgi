#!/usr/local/bin/perl
# save_group.cgi
# Saves or creates a new group

require './ldap-useradmin-lib.pl';
&error_setup($text{'gsave_err'});
&ReadParse();
$ldap = &ldap_connect();
$schema = $ldap->schema();
&lock_user_files();

if (!$in{'new'}) {
	# Get existing group
	$rv = $ldap->search(base => $in{'dn'},
			    scope => 'base',
			    filter => &group_filter());
	($ginfo) = $rv->all_entries;
	$ginfo || &error($text{'gsave_egone'});
	$olddesc = $ginfo->get_value('description');
	%ogroup = &dn_to_hash($ginfo);
	&can_edit_group(\%ogroup) || &error($text{'gedit_eedit'});
	}
else {
	# Creating a new one
	$access{'gcreate'} || &error($text{'gedit_ecreate'});
	}

if ($in{'delete'}) {
	# Delete the group, but first check if it is anyone's primary group,
	# and ask first
	&ui_print_header(undef, $text{'gdel_title'}, "");

	if ($in{'confirm'}) {
		# Run the before command
		%ghash = &dn_to_hash($ginfo);
		&set_group_envs(\%ghash, 'DELETE_GROUP', undef);
		$merr = &making_changes();
		&error(&text('gsave_emaking', "<tt>$merr</tt>"))
			if (defined($merr));

		# Delete from other modules
		%group = &dn_to_hash($ginfo);
		if ($in{'others'}) {
			print "$text{'gdel_other'}<br>\n";
			&useradmin::other_modules("useradmin_delete_group",
						  \%group);
			print "$text{'gdel_done'}<p>\n";
			}

		# Delete the LDAP entry
		print "$text{'gdel_group'}<br>\n";
		$rv = $ldap->delete($in{'dn'});
		if ($rv->code) {
			&error(&text('gsave_edelete', $rv->error));
			}
		print "$text{'gdel_done'}<p>\n";

		&made_changes();

		%p = ( %in, %group );
		&webmin_log('delete', 'group', $group{'group'}, \%p);
		}
	else {
		# Check if any user has this group as his primary
		$gid = $ginfo->get_value("gidNumber");
		$group = $ginfo->get_value("cn");
		foreach $u (&list_users()) {
			if ($u->{'gid'} == $gid) {
				$found = $u->{'user'};
				last;
				}
			}

		if ($found) {
			# Cannot delete
			print "<p><b>",&text('gdel_eprimary', $found),
			      "</b> <p>\n";
			}
		else {
			# Ask the user if he is sure
			print &ui_confirmation_form(
				"save_group.cgi",
				&text('gdel_sure', $group),
				[ [ "dn", $in{'dn'} ],
				  [ "delete", 1 ] ],
				[ [ "confirm", $text{'gdel_del'} ] ],
				&ui_checkbox("others", 1,
					$text{'gdel_dothers'},
					$mconfig{'default_other'}),
				undef);
			}
		}

	$ldap->unbind();
	&ui_print_footer("index.cgi?mode=groups", $text{'index_greturn'});
	exit;
	}
elsif ($in{'raw'}) {
	# Show all LDAP attributes for user
	&redirect("raw.cgi?group=1&dn=".&urlize($in{'dn'}));
	exit;
	}

# Strip out \n characters in inputs
$in{'group'} =~ s/\r|\n//g;
$in{'pass'} =~ s/\r|\n//g;
$in{'encpass'} =~ s/\r|\n//g;
$in{'gid'} =~ s/\r|\n//g;

# Validate inputs
if ($in{'new'}) {
	$in{'group'} =~ /^[^:\t]+$/ ||
		&error(&text('gsave_ebadname', $in{'group'}));
	$group = $in{'group'};
	&check_group_used($ldap, $group) &&
		&error(&text('gsave_einuse', $group));
	}
else {
	$group = $in{'group'};
	$oldgroup = $ginfo->get_value("cn");
	}
$in{'gid'} =~ /^[0-9]+$/ || &error(&text('gsave_egid', $in{'gid'}));
$gid = $in{'gid'};
$desc = $in{'desc'} || undef;
@members = split(/\r?\n/, $in{members});
if ($in{'new'} || $oldgroup ne $group) {
	# Check for collision
	defined(&all_getgrnam($group)) &&
		&error(&text('gsave_einuse', $group));
	}

# Check for GID clash
if ($in{'new'} && !$access{'gmultiple'}) {
	&check_gid_used($ldap, $gid) &&
		&error($text{'gsave_egidused2'});
	}

$pfx = $config{'md5'} == 1 || $config{'md5'} == 3 ? "{md5}" :
       $config{'md5'} == 4 ? "{ssha}" :
       $config{'md5'} == 5 ? "{sha}" :
       $config{'md5'} == 0 ? "{crypt}" : "";
if ($in{'passmode'} == 0) {
	$pass = "";
	}
elsif ($in{'passmode'} == 1) {
	$pass = $in{'encpass'};
	$pass = $pfx.$pass if ($pass !~ /^\{[a-z0-9]+\}/i && $pfx);
	}
elsif ($in{'passmode'} == 2) {
	$pass = $pfx.&encrypt_password($in{'pass'});
	}

local %ghash = ( 'group' => $group,
		 'gid' => $gid,
		 'pass' => $pass,
		 'members' => join(",", @members) );

if (!$in{'new'}) {
	# Run the pre-change command
	&set_group_envs(\%ghash, 'MODIFY_GROUP',
		       $in{'passmode'} == 3 ? $in{'pass'} : "");
	$merr = &making_changes();
	&error(&text('gsave_emaking', "<tt>$merr</tt>"))
		if (defined($merr));

	# Change GID on files if needed
	$oldgid = $ginfo->get_value("gidNumber");
	if ($gid != $oldgid && $in{'chgid'}) {
		if ($in{'chgid'} == 1) {
			# Do all the home directories of users in this group
			setpwent();
			while(@tmp = getpwent()) {
                                if ($tmp[3] == $oldgid ||
                                    &indexof($tmp[0], @members) >= 0) {
                                        &useradmin::recursive_change(
                                                $tmp[7], -1, $oldgid,
                                                         -1, $gid);
                                        }
                                }
                        endpwent();
			}
		else {
			# Do all files in this group from the root dir
			&useradmin::recursive_change("/", -1, $oldgid,
						     -1, $gid);
			}
		}

	# Work out old settings
	@classes = $ginfo->get_value("objectClass");
	$wassamba = &indexof($samba_group_class, @classes) >= 0;

	if ($wassamba && !$in{'samba'}) {
		# Remove Samba attributes
		@classes = grep { $_ ne $samba_group_class } @classes;
		push(@rprops,
		     $samba_group_class eq "sambaGroup" ? ( "rid" )
			: ( "sambaSID", "sambaGrouptype" ));
		}
	elsif (!$wassamba && $in{'samba'}) {
		# Add Samba attributes
		push(@classes, $samba_group_class);
		push(@props, "rid", $gid*2+1001)
			if (&in_schema($schema, "rid") &&
			    $samba_group_schema == 2);
		push(@props, "sambaSID",
			     "$config{'samba_domain'}-".($gid*2+1001))
			if (&in_schema($schema, "sambaSID") &&
			    $samba_group_schema == 3);
		push(@props, "sambaGrouptype", 2)
			if (&in_schema($schema, "sambaGrouptype") &&
			    $samba_group_schema == 3);
		}

	# Add extra fields
	&parse_extra_fields($config{'group_fields'}, \@props, \@rprops, $ldap);

	# Get the properties for modified groups
	push(@props, &split_props($config{'group_mod_props'}, \%ghash));

	# Update the LDAP database
	@classes = &unique(@classes);
	@rprops = grep { defined($ginfo->get_value($_)) } @rprops;

	if ($oldgroup ne $group) {
	        # Need to rename the LDAP dn itself, first
	        $base = &get_group_base();
	        $newdn = "cn=$group,$base";
	        $rv = $ldap->moddn($in{'dn'}, newrdn => "cn=$group");
	        if ($rv->code) {
	                &error(&text('gsave_emoddn', $rv->error));
	                }
	        }
	else {
		$newdn = $in{'dn'};
		}

	# Add or remove description
	if ($desc) {
		push(@props, "description" => $desc);
		}
	elsif ($olddesc) {
		push(@rprops, "description");
		}
	if (!$pass && $ginfo->get_value("userPassword")) {
		push(@rprops, "userPassword");
		}

	# Update group properties
	$rv = $ldap->modify($newdn, replace =>
			    { "gidNumber" => $gid,
			      "cn" => $group,
			      $pass ? ( "userPassword" => $pass ) : ( ),
			      @members ? ( "memberUid" => \@members ) : ( ),
			      @props,
			      "objectClass" => \@classes },
			    'delete' => \@rprops);
	if ($rv->code) {
		&error(&text('gsave_emod', $rv->error))
		}
	if (!@members && $ginfo->get_value("memberUid")) {
		$rv = $ldap->modify($in{'dn'}, delete => [ "memberUid" ] );
		if ($rv->code) {
			&error(&text('gsave_emod', $rv->error))
			}
		}

	}
else {
	# Run the pre-change command
	&set_group_envs(\%ghash, 'CREATE_GROUP',
		       $in{'passmode'} == 3 ? $in{'pass'} : "");
	$merr = &making_changes();
	&error(&text('gsave_emaking', "<tt>$merr</tt>"))
		if (defined($merr));

	# Parse extra fields
	&parse_extra_fields($config{'group_fields'}, \@props, \@rprops,
			    $ldap, $in{'dn'});

	# Get the properties for new groups
	push(@props, &split_props($config{'group_props'}, \%ghash));

	# Add to the LDAP database
	$base = &get_group_base();
	$newdn = "cn=$group,$base";
	@classes = ( &def_group_obj_class() );
	push(@classes, split(/\s+/, $config{'gother_class'}));
	if ($in{'samba'}) {
		push(@classes, $samba_group_class);
		push(@props, "rid", $gid*2+1001)
			if (&in_schema($schema, "rid") &&
			    $samba_group_class eq 'sambaGroup');
		push(@props, "sambaSID",
			     "$config{'samba_domain'}-".($gid*2+1001))
			if (&in_schema($schema, "sambaSID") &&
			    $samba_group_schema == 3);
		push(@props, "sambaGrouptype", 2)
			if (&in_schema($schema, "sambaGrouptype") &&
			    $samba_group_schema == 3);
		}
	if ($desc) {
		push(@props, "description" => $desc);
		}
	$rv = $ldap->add($newdn, attr =>
			 [ "cn" => $group,
			   "gidNumber" => $gid,
			   $pass ? ( "userPassword" => $pass ) : ( ),
			   @members ? ( "memberUid" => \@members ) : ( ),
			   @props,
			   "objectClass" => \@classes ] );
	if ($rv->code) {
		&error(&text('gsave_eadd', $rv->error));
		}
	}

&made_changes();

# Run other module's scripts
if ($in{'others'}) {
	if (!$in{'new'}) {
		&useradmin::other_modules("useradmin_modify_group", \%group, \%ogroup);
		}
	else {
		&useradmin::other_modules("useradmin_create_group", \%group);
		}
	}

delete($in{'pass'});
delete($in{'encpass'});
$ldap->unbind();
&unlock_user_files();
&webmin_log(!$in{'new'} ? 'modify' : 'create', 'group', $group, \%in);

# Bounce back to the list
&redirect("index.cgi?mode=groups");

# dn_to_hash(&ldap-object)
sub dn_to_hash
{
local %group = ( 'group' => $_[0]->get_value("cn"),
                 'gid' => $_[0]->get_value("gidNumber"),
                 'pass' => $_[0]->get_value("userPassword"),
		 'members' => join(",", $_[0]->get_value("memberUid")) );
$group{'pass'} =~ s/^{[a-z0-9]+}//i;
return %group;
}

