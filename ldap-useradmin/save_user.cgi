#!/usr/local/bin/perl
# save_user.cgi
# Create, update or delete an LDAP user

require './ldap-useradmin-lib.pl';
use Time::Local;
&ReadParse();
$ldap = &ldap_connect();
$schema = $ldap->schema();
&lock_user_files();
if (!$in{'new'}) {
	# Get existing user
	$rv = $ldap->search(base => $in{'dn'},
			    scope => 'base',
			    filter => &user_filter());
	($uinfo) = $rv->all_entries;
	$uinfo || &error($text{'usave_egone'});
	%ouser = &dn_to_hash($uinfo);
	&can_edit_user(\%ouser) || &error($text{'usave_eedit'});
	}
else {
	$access{'ucreate'} || &error($text{'usave_ecreate'});
	}

if ($in{'mailboxes'}) {
	# Just re-direct to mailboxes page
	&redirect("../mailboxes/list_mail.cgi?user=$ouser{'user'}");
	exit;
	}
elsif ($in{'switch'}) {
	# Just re-direct to Usermin switch user program
	&redirect("../usermin/switch.cgi?user=$ouser{'user'}");
	exit;
	}
elsif ($in{'delete'}) {
	# Delete the user .. but ask first!
	&ui_print_header(undef, $text{'udel_title'}, "");
	$home = $uinfo->get_value("homeDirectory");
	$user = $uinfo->get_value("uid");
	if ($in{'confirm'}) {
		# Run the before command
		%uhash = &dn_to_hash($uinfo);
		&set_user_envs(\%uhash, 'DELETE_USER', undef, undef);
		$merr = &making_changes();
		&error(&text('usave_emaking', "<tt>$merr</tt>"))
			if (defined($merr));

		# Work out old classes
		@classes = $uinfo->get_value("objectClass");
		@cyrus_class_2 = split(' ',$cyrus_class);
		$wascyrus = &indexof($cyrus_class_2[0], @classes) >= 0;

		# Delete from other modules
		%user = &dn_to_hash($uinfo);
		if ($in{'others'}) {
			print "$text{'udel_other'}<br>\n";
			&useradmin::other_modules("useradmin_delete_user",
						  \%user);
			print "$text{'udel_done'}<p>\n";
			}

		# Delete from any groups
		print "$text{'udel_groups'}<br>\n";
		$base = &get_group_base();
		$rv = $ldap->search(base => $base,
				    filter => &group_filter());
		foreach $g ($rv->all_entries) {
			local @mems = $g->get_value("memberUid");
			local $idx = &indexof($user, @mems);
			if ($idx >= 0) {
				# Take out of this group
				splice(@mems, $idx, 1);
				$rv = $ldap->modify($g->dn(), replace =>
					{ 'memberUid' => \@mems });
				if ($rv->code) {
					&error(&text('usave_emodgroup',
						     $g->get_value('cn'),
						     $rv->error));
					}
				}
			}
		print "$text{'udel_done'}<p>\n";

		# Delete from the LDAP db
		print "$text{'udel_pass'}<br>\n";
		$rv = $ldap->delete($in{'dn'});
		if ($rv->code) {
			&error(&text('usave_edelete', $rv->error));
			}
		print "$text{'udel_done'}<p>\n";

		# Delete his addressbook entry
		if ($config{'addressbook'} && $wascyrus) {
			print "$text{'udel_book'}<br>\n";
			$err = &delete_addressbook();
			if ($err) {
				print &text('udel_failed', $err),"<p>\n";
				}
			else {
				print "$text{'udel_done'}<p>\n";
				}
			}

		# Delete his home directory
		if ($in{'delhome'}) {
			print "$text{'udel_home'}<br>\n";
			$home = $uinfo->get_value("homeDirectory");
			if (-d $home && $home ne "/") {
				local $realhome = &resolve_links($home);
				local $qhome = quotemeta($realhome);
				system("rm -rf $qhome >/dev/null 2>&1");
				unlink($home);	# in case of links
				}
			print "$text{'udel_done'}<p>\n";

		  # Delete his IMAP mailbox only if home gets deleted, too
		  if ($config{'imap_host'}) {
			print "$text{'udel_imap'}<br>\n";
			$imap = &imap_connect();
			$rv = $imap->delete("user".$config{'imap_foldersep'}.
					    $uinfo->get_value("uid"));
			$imap->logout();
			print "$text{'udel_done'}<p>\n";
			}
		}

		&made_changes();

		%p = ( %in, %user );
		&webmin_log("delete", "user", $user{'user'}, \%p);
		}
	else {
		# Show confirmation page
		if ($home ne "/" && -d $home) {
			# With option to delete home
			$size = &nice_size(&disk_usage_kb($home)*1024);
			$msg = &text('udel_sure', $user, $home, $size);
			@buts = ( [ undef, $text{'udel_del1'} ],
				  [ "delhome", $text{'udel_del2'} ] );
			}
		else {
			# Without home
			$msg = &text('udel_sure2', $user);
			@buts = ( [ undef, $text{'udel_del1'} ] );
			}
		print &ui_confirmation_form(
			"save_user.cgi",
			$msg,
			[ [ "dn", $in{'dn'} ],
			  [ "confirm", 1 ],
			  [ "delete", 1 ] ],
			\@buts,
			&ui_checkbox("others", 1, $text{'udel_dothers'},
				     $mconfig{'default_other'}),
			$user eq 'root' ?
			  "<font color=#ff0000>$text{'udel_root'}</font>" : ""
			);
		}

	$ldap->unbind();
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
elsif ($in{'raw'}) {
	# Show all LDAP attributes for user
	&redirect("raw.cgi?user=1&dn=".&urlize($in{'dn'}));
	exit;
	}
else {
	# Validate inputs
	&error_setup($text{'usave_err'});
	$in{'user'} =~ /^[^:\t]+$/ ||
		&error(&text('usave_ebadname', $in{'user'}));
	$in{'user'} =~ s/\r//g;
	$err = &useradmin::check_username_restrictions($in{'user'});
	&error($err) if ($err);
	$in{'real'} || &error($text{'usave_ereal'});
	@users = split(/\n/, $in{'user'});
	$user = $users[0];
	$in{'uid'} =~ /^\-?[0-9]+$/ || &error(&text('usave_euid', $in{'uid'}));
	$uid = $in{'uid'};
	$in{'real'} =~ /^[^:]*$/ || &error(&text('usave_ereal', $in{'real'}));
	$firstname = $in{'firstname'};
	$lastname = $in{'lastname'};
	$real = $in{'real'};
	$shell = $in{'shell'} eq '*' ? $in{'othersh'} : $in{'shell'};
	if ($in{'new'}) {
		&check_user_used($ldap, $user) &&
			&error(&text('usave_einuse', $user));
		}

	# Check for UID clash
	if ($in{'new'} && !$access{'umultiple'}) {
		&check_uid_used($ldap, $uid) &&
			&error($text{'usave_euidused2'});
		}

	# Validate IMAP quota
	$quota = undef;
	if ($config{'quota_support'} && !$in{'quota_def'} &&
            defined($in{'quota'})) {
		$in{'quota'} =~ /^\d+$/ || &error($text{'usave_equota'});
		$quota = $in{'quota'};
		}
	
	#load main user group
	if ($in{'gid'} =~ /^\d+$/) {
		$gid = $in{'gid'};
		}
	else {
		$gid = &all_getgrnam($in{'gid'});
		defined($gid) || &error(&text('usave_egid', $in{'gid'}));
		}
	$grp = &all_getgrgid($gid);

	# Compute and validate home directory
	if ($access{'autohome'}) {
		if ($in{'new'} || $ouser{'user'} ne $user) {
			$home = &auto_home_dir($access{'home'}, $user, $grp);
			}
		else {
			$home = $ouser{'home'};
			}
		}
	elsif ($mconfig{'home_base'} && $in{'home_base'}) {
		$home = &auto_home_dir($mconfig{'home_base'}, $user, $grp);
		}
	else {
		$home = $in{'home'};
		$home =~ /^\// || &error(&text('usave_ehome', $home));
		}
	if (!$access{'autohome'}) {
		$home =~ /^\// || &error(&text('usave_ehome', $home));
		$al = length($access{'home'});
		if (length($home) < $al ||
		    substr($home, 0, $al) ne $access{'home'}) {
			&error(&text('usave_ehomepath', $home));
			}
		}

	local $pfx = $config{'md5'} == 1 || $config{'md5'} == 3 ? "{md5}" :
	       	     $config{'md5'} == 4 ? "{ssha}" :
	       	     $config{'md5'} == 5 ? "{sha}" :
	       	     $config{'md5'} == 0 ? "{crypt}" : "";
	if ($in{'passmode'} == 0) {
		# Password is blank
		if (!$mconfig{'empty_mode'}) {
			local $err = &useradmin::check_password_restrictions(
				"", $user, $in{'new'} ? 'none' : \%ouser);
			&error($err) if ($err);
			}
		$pass = "";
		}
	elsif ($in{'passmode'} == 1) {
		# Password is locked
		$pass = $mconfig{'lock_string'};
		}
	elsif ($in{'passmode'} == 2) {
		# Specific encrypted password entered, or possibly no change
		$pass = $in{'encpass'};
		$pass = $pfx.$pass if ($pass !~ /^\{[a-z0-9]+\}/i && $pfx);
		}
	elsif ($in{'passmode'} == 3) {
		# Normal password entered - check restrictions
		local $err = &useradmin::check_password_restrictions(
				$in{'pass'}, $user,
				$in{'new'} ? 'none' : \%ouser);
		&error($err) if ($err);
		$pass = $pfx.&encrypt_password($in{'pass'});
		$plainpass = $in{'pass'};
		}
	if ($in{'disable'} && ($in{'passmode'} == 2 || $in{'passmode'} == 3)) {
		$pass = $useradmin::disable_string.$pass;
		}

	# Build useradmin-style hash of user details
	local %uhash = ( 'user' => $user,
			 'uid' => $uid,
			 'gid' => $gid,
			 'group' => $in{'group'},
			 'real' => $real,
			 'shell' => $shell,
			 'pass' => $pass,
			 'plainpass' => $plainpass,
			 'home' => $home,
			 'firstname' => $firstname,
			 'lastname' => $lastname );

	if ($in{'new'}) {
		defined(&all_getpwnam($user)) &&
			&error(&text('usave_einuse', $user));
		if ($in{'passmode'} == 1 || $in{'passmode'} == 2) {
			if ($in{'cyrus'}) {
				&error($text{'usave_ecyruspass'});
				}
			}

		# Run the pre-change command
		&set_user_envs(\%uhash, 'CREATE_USER',
			       $in{'passmode'} == 3 ? $in{'pass'} : "",
			       undef);
		$merr = &making_changes();
		&error(&text('usave_emaking', "<tt>$merr</tt>"))
			if (defined($merr));

		# Create home dir
		if (!-e $home && $in{'makehome'}) {
			&lock_file($home);
			mkdir($home, oct($mconfig{'homedir_perms'})) ||
				&error(&text('usave_emkdir', $!));
			chmod(oct($mconfig{'homedir_perms'}), $home) ||
				&error(&text('usave_echmod', $!));
			chown($uid, $gid, $home) ||
				&error(&text('usave_echown', $!));
			&unlock_file($home);
			}

		# Get configured properties for new users
		local @props = &split_props($config{'props'}, \%uhash);
		if ($in{'cyrus'}) {
			push(@props, &split_props($config{'imap_props'},
						  \%uhash));
			}

		# Build Samba-related properties
		if ($in{'samba'}) {
			&samba_properties(1, \%uhash, $in{'passmode'},
					  $in{'pass'}, $schema, \@props, $ldap);
			}

		if ($in{'cyrus'}) {
			# Build mail-related properties
			&mail_props();
			}

		# Add any extra LDAP fields
		&parse_extra_fields($config{'fields'}, \@props, \@rprops,
				    $ldap);

		# Add shadow LDAP fields
		$shadow = &shadow_fields();

		# Add to the ldap database
		@classes = ( "posixAccount", "shadowAccount" );
		if ($schema && $schema->objectclass("person") && $config{'person'}) {
			push(@classes, "person");
			}

		push(@classes, split(/\s+/, $config{'other_class'}));
		push(@classes, $samba_class) if ($in{'samba'});
		push(@classes, split(' ',$cyrus_class)) if ($in{'cyrus'});
		@classes = grep { /\S/ } @classes;	# Remove empty
		&name_fields();
		@classes = &uniquelc(@classes);
		$base = &get_user_base();
		$newdn = "uid=$user,$base";
		@allprops = ( "cn" => $real,
                              "uid" => \@users,
                              "uidNumber" => $uid,
                              "loginShell" => $shell,
                              "homeDirectory" => $home,
                              "gidNumber" => $gid,
                              $pass ? ( "userPassword" => $pass ) : ( ),
                              "objectClass" => \@classes,
			      @props );
		if (&indexoflc("person", @classes) >= 0 &&
		    !&in_props(\@allprops, "sn")) {
			# Person needs an 'sn' too
			push(@allprops, "sn", $real);
			}
		$rv = $ldap->add($newdn, attr => \@allprops);
		if ($rv->code) {
			&error(&text('usave_eadd', $rv->error));
			}

		if ($in{'cyrus'}) {
			if ($config{'addressbook'}) {
				# Create addressbook entry
				&setup_addressbook(\%uhash);
				}

			# Disconnect to save the changes
			$ldap->unbind();
			undef($ldap);

			# Create imap account
			&setup_imap(\%uhash, $quota);

			# Re-connect for later LDAP operations
			$ldap = &ldap_connect();
			}

		# Copy files into user's directory
		if ($in{'makehome'} && $mconfig{'user_files'}) {
			local $uf = $mconfig{'user_files'};
			local $shell = $user{'shell'}; $shell =~ s/^(.*)\///g;
			$uf =~ s/\$group/$in{'gid'}/g;
			$uf =~ s/\$gid/$user{'gid'}/g;
			$uf =~ s/\$shell/$shell/g;
			&useradmin::copy_skel_files($uf, $home, $uid, $gid);
			}
		}
	else {
		# Modifying a user
		$olduser = $uinfo->get_value('uid');
		if ($olduser ne $user) {
			defined(&all_getpwnam($user)) &&
				&error(&text('usave_einuse', $user));
			}

		# Work out old settings
		@classes = $uinfo->get_value("objectClass");
		$wassamba = &indexof($samba_class, @classes) >= 0;
		@cyrus_class_2 = split(' ',$cyrus_class);
		$wascyrus = &indexof($cyrus_class_2[0], @classes) >= 0;
		if ($in{'passmode'} == 1 || $in{'passmode'} == 2) {
			if (!$wascyrus && $in{'cyrus'}) {
				&error($text{'usave_ecyruspass'});
				}
			}

		# Run the pre-change command
		&set_user_envs(\%uhash, 'MODIFY_USER',
			       $in{'passmode'} == 3 ? $in{'pass'} : "",
			       undef);
		$merr = &making_changes();
		&error(&text('usave_emaking', "<tt>$merr</tt>"))
			if (defined($merr));

		# Rename home dir, if needed
		$oldhome = $uinfo->get_value("homeDirectory");
		if ($home ne $oldhome && -d $oldhome && !-e $home &&
		    $in{'movehome'}) {
			$out = `mv '$oldhome' '$home' 2>&1`;
			if ($?) { &error(&text('usave_emove', $out)); }
			}

		# Change GID on files if needed
		$oldgid = $uinfo->get_value("gidNumber");
		$olduid = $uinfo->get_value("uidNumber");
		if ($oldgid != $gid && $in{'chgid'}) {
			if ($in{'chgid'} == 1) {
				&useradmin::recursive_change($home, $olduid,
							     $oldgid, -1, $gid);
				}
			else {
				&useradmin::recursive_change("/", $olduid,
							     $oldgid, -1, $gid);
				}
			}

		# Change UID on files if needed
		if ($olduid != $uid && $in{'chuid'}) {
			if ($in{'chuid'} == 1) {
				&useradmin::recursive_change($home, $olduid,
							     -1, $uid, -1);
				}
			else {
				&useradmin::recursive_change("/", $olduid,
							     -1, $uid, -1);
				}
			}

		# Get properties for modified users
		local @props = &split_props($config{'mod_props'}, \%uhash);

		# Work out samba-related property changes
		$oldpass = $uinfo->get_value('userPassword');
		if ($in{'samba'}) {
			# Is a samba user .. add or update props
			$passmode = $in{'passmode'};
			if ($passmode == 2 && $wassamba &&
			    $in{'encpass'} eq $oldpass) {
				# Not being changed
				$passmode = 4;
				}
			&samba_properties(!$wassamba, \%uhash, $passmode,
					  $in{'pass'}, $schema, \@props, $ldap);
			}
		elsif ($wassamba) {
			# Is no longer a samba user .. take away standard
			# samba properties
			&samba_removes(\%uhash, $schema, \@rprops);
			}

		# Work out imap-related property changes
		if ($in{'cyrus'}) {
			&mail_props();
			}
		if ($in{'cyrus'} && !$wascyrus) {
			# Add any extra properties for IMAP users
			push(@props, &split_props($config{'imap_props'}));
			}
		elsif (!$in{'cyrus'} && $wascyrus) {
			# Take away properties for IMAP users
			push(@rprops, &split_first($config{'imap_props'}));
			&delete_mail_props();
			}

		# Add or update any extra LDAP fields
		&parse_extra_fields($config{'fields'}, \@props, \@rprops,
				    $ldap, $in{'dn'});

		# Add or update shadow LDAP fields
		$shadow = &shadow_fields();

		# Update the ldap database
		if ($in{'samba'}) {
			push(@classes, $samba_class);
			}
		else {
			@classes = grep { $_ ne $samba_class } @classes;
			}
		if ($in{'cyrus'}) {
			push(@classes, split(' ',$cyrus_class));
			}
		else {
                       @cyrus_class_4 = split(' ',$cyrus_class);
                       foreach $one_cyrus_class (@cyrus_class_4) {     
			       @classes = grep { $_ ne $one_cyrus_class }
					       @classes;
			       }
			}
		push(@classes, "shadowAccount") if ($shadow);
		&name_fields();
		@classes = &uniquelc(@classes);
		@classes = grep { /\S/ } @classes;	# Remove empty
		@rprops = grep { defined($uinfo->get_value($_)) } @rprops;

		if ($olduser ne $user) {
			# Need to rename the LDAP dn itself, first
			$renaming = 1;
			$base = &get_user_base();
			$newdn = "uid=$user,$base";
			$rv = $ldap->moddn($in{'dn'}, newrdn => "uid=$user");
			if ($rv->code) {
				&error(&text('usave_emoddn', $rv->error));
				}
			}
		else {
			$newdn = $in{'dn'};
			}

		# Change the user's properties
		%allprops = ( "cn" => $real,
			      "uid" => \@users,
			      "uidNumber" => $uid,
			      "loginShell" => $shell,
			      "homeDirectory" => $home,
			      "gidNumber" => $gid,
			      $pass ? ( "userPassword" => $pass ) : ( ),
			      "objectClass" => \@classes,
			      @props );
		if (&indexoflc("person", @classes) >= 0 &&
		    !$allprops{'sn'}) {
			# Person needs 'sn'
			$allprops{'sn'} = $real;
			}
		if (!$pass) {
			push(@rprops, "userPassword");
			}
		$rv = $ldap->modify($newdn, 'replace' => \%allprops,
					    'delete' => \@rprops);
		if ($rv->code) {
			&error(&text('usave_emod', $rv->error));
			}

		if ($olduser ne $user) {
			# Check if an addressbook dn exists
			local $olda =
				"ou=$olduser, $config{'addressbook'}";
			$rv = $ldap->search(base => $olda,
					    scope => 'base',
					    filter => '(&(objectClass=organizationalUnit))');
			($oldbook) = $rv->all_entries;

			if ($oldbook) {
				# Need to rename the addressbook dn
				$rv = $ldap->modify($olda, replace =>
					{ "ou" => $user });
				if ($rv->code) {
					&error(&text('usave_emodbook',
						     $rv->error));
					}

				$rv = $ldap->moddn($olda, newrdn =>
					"ou=$user");
				if ($rv->code) {
					&error(&text('usave_emodbookdn',
						     $rv->error));
					}
				}
			}

		if ($in{'cyrus'} && !$wascyrus) {
			# Adding IMAP support
			if ($config{'addressbook'}) {
                        	# Create addressbook entry
				&setup_addressbook();
				}

			# Setup the imap account as well
			&setup_imap(\%uhash, $quota);
			}
		elsif (!$in{'cyrus'} && $wascyrus) {
			# Removing IMAP support
			if ($config{'addressbook'}) {
                        	# Delete addressbook entry
				&delete_addressbook();
				}
			}
		elsif ($in{'cyrus'} && $wascyrus) {
			# Changing IMAP support
			if (!$in{'quota_def'} && $config{'quota_support'}) {
				&set_imap_quota(\%uhash, $in{'quota'});
				}
			}
		}

	if ($config{'secmode'} != 1) {
		# Update any groups that the user has been added to/removed from
		@sgnames = $config{'secmode'} == 2 ? split(/\s+/, $in{'sgid'})
						   : split(/\r?\n/, $in{'sgid'});
		foreach $gname (@sgnames) {
			$ingroup{$gname}++;
			}
		$base = &get_group_base();
		$rv = $ldap->search(base => $base,
				    filter => &group_filter());
		foreach $g ($rv->all_entries) {
			local @mems = $g->get_value("memberUid");
			local $gname = $g->get_value("cn");
			local $ldap_group_id = $g->get_value("gidNumber");
			if ($renaming) {
				local $idx = &indexof($olduser, @mems);
				if ($ingroup{$gname} && $idx<0) {
					# Need to add to the group
					push(@mems, $user);
					push(@sgids, $ldap_group_id);
					}
				elsif (!$ingroup{$gname} && $idx>=0) {
					# Need to remove from the group
					splice(@mems, $idx, 1);
					}
				elsif ($idx >= 0) {
					# Need to rename in group
					$mems[$idx] = $user;
					push(@sgids, $ldap_group_id);
					}
				else { next; }
				}
			else {
				local $idx = &indexof($user, @mems);
				if ($ingroup{$gname} && $idx<0) {
					# Need to add to the group
					push(@mems, $user);
					push(@sgids, $ldap_group_id);
					}
				elsif (!$ingroup{$gname} && $idx>=0) {
					# Need to remove from the group
					splice(@mems, $idx, 1);
					}
				elsif ($ingroup{$gname} && $idx >=0) {
					# already in this group
                                        push(@sgids, $ldap_group_id);
					next;
				        }
				else { next; }
				}

			# Actually change the group
			$rv = $ldap->modify($g->dn(), replace =>
				{ 'memberUid' => \@mems });
			if ($rv->code) {
				&error(&text('usave_emodgroup', $g->get_value('cn'),
					     $rv->error));
				}
			}
		}

	# Get the updated user object
	$rv = $ldap->search(base => $newdn,
			    scope => 'base',
			    filter => &user_filter());
	($uinfo) = $rv->all_entries;
	%user = &dn_to_hash($uinfo);

	# Run post-change script
	&set_user_envs(\%user, $in{'new'} ? 'CREATE_USER' : 'MODIFY_USER',
		       $in{'passmode'} == 3 ? $in{'pass'} : "", \@sgids);
	&made_changes();

	# Run other modules' scripts
	if ($in{'others'}) {
		$user{'passmode'} = $in{'passmode'};
		if ($in{'passmode'} == 2 && $user{'pass'} eq $ouser{'pass'}) {
			# not changing password
			$user{'passmode'} = 4;
			}
		$user{'plainpass'} = $in{'pass'} if ($in{'passmode'} == 3);
		$ldap->unbind();	# force commit?
		if (!$in{'new'}) {
			$user{'olduser'} = $ouser{'user'};
			&useradmin::other_modules("useradmin_modify_user",
						  \%user, \%ouser);
			}
		else {
			&useradmin::other_modules("useradmin_create_user",
						  \%user);
			}
		$ldap = &ldap_connect();
		}
	}
$ldap->unbind();
delete($in{'pass'});
delete($in{'passmode'});
&unlock_user_files();
&webmin_log(!$in{'new'} ? 'modify' : 'create', 'user', $user, \%in);
&redirect($in{'return'} || "");

# mail_props()
# Add properties for mail and aliases
sub mail_props
{
# Do nothing if no domain is set
return if (!$config{'domain'});

# Add surname and first name details
local ($autofirstname, $autolastname);
if ($firstname && $lastname) {
	$autofirstname = $firstname;
	$autolastname = $lastname;
	}
elsif ($in{'real'} =~ /(\S+)\s+(\S+)$/) {
	$autofirstname = lc($1);
	$autolastname = lc($2);
	}
elsif ($in{'real'} =~ /(\S+)/) {
	$autofirstname = lc($1);
	}
else {
	$autofirstname = lc($in{'user'});
	}
if ($autolastname) {
	if (&in_schema($schema, "mail")) {
		if ($config{'mailfmt'} == 0) {
			push(@props, "mail",
				     "$autofirstname.$autolastname\@$config{'domain'}")
			}
		else {
			push(@props, "mail",
				     "$user\@$config{'domain'}")
			}
		}
	}
else {
	push(@props, "mail", "$autofirstname\@$config{'domain'}")
		if (&in_schema($schema, "mail"));
	}

# Add extra aliases
local $aattr = $config{'maillocaladdress'} || "alias";
if (&in_schema($schema, $aattr)) {
	local @alias = split(/\s+/, $in{'alias'});
	if ($in{'alias'}) {
		if (!$config{'alias_same'}) {
			($dup, $dupwhat) = &check_duplicates($ldap, $aattr, \@alias, $in{'dn'});
			$dup && &error(&text('save_ealiasdup', $dupwhat, $dup->dn()));
			}
		push(@props, $aattr, \@alias);
		}
	else {
		push(@rprops, $aattr);
		}
	}
local $battr = $config{'mailroutingaddress'};
push(@props, $battr, lc($in{'user'})."\@$config{'imap_host'}")
	if ($battr ne "") && (&in_schema($schema, $battr));
}

# delete_mail_props()
# Take away any extra properties added by mail_props
sub delete_mail_props
{
local $aattr = $config{'maillocaladdress'} || "alias";
if (&in_schema($schema, $aattr)) {
	push(@rprops, $aattr);
	}
local $battr = $config{'mailroutingaddress'};
if (($battr ne "") && &in_schema($schema, $battr)) {
	push(@rprops, $battr);
	}
push(@rprops, "mail")
	if (&in_schema($schema, "mail"));
}

sub delete_addressbook
{
return &delete_ldap_subtree($ldap, "ou=$user, $config{'addressbook'}");
}

sub name_fields
{
if ($config{'given'}) {
	if ($firstname) {
		if (&in_schema($schema, "gn")) {
			push(@props, "gn", $firstname);
			}
		elsif (&in_schema($schema, "givenName")) {
			push(@props, "givenName", $firstname)
			}
		}
	if ($lastname && &in_schema($schema, "sn")) {
		push(@props, "sn", $lastname);
		}
	if ($firstname || $lastname) {
		push(@classes, $config{'given_class'});
		}
	}
if (&in_schema($schema, "gecos") && $config{'gecos'}) {
	push(@props, "gecos", &remove_accents($in{'real'}));
	}
}

sub shadow_fields
{
if (&in_schema($schema, "shadowLastChange")) {
	# Validate shadow-password inputs
	$in{'min'} =~ /^\-?[0-9]*$/ ||
		&error(&text('usave_emin', $in{'min'}));
	if ($in{'min'} ne '') {
		push(@props, "shadowMin", $in{'min'});
		}
	else {
		push(@rprops, "shadowMin");
		}
	$in{'max'} =~ /^\-?[0-9]*$/ ||
		&error(&text('usave_emax', $in{'max'}));
	if ($in{'max'} ne '') {
		push(@props, "shadowMax", $in{'max'});
		}
	else {
		push(@rprops, "shadowMax");
		}
	if ($in{'expired'} ne "" && $in{'expirem'} ne ""
	    && $in{'expirey'} ne "") {
		eval { $expire = timelocal(0, 0, 12,
					$in{'expired'},
					$in{'expirem'}-1,
					$in{'expirey'}-1900); };
		if ($@) { &error($text{'usave_eexpire'}); }
		push(@props, "shadowExpire", int($expire / (60*60*24)));
		}
	else {
		push(@rprops, "shadowExpire");
		}
	$in{'warn'} =~ /^\-?[0-9]*$/ ||
	    &error(&text('usave_ewarn', $in{'warn'}));
	if ($in{'warn'} ne '') {
		push(@props, "shadowWarning", $in{'warn'});
		}
	else {
		push(@rprops, "shadowWarning");
		}
	$in{'inactive'} =~ /^\-?[0-9]*$/ ||
	    &error(&text('usave_einactive', $in{'inactive'}));
	if ($in{'inactive'} ne '') {
		push(@props, "shadowInactive", $in{'inactive'});
		}
	else {
		push(@rprops, "shadowInactive");
		}
	if ($in{'forcechange'} == 1){
	    if ($in{'passmode'} != 1) {
		push(@props, "shadowLastChange", 0);
	    }
	} else {
	    if ($in{'passmode'} == 3 ||
		$in{'passmode'} == 2 && $pass ne $oldpass) {
	
		$daynow = int(time() / (60*60*24));
		push(@props, "shadowLastChange", $daynow);
	    }

        }
	
	return 1;
	}
else {
	return 0;
	}
}

