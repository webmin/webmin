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

print "<form action=save_user.cgi method=post>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=dn value='$in{'dn'}'>\n";
print "<input type=hidden name=return value='$in{'return'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'uedit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if (!$in{'new'}) {
	print "<tr> <td><b>$text{'uedit_dn'}</b></td>\n";
	print "<td colspan=3><tt>$in{'dn'}</tt></td> </tr>\n";

	print "<tr> <td><b>$text{'uedit_classes'}</b></td>\n";
	print "<td colspan=3>",join(" , ", map { "<tt>$_</tt>" }
			$uinfo->get_value('objectClass')),"</td> </tr>\n";
	}

# Show username input
print "<tr> <td><b>$text{'user'}</b></td>\n";
if (@users > 1) {
	print "<td><textarea name=user rows=2 cols=10>",
		join("\n", @users),"</textarea></td>\n";
	}
else {
	print "<td><input name=user size=20 value=\"$user\"></td>\n";
	}

# Show UID input, filled in with a default for new users
print "<td><b>$text{'uid'}</b></td>\n";
if ($in{'new'}) {
	# Find the first free UID above the base
	$newuid = $mconfig{'base_uid'};
	while(&check_uid_used($ldap, $newuid)) {
		$newuid++;
		}
	print "<td><input name=uid size=10 value='$newuid'></td> </tr>\n";
	}
else {
	print "<td><input name=uid size=10 value='$uid'></td> </tr>\n";
	}

if ($config{'given'}) {
	# Show Full name inputs
	if ($in{'new'}) {
		$onch = "onChange='form.real.value = form.firstname.value+\" \"+form.lastname.value'";
		}
	print "<tr> <td><b>$text{'uedit_firstname'}</b></td>\n";
	print "<td><input name=firstname size=20 value=\"$firstname\" $onch></td>\n";

	print "<td><b>$text{'uedit_lastname'}</b></td>\n";
	print "<td><input name=lastname size=20 value=\"$lastname\" $onch></td></tr>\n";
	}

# Show real name input
print "<tr> <td><b>$text{'real'}</b></td>\n";
print "<td><input name=real size=20 value=\"$real\"></td>\n";

# Show home directory input, with an 'automatic' option
print "<td><b>$text{'home'}</b></td>\n";
print "<td>\n";
if ($mconfig{'home_base'}) {
	local $hb = $in{'new'} ||
	    &auto_home_dir($mconfig{'home_base'}, $user) eq $home;
	printf "<input type=radio name=home_base value=1 %s> %s\n",
		$hb ? "checked" : "", $text{'uedit_auto'};
	printf "<input type=radio name=home_base value=0 %s>\n",
		$hb ? "" : "checked";
	printf "<input name=home size=25 value=\"%s\"> %s\n",
		$hb ? "" : $home,
		&file_chooser_button("home", 1);
	}
else {
	print "<input name=home size=25 value=\"$home\">\n",
	      &file_chooser_button("home", 1);
	}
print "</td> </tr>\n";

# Show shell selection menu
print "<tr> <td valign=top><b>$text{'shell'}</b></td>\n";
print "<td valign=top><select name=shell>\n";
foreach $s (@shlist) {
	printf "<option value='%s' %s>%s\n", $s,
		$s eq $shell ? "selected" : "",
		$s eq "" ? "&lt;None&gt;" : $s;
	}
print "<option value=*>$text{'uedit_other'}\n";
print "</select></td>\n";

# Show password fields
if ($in{'new'} && $mconfig{'random_password'}) {
	&seed_random();
	foreach (1 .. 15) {
		$random_password .= $random_password_chars[
					rand(scalar(@random_password_chars))];
		}
	}
if (%uinfo && $pass ne $config{'lock_string'} && $pass ne "") {
        # Can disable if not already locked, or if a new account
        $can_disable = 1;
        if ($pass =~ /^\Q$useradmin::disable_string\E/) {
                $disabled = 1;
                $pass =~ s/^\Q$useradmin::disable_string\E//;
                }
        }
elsif (!%uinfo) {
        $can_disable = 1;
        }
print "<td valign=top rowspan=4><b>$text{'pass'}</b>",
      "</td> <td rowspan=4 valign=top>\n";
printf"<input type=radio name=passmode value=0 %s> %s<br>\n",
	$pass eq "" && $random_password eq "" ? "checked" : "",
	$mconfig{'empty_mode'} ? $text{'none1'} : $text{'none2'};
