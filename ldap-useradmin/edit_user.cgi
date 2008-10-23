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
			    filter => '(objectClass=posixAccount)');
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
	@alias = $uinfo->get_value('alias');
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
	open(SHELLS, "/etc/shells");
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
print &ui_table_row($text{'user'},
	@users > 1 ? &ui_textarea("user", join("\n", @users), 2, 10)
		   : &ui_textbox("user", $user, 20));

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

# Show home directory input, with an 'automatic' option
if ($mconfig{'home_base'}) {
	local $hb = $in{'new'} ||
	    &auto_home_dir($mconfig{'home_base'}, $user) eq $home;
	$homefield = &ui_radio("home_base", $hb ? 1 : 0,
			       [ [ 1, $text{'uedit_auto'} ],
				 [ 0, &ui_filebox("home", $hb ? "" : $home,
						  25, 0, undef, undef, 1) ]
			       ]);
	}
else {
	$homefield = &ui_filebox("home", $home, 25, 0, undef, undef, 1);
	}
print &ui_table_row(&hlink($text{'home'}, "home"), $homefield);

# Show shell selection menu
print &ui_table_row($text{'shell'},
	&ui_select("shell", $uinfo{'shell'}, \@shlist, 1, 0, 0, 0,
           "onChange='form.othersh.disabled = form.shell.value != \"*\"'").
	&ui_filebox("othersh", undef, 40, 1));

# Generate password if needed
if ($in{'new'} && $mconfig{'random_password'}) {
	&seed_random();
	foreach (1 .. 15) {
		$random_password .= $random_password_chars[
					rand(scalar(@random_password_chars))];
		}
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
print &ui_table_row(&hlink($text{'pass'}, "pass"),
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
	print &ui_table_row(&hlink($text{'expire'}, "expire"),
		&date_input($eday, $emon, $eyear, 'expire'));

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

	print &ui_table_end();
	}

# Group memberships section
print &ui_table_start($text{'uedit_gmem'}, "width=100%", 4, \@tds);

# Primary group
print &ui_table_row($text{'group'},
	&ui_textbox("gid", $in{'new'} ? $mconfig{'default_group'}
				      : ($x=&all_getgrgid($gid)) || $gid, 13).
	" ".&group_chooser_button("gid"));

# XXXX
if ($config{'secmode'} != 1) {
	# Work out which secondary groups the user is in
	@defsecs = &split_quoted_string($mconfig{'default_secs'});
	$base = &get_group_base();
	$rv = $ldap->search(base => $base,
			    filter => '(objectClass=posixGroup)');
	%ingroups = ( );
	foreach $g (sort { lc($a->dn()) cmp lc($b->dn()) } $rv->all_entries) {
		$group = $g->get_value("cn");
		@mems = $g->get_value("memberUid");
		local $ismem = &indexof($user, @mems) >= 0;
		if ($n eq "") {
			$ismem = 1 if (&indexof($group, @defsecs) >= 0);
			}
		$ingroups{$group} = $ismem;
		}
	print "<td valign=top><b>$text{'uedit_2nd'}</b></td>\n";
	}

if ($config{'secmode'} == 0) {
	# Show secondary groups with select menu
	foreach $g (sort { lc($a->dn()) cmp lc($b->dn()) } $rv->all_entries) {
		$group = $g->get_value("cn");
		push(@canglist, [ $group, $group ]);
		}
	@ingroups = map { [ $_, $_ ] } sort { $a cmp $b }
                        grep { $ingroups{$_} } (keys %ingroups);
	print "<td>",&ui_multi_select("sgid", \@ingroups, \@canglist, 5, 1, 0,
			     $text{'uedit_allg'}, $text{'uedit_ing'}),"</td>\n";
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
	print "<td>",&ui_textarea("sgid", join("\n", @insecs), 5, 20),"</td>\n";
	}
else {
	# Don't show
	print "<td colspan=2 width=50%></td>\n";
	}
print "</tr>\n";

print &ui_table_end();

# Show extra fields (if any)
&extra_fields_input($config{'fields'}, $uinfo);

# Show capabilties section
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'uedit_cap'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'uedit_samba'}</b></td>\n";
printf "<td><input type=radio name=samba value=1 %s> %s\n",
	$oclass{$samba_class} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=samba value=0 %s> %s</td>\n",
	$oclass{$samba_class} ? "" : "checked", $text{'no'};

