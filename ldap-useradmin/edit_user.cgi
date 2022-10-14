#!/usr/local/bin/perl
# edit_user.cgi
# Display details of an existing user and allow editing

require './ldap-useradmin-lib.pl';
use Time::Local;
&ReadParse();
$ldap = &ldap_connect();
$schema = $ldap->schema();
if ($in{'new'}) {
	$access{'ucreate'} || &error($text{'uedit_ecreate'});
	$pass = $mconfig{'lock_string'};
	$shell = $mconfig{'default_shell'} if ($mconfig{'default_shell'});
	foreach $oec (split(/\s+/, $config{'other_class'})) {
		$oclass{$oec}++;
		}
	if ($config{'samba_def'}) {
		$oclass{$samba_class}++;
		}
	if ($config{'imap_def'}) {
		@cyrus_class_3 = split(' ',$cyrus_class);
		$oclass{$cyrus_class_3[0]}++;
		}

	# Get initial values from form parameters
	foreach $n ("user", "firstname", "lastname", "real", "home", "shell",
		    "gid", "pass", "change", "expire", "min", "max", "warn",
		    "inactive") {
		if (defined($in{$n})) {
			$$n = $in{$n};
			}
		}
	&ui_print_header(undef, $text{'uedit_title2'}, "");
	}
else {
	# Get values from current user
	$rv = $ldap->search(base => $in{'dn'},
			    scope => 'base',
			    filter => &user_filter());
	($uinfo) = $rv->all_entries;
	@users = $uinfo->get_value('uid');
	$user = $users[0];
	$uid = $uinfo->get_value('uidNumber');
	$firstname = $uinfo->get_value('givenName');
	$lastname = $uinfo->get_value('sn');
	$real = $uinfo->get_value('cn');
	$home = $uinfo->get_value('homeDirectory');
	$shell = $uinfo->get_value('loginShell');
	$gid = $uinfo->get_value('gidNumber');
	$pass = $uinfo->get_value('userPassword');
	$change = $uinfo->get_value('shadowLastChange');
	$expire = $uinfo->get_value('shadowExpire');
	$min = $uinfo->get_value('shadowMin');
	$max = $uinfo->get_value('shadowMax');
	$warn = $uinfo->get_value('shadowWarning');
	$inactive = $uinfo->get_value('shadowInactive');
	foreach $oc ($uinfo->get_value('objectClass')) {
		$oclass{$oc} = 1;
		}
	@alias = $uinfo->get_value($config{'maillocaladdress'} || 'alias');
	%uinfo = &dn_to_hash($uinfo);
	&can_edit_user(\%uinfo) || &error($text{'uedit_eedit'});
	&ui_print_header(undef, $text{'uedit_title'}, "");
	}
@tds = ( "width=30%" );

# build a list of used shells and uids
@shlist = ($mconfig{'default_shell'} ? ( $mconfig{'default_shell'} ) : ( ));
%shells = map { $_, 1 } split(/,/, $config{'shells'});
push(@shlist, "/bin/sh", "/bin/csh", "/bin/false") if ($shells{'fixed'});
if ($shells{'passwd'}) {
	# Don't do this unless we need to, as scanning all users is slow
	&build_user_used(undef, \@shlist);
	}
if ($shells{'shells'}) {
	open(SHELLS, "</etc/shells");
	while(<SHELLS>) {
		s/\r|\n//g;
		s/#.*$//;
		push(@shlist, $_) if (/\S/);
		}
	close(SHELLS);
	}
push(@shlist, $shell) if ($shell);
@shlist = &unique(@shlist);