printf"<input type=radio name=passmode value=1 %s> $text{'nologin'}<br>\n",
	$pass eq $mconfig{'lock_string'} && $random_password eq "" ? "checked" : "";

printf "<input type=radio name=passmode value=3 %s> $text{'clear'}\n",
	$random_password ne "" ? "checked" : "";
printf "<input %s name=pass size=15 value='%s'><br>\n",
	$mconfig{'passwd_stars'} ? "type=password" : "",
	$mconfig{'random_password'} && $n eq "" ? $random_password : "";

printf "<input type=radio name=passmode value=2 %s> $text{'encrypted'}\n",
	$pass && $pass ne $mconfig{'lock_string'} ? "checked" : "";
printf "<input name=encpass size=20 value=\"%s\">\n",
	$pass && $pass ne $mconfig{'lock_string'} ? $pass : "";

# Show password lock checkbox
if ($can_disable) {
        printf "<br>&nbsp;&nbsp;&nbsp;".
               "<input type=checkbox name=disable value=1 %s> %s\n",
                $disabled ? "checked" : "", $text{'uedit_disabled'};
        }

print "</td> </tr>\n";

# Show alternate shell field
print "<tr> <td valign=top>$text{'uedit_other'}</td>\n";
print "<td valign=top><input size=25 name=othersh>\n";
print &file_chooser_button("othersh", 0),"</td> </tr>\n";
print "<tr> <td colspan=2><br></td> </tr>\n";

print "</table></td></tr></table><p>\n";

if (&in_schema($schema, "shadowLastChange")) {
	# Show shadow password options
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'uedit_passopts'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	print "<tr> <td><b>$text{'change'}</b></td>\n";
	print "<td>";
	if ($change) {
		@tm = localtime(timelocal(gmtime($change * 60*60*24)));
		printf "%s/%s/%s\n",
			$tm[3], $text{"smonth_".($tm[4]+1)}, $tm[5]+1900;
		}
	elsif ($in{'new'}) { print "$text{'uedit_never'}\n"; }
	else { print "$text{'uedit_unknown'}\n"; }
	print "</td>\n";

	print "<td><b>$text{'expire'}</b></td>\n";
	if ($in{'new'}) {
		if ($mconfig{'default_expire'} =~
		    /^(\d+)\/(\d+)\/(\d+)$/) {
			$eday = $1;
			$emon = $2;
			$eyear = $3;
			}
		}
	elsif ($expire) {
		@tm = localtime(timelocal(gmtime($expire * 60*60*24)));
		$eday = $tm[3];
		$emon = $tm[4]+1;
		$eyear = $tm[5]+1900;
		}
	print "<td>";
	&useradmin::date_input($eday, $emon, $eyear, 'expire');
	print "</td>\n";

	print "<tr> <td><b>$text{'min'}</b></td>\n";
	printf "<td><input size=5 name=min value=\"%s\"></td>\n",
		$in{'new'} ? $mconfig{'default_min'} : $min;

	print "<td><b>$text{'max'}</b></td>\n";
	printf "<td><input size=5 name=max value=\"%s\"></td></tr>\n",
		$in{'new'} ? $mconfig{'default_max'} : $max;

	print "<tr> <td><b>$text{'warn'}</b></td>\n";
	printf "<td><input size=5 name=warn value=\"%s\"></td>\n",
		$in{'new'} ? $mconfig{'default_warn'} : $warn;

	print "<td><b>$text{'inactive'}</b></td>\n";
	printf "<td><input size=5 name=inactive value=\"%s\"></td></tr>\n",
		$in{'new'} ? $mconfig{'default_inactive'} : $inactive;

	print "</table></td></tr></table><p>\n";

	}

# Show primary group
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'uedit_gmem'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
print "<tr> <td valign=top><b>$text{'group'}</b></td> <td valign=top>\n";
printf "<input name=gid size=8 value=\"%s\"> %s</td>\n",
	$in{'new'} ? $mconfig{'default_group'}
		   : ($x=&all_getgrgid($gid)) || $gid,
	&group_chooser_button("gid");

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
	print "<td><select name=sgid multiple size=5>\n";
	foreach $g (sort { lc($a->dn()) cmp lc($b->dn()) } $rv->all_entries) {
		$group = $g->get_value("cn");
		$gid = $g->get_value('gidNumber');
		printf "<option value=\"%s\" %s>%s (%s)\n",
		    $group, $ingroups{$group} ? "selected" : "",
		    $group, $gid;
		}
	print "</select></td>\n";
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

print "</table></td></tr></table><p>\n";

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