if ($config{'imap_host'}) {
	print "<td><b>$text{'uedit_cyrus'}</b></td>\n";
	@cyrus_class_3 = split(' ',$cyrus_class);
	printf "<td><input type=radio name=cyrus value=1 %s> %s\n",
		$oclass{$cyrus_class_3[0]} ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=cyrus value=0 %s> %s</td> </tr>\n",
		$oclass{$cyrus_class_3[0]} ? "" : "checked", $text{'no'};

	if ($config{'domain'}) {
		print "<tr> <td><b>$text{'uedit_alias'}</b></td>\n";
		print "<td colspan=3>\n";
		printf "<input name=alias size=50 value='%s'></td> </tr>\n",
			join(" ", @alias);
		}

	# Show field for changing the quota on existing users, or setting
	# it for new users
	if ($config{'quota_support'}) {
		print "<tr> <td><b>$text{'uedit_quota'}</b></td> <td>\n";
		if ($in{'new'} || !$oclass{$cyrus_class_3[0]}) {
			print &ui_textbox("quota", $config{'quota'}, 10)." kB";
			}
		else {
			print &ui_opt_textbox("quota", undef, 10,
					      $text{'uedit_unquota'})." Kb";
			}
		print "</td> </tr>\n";
		}
	}
else {
	printf "<input type=hidden name=cyrus value='%s'>\n",
		$oclass{$cyrus_class};
	print "<td colspan=2 width=50%></td> </tr>\n";
	}
print "</table></td></tr></table><p>\n";

if ($in{'new'}) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'uedit_oncreate'}</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";

	print "<tr> <td><b>$text{'uedit_makehome'}</b></td>\n";
	print "<td><input type=radio name=makehome value=1 checked> $text{'yes'}\n";
	print "<input type=radio name=makehome value=0> $text{'no'}</td> </tr>\n";

	print "<tr> <td><b>$text{'uedit_cothers'}</b></td>\n";
	printf "<td><input type=radio name=others value=1 %s> $text{'yes'}\n",
		$mconfig{'default_other'} ? "checked" : "";
	printf "<input type=radio name=others value=0 %s> $text{'no'}</td> </tr>\n",
		$mconfig{'default_other'} ? "" : "checked";

	print "</table></td></tr></table>\n";
	}
else {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'onsave'}</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";

	print "<tr> <td><b>$text{'uedit_movehome'}</b></td>\n";
	print "<td><input type=radio name=movehome value=1 checked> $text{'yes'}\n";
	print "<input type=radio name=movehome value=0> $text{'no'}</td> </tr>\n";

	print "<tr> <td><b>$text{'uedit_chuid'}</b></td>\n";
	print "<td><input type=radio name=chuid value=0> $text{'no'}\n";
	print "<input type=radio name=chuid value=1 checked> ",
	      "$text{'home'}\n";
	print "<input type=radio name=chuid value=2> ",
	      "$text{'uedit_allfiles'}</td> </tr>\n";

	print "<tr> <td><b>$text{'chgid'}</b></td>\n";
	print "<td><input type=radio name=chgid value=0> $text{'no'}\n";
	print "<input type=radio name=chgid value=1 checked> ".
	      "$text{'home'}\n";
	print "<input type=radio name=chgid value=2> ",
	      "$text{'uedit_allfiles'}</td></tr>\n";

	print "<tr> <td><b>$text{'uedit_mothers'}</b></td>\n";
	printf "<td><input type=radio name=others value=1 %s> $text{'yes'}\n",
		$mconfig{'default_other'} ? "checked" : "";
	printf "<input type=radio name=others value=0 %s> $text{'no'}</td> </tr>\n",
		$mconfig{'default_other'} ? "" : "checked";

	print "</table></td></tr></table>\n";
	}

print "<table width=100%><tr>\n";
if ($in{'new'}) {
	# Show buttons for new users
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	# Show buttons for existing users
	print "<td><input type=submit value='$text{'save'}'></td>\n";

	print "<td align=center><input type=submit name=raw ",
	      "value='$text{'uedit_raw'}'></td>\n";

	if (&foreign_available("mailboxes") &&
	    &foreign_installed("mailboxes", 1)) {
		# Link to the mailboxes module, if installed
		print "<td align=center><input type=submit name=mailboxes ",
		      "value='$text{'uedit_mail'}'></td>\n";
		}

	if (&foreign_available("usermin") &&
	    &foreign_installed("usermin", 1) &&
	    (%uacl = &get_module_acl("usermin") &&
	    $uacl{'sessions'})) {
		# Link to Usermin module for switching to some user
		print "<td align=center><input type=submit name=switch ",
		      "value='$text{'uedit_swit'}'></td>\n";
		}

	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table>\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