# Start of the form
print &ui_form_start("save_user.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("dn", $in{'dn'});
print &ui_table_start($text{'uedit_details'}, "width=100%", 2, \@tds);

# DN and classes
if (!$in{'new'}) {
	print &ui_table_row($text{'uedit_dn'},
		"<tt>$in{'dn'}</tt>", 3);

	print &ui_table_row($text{'uedit_classes'},
		,join(" , ", map { "<tt>$_</tt>" }
                        $uinfo->get_value('objectClass')), 3);
	}

# Show username input
if ($in{'new'} && $config{'new_user_group'} && $access{'gcreate'}) {
	$onch = "newgid.value = user.value";
	}
print &ui_table_row($text{'user'},
	@users > 1 ? &ui_textarea("user", join("\n", @users), 2, 20)
		   : &ui_textbox("user", $user, 20, 0, undef,
				 "onchange='$onch'"));

# Show UID input, filled in with a default for new users
if ($in{'new'}) {
	# Find the first free UID above the base
	$newuid = $mconfig{'base_uid'};
	while(&check_uid_used($ldap, $newuid)) {
		$newuid++;
		}
	$uidfield = &ui_textbox("uid", $newuid, 10);
	}
else {
	$uidfield = &ui_textbox("uid", $uid, 10);
	}
print &ui_table_row($text{'uid'}, $uidfield);

if ($config{'given'}) {
	# Show Full name inputs
	if ($in{'new'}) {
		if ($config{'given_order'} == 0) {
			# Firstname surname
			$onch = "onChange='form.real.value = form.firstname.value+\" \"+form.lastname.value'";
			}
		else {
			# Surname, firstname
			$onch = "onChange='form.real.value = form.lastname.value+\", \"+form.firstname.value'";
			}
		}
	print &ui_table_row($text{'uedit_firstname'},
		&ui_textbox("firstname", $firstname, 20, 0, undef, $onch));

	print &ui_table_row($text{'uedit_lastname'},
		&ui_textbox("lastname", $lastname, 20, 0, undef, $onch));
	}

# Show real name input
print &ui_table_row($text{'real'},
	&ui_textbox("real", $real, 40));

# Work out group name
if ($in{'new'}) {
	$grp = $mconfig{'default_group'};
	}
else {
	$grp = &all_getgrgid($gid);
	}

# Show home directory input, with an 'automatic' option
if ($mconfig{'home_base'}) {
	local $hb = $in{'new'} ||
	    &auto_home_dir($mconfig{'home_base'}, $user, $grp) eq $home;
	$homefield = &ui_radio("home_base", $hb ? 1 : 0,
			       [ [ 1, $text{'uedit_auto'} ],
				 [ 0, &ui_filebox("home", $hb ? "" : $home,
						  25, 0, undef, undef, 1) ]
			       ]);
	}
else {
	$homefield = &ui_filebox("home", $home, 25, 0, undef, undef, 1);
	}
print &ui_table_row($text{'home'}, $homefield);

# Show shell selection menu
print &ui_table_row($text{'shell'},
	&ui_select("shell", $uinfo{'shell'}, \@shlist, 1, 0, 0, 0,
           "onChange='form.othersh.disabled = form.shell.value != \"*\"'").
	&ui_filebox("othersh", undef, 40, 1));

# Generate password if needed
if ($in{'new'} && $mconfig{'random_password'}) {
	$random_password = &useradmin::generate_random_password();
	}

# Check if temporary locking is supported
if (!$in{'new'} && $pass ne $mconfig{'lock_string'} && $pass ne "") {
        # Can disable if not already locked, or if a new account
        $can_disable = 1;
        if ($pass =~ /^\Q$useradmin::disable_string\E/) {
                $disabled = 1;
                $pass =~ s/^\Q$useradmin::disable_string\E//;
                }
        }
elsif ($in{'new'}) {
        $can_disable = 1;
        }

# Show password field
$passmode = $pass eq "" && $random_password eq "" ? 0 :
            $pass eq $mconfig{'lock_string'} && $random_password eq "" ? 1 :
            $random_password ne "" ? 3 :
            $pass && $pass ne $mconfig{'lock_string'} &&
                $random_password eq "" ? 2 : -1;
$pffunc = $mconfig{'passwd_stars'} ? \&ui_password : \&ui_textbox;
print &ui_table_row($text{'pass'},
        &ui_radio_table("passmode", $passmode,
          [ [ 0, $mconfig{'empty_mode'} ? $text{'none1'} : $text{'none2'} ],
            [ 1, $text{'nologin'} ],
            [ 3, $text{'clear'},
              &$pffunc("pass", $mconfig{'random_password'} && $n eq "" ?
                                $random_password : "", 15) ],
            $access{'nocrypt'} ?                 ( [ 2, $text{'nochange'},
                    &ui_hidden("encpass", $pass) ] ) :
                ( [ 2, $text{'encrypted'},
                    &ui_textbox("encpass", $passmode == 2 ? $pass : "", 40) ] )
          ]).
          ($can_disable ? "&nbsp;&nbsp;".&ui_checkbox("disable", 1,
                                $text{'uedit_disabled'}, $disabled) : "")
          );

print &ui_table_end();

# Show shadow password options
if (&in_schema($schema, "shadowLastChange")) {
	print &ui_table_start($text{'uedit_passopts'}, "width=100%", 4, \@tds);

	# Last change date
        print &ui_table_row($text{'change'},
                ($uinfo{'change'} ? &make_date(timelocal(
                                       gmtime($change * 60*60*24)),1) :
                 $n eq "" ? $text{'uedit_never'} :
                            $text{'uedit_unknown'}));

	# Expiry date
	if ($in{'new'} &&
	    $mconfig{'default_expire'} =~ /^(\d+)\/(\d+)\/(\d+)$/) {
		$eday = $1;
		$emon = $2;
		$eyear = $3;
		}
	elsif ($expire) {
		@tm = localtime(timelocal(gmtime($expire * 60*60*24)));
		$eday = $tm[3];
		$emon = $tm[4]+1;
		$eyear = $tm[5]+1900;
		}
	print &ui_table_row($text{'expire'},
		&useradmin::date_input($eday, $emon, $eyear, 'expire'));

        # Minimum and maximum days for changing
        print &ui_table_row($text{'min'},
                &ui_textbox("min", $in{'new'} ? $mconfig{'default_min'}
					      : $min, 5));
        print &ui_table_row($text{'max'},
                &ui_textbox("max", $in{'new'} ? $mconfig{'default_max'}
					      : $max, 5));

	# Password warning days
        print &ui_table_row($text{'warn'},
                &ui_textbox("warn", $in{'new'} ? $mconfig{'default_warn'}
					       : $warn, 5));

	# Inactive dats
        print &ui_table_row($text{'inactive'},
                &ui_textbox("inactive", $in{'new'} ?$mconfig{'default_inactive'}
					           : $inactive, 5));

	# Force password change at next login
	print &ui_table_row(
		$text{'uedit_forcechange'},
			&ui_yesno_radio("forcechange", 0));


	print &ui_table_end();
	}

if (&in_schema($schema, "sambaPwdLastSet")) {
       print &ui_table_start($text{'uedit_sambapassopts'},
			     "width=100%", 4, \@tds);

       $value = $uinfo ? $uinfo->get_value('sambaPwdLastSet') : undef;

       print &ui_table_row($text{'uedit_sambapwdlastset'},
               ($value ? &make_date(timelocal(gmtime($value)),1) :
                 $n eq "" ? $text{'uedit_never'} :
                            $text{'uedit_unknown'}));

       $value = $uinfo ? $uinfo->get_value('sambaPwdCanChange') : undef;
       print &ui_table_row($text{'uedit_sambapwdcanchange'},
               ($value ? &make_date(timelocal(gmtime($value)),1) :
                 $n eq "" ? $text{'uedit_never'} :
                            $text{'uedit_unknown'}));

       $value = $uinfo ? $uinfo->get_value('sambaBadPasswordCount') : undef;
       print &ui_table_row($text{'uedit_sambabadpasswordcount'}, $value);

       $value = $uinfo ? $uinfo->get_value('sambaAcctFlags') : undef;
       print &ui_table_row($text{'uedit_sambaacctflags'}, $value);

       print &ui_table_end();
       }

# Group memberships section
print &ui_table_start($text{'uedit_gmem'}, "width=100%", 4, \@tds);

# Primary group
if ($in{'new'}) {
	print &ui_table_row($text{'group'},
		&ui_radio_table("gidmode",
			$mconfig{'new_user_group'} ? 2 : $grp ? 1 : 0,
			[ [ 2, $text{'uedit_samg'} ],
			  [ 1, $text{'uedit_newg'},
			       &ui_textbox("newgid", undef, 20) ],
			  [ 0, $text{'uedit_oldg'},
				&ui_textbox("gid", $grp || $gid, 20).
				" ".&group_chooser_button("gid") ] ]), 3);
	}
else {
	print &ui_table_row($text{'group'},
		&ui_textbox("gid", $grp || $gid, 20)." ".
		&group_chooser_button("gid"), 3);
	}

if ($config{'secmode'} != 1) {
	# Work out which secondary groups the user is in
	@defsecs = &split_quoted_string($mconfig{'default_secs'});
	$base = &get_group_base();
	$rv = $ldap->search(base => $base,
			    filter => &group_filter());
	%ingroups = ( );
	foreach $g (sort { lc($a->dn()) cmp lc($b->dn()) } $rv->all_entries) {
		$group = $g->get_value("cn");
		@mems = $g->get_value("memberUid");
		$desc = $g->get_value("description");
		local $ismem = &indexof($user, @mems) >= 0;
		if ($n eq "") {
			$ismem = 1 if (&indexof($group, @defsecs) >= 0);
			}
		$ingroups{$group} = $ismem;
		$descgroups{$group} = " ($desc)";
		}
	}

if ($config{'secmode'} == 0) {
	# Show secondary groups with select menu
	foreach $g (sort { lc($a->dn()) cmp lc($b->dn()) } $rv->all_entries) {
		$group = $g->get_value("cn");
		push(@canglist, [ $group, $group ]);
		}
	@ingroups = map { [ $_, $_.$descgroups{$_} ] } sort { $a cmp $b }
                        grep { $ingroups{$_} } (keys %ingroups);
	$groupfield = &ui_multi_select("sgid", \@ingroups, \@canglist, 5, 1, 0,
			     $text{'uedit_allg'}, $text{'uedit_ing'});
	}
elsif ($config{'secmode'} == 2) {
	# Show a text box
	@insecs = ( );
	foreach $g (sort { lc($a->dn()) cmp lc($b->dn()) } $rv->all_entries) {
		$group = $g->get_value("cn");
		if ($ingroups{$group}) {
			push(@insecs, $group);
			}
		}
	$groupfield = &ui_textarea("sgid", join("\n", @insecs), 5, 20);
	}
if ($groupfield) {
	print &ui_table_row($text{'uedit_2nd'}, $groupfield, 3);
	}

print &ui_table_end();

# Show extra fields (if any)
&extra_fields_input($config{'fields'}, $uinfo, \@tds);

# Show capabilties section
print &ui_table_start($text{'uedit_cap'}, "width=100%", 4, \@tds);

# Samba login?
print &ui_table_row($text{'uedit_samba'},
	&ui_yesno_radio("samba", $oclass{$samba_class} ? 1 : 0));

if ($config{'imap_host'}) {
	# Cyrus IMAP login
	@cyrus_class_3 = split(' ',$cyrus_class);
	print &ui_table_row($text{'uedit_cyrus'},
		&ui_yesno_radio("cyrus", $oclass{$cyrus_class_3[0]} ? 1 : 0));

	# IMAP domain
	if ($config{'domain'}) {
		print &ui_table_row($text{'uedit_alias'},
			&ui_textbox("alias", join(" ", @alias), 40), 3);
		}

	# Show field for changing the quota on existing users, or setting
	# it for new users
	if ($config{'quota_support'}) {
		print &ui_table_row($text{'uedit_quota'},
			$in{'new'} || !$oclass{$cyrus_class_3[0]} ?
			  &ui_textbox("quota", $config{'quota'}, 10)." kB" :
			  &ui_opt_textbox("quota", undef, 10,
                                              $text{'uedit_unquota'})." Kb");
		}
	}
else {
	print &ui_hidden("cyrus", $oclass{$cyrus_class});
	}
print &ui_table_end();

if ($in{'new'}) {
	# On-create options
	print &ui_table_start($text{'uedit_oncreate'}, "width=100%",
			      2, \@tds);

	# Create home dir?
	print &ui_table_row($text{'uedit_makehome'},
		&ui_yesno_radio("makehome", 1));

	# Create in other modules?
	print &ui_table_row($text{'uedit_cothers'},
		&ui_yesno_radio("others", $mconfig{'default_other'}));

	print &ui_table_end();
	}
else {
	# On save options
	print &ui_table_start($text{'onsave'}, "width=100%", 2, \@tds);

	# Move home directory
	print &ui_table_row($text{'uedit_movehome'},
		&ui_yesno_radio("movehome", 1));

	# Change UID on files
	print &ui_table_row($text{'uedit_chuid'},
		&ui_radio("chuid", 1,
			  [ [ 0, $text{'no'} ],
			    [ 1, $text{'home'} ],
			    [ 2, $text{'uedit_allfiles'} ] ]));

	# Change GID on files
	print &ui_table_row($text{'uedit_chgid'},
		&ui_radio("chgid", 1,
			  [ [ 0, $text{'no'} ],
			    [ 1, $text{'home'} ],
			    [ 2, $text{'uedit_allfiles'} ] ]));

	# Modify in other modules
	print &ui_table_row($text{'uedit_mothers'},
		&ui_yesno_radio("others",
			$mconfig{'default_other'} ? 1 : 0));

	print &ui_table_end();
	}

# Build buttons for end of form
@buts = ( );
if ($in{'new'}) {
	# Show buttons for new users
	push(@buts, [ undef, $text{'create'} ]);
	}
else {
	# Show buttons for existing users
	push(@buts, [ undef, $text{'save'} ],
		    [ 'raw', $text{'uedit_raw'} ]);

	if (&foreign_available("mailboxes") &&
	    &foreign_installed("mailboxes", 1)) {
		# Link to the mailboxes module, if installed
		push(@buts, [ 'mailboxes', $text{'uedit_mail'} ]);
		}

	if (&foreign_available("usermin") &&
	    &foreign_installed("usermin", 1) &&
	    (%uacl = &get_module_acl("usermin") &&
	    $uacl{'sessions'})) {
		# Link to Usermin module for switching to some user
		&foreign_require("usermin", "usermin-lib.pl");
		local %uminiserv;
		&usermin::get_usermin_miniserv_config(\%uminiserv);
		if ($uminiserv{'session'}) {
			push(@buts, [ "switch", $text{'uedit_swit'} ]);
			}
		}

	push(@buts, [ 'delete', $text{'delete'} ]);
	}
print &ui_form_end(\@buts);

&ui_print_footer("", $text{'index_return'});

