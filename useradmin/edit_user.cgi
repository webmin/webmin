#!/usr/local/bin/perl
# edit_user.cgi
# Display a form for editing a user, or creating a new user

require './user-lib.pl';
require 'timelocal.pl';
&ReadParse();

# Show header and get the user
$n = $in{'num'};
if ($n eq "") {
	$access{'ucreate'} || &error($text{'uedit_ecreate'});
	&ui_print_header(undef, $text{'uedit_title2'}, "", "create_user");
	}
else {
	@ulist = &list_users();
	%uinfo = %{$ulist[$n]};
	&can_edit_user(\%access, \%uinfo) || &error($text{'uedit_eedit'});
	&ui_print_header(undef, $text{'uedit_title'}, "", "edit_user");
	}

# build list of used shells
%shells = map { $_, 1 } split(/,/, $config{'shells'});
@shlist = ($config{'default_shell'} ? ( $config{'default_shell'} ) : ( ));
push(@shlist, "/bin/sh", "/bin/csh", "/bin/false") if ($shells{'fixed'});
&build_user_used(\%used, $shells{'passwd'} ? \@shlist : undef);
if ($shells{'shells'}) {
	open(SHELLS, "/etc/shells");
	while(<SHELLS>) {
		s/\r|\n//g;
		s/#.*$//;
		push(@shlist, $_) if (/\S/);
		}
	close(SHELLS);
	}
if (%uinfo) {
	push(@shlist, $uinfo{'shell'});
	}

# Start of the form
print &ui_form_start("save_user.cgi", "post");
print &ui_hidden("num", $n) if ($n ne "");
print &ui_table_start($text{'uedit_details'}, "width=100%", 4);

# Username
if ($n eq "" && $config{'new_user_group'} && $access{'gcreate'}) {
	$onch = "newgid.value = user.value";
	}
if ($access{'urename'} || $n eq "") {
	print &ui_table_row(&hlink($text{'user'}, "user"),
		&ui_textbox("user", $uinfo{'user'}, 20, 0, undef,
			    "onChange='$onch'"));
	}
else {
	print &ui_table_row(&hlink($text{'user'}, "user"),
		"<tt>".&html_escape($uinfo{'user'})."</tt>");
	print &ui_hidden("user", $uinfo{'user'}),"\n";
	}

# User ID
if ($n ne "") {
	# Existing user, just show field to edit
	$uidfield = &ui_textbox("uid", $uinfo{'uid'}, 10);
	}
else {
	# Work out which UID modes are available
	@uidmodes = ( );
	$defuid = &allocate_uid(\%used);
	if ($access{'autouid'}) {
		push(@uidmodes, [ 1, $text{'gedit_uid_def'} ]);
		}
	if ($access{'calcuid'}) {
		push(@uidmodes, [ 2, $text{'gedit_uid_calc'} ]);
		}
	if ($access{'useruid'}) {
		push(@uidmodes, [ 0, &ui_textbox("uid", $defuid, 10) ]);
		}
	if (@uidmodes == 1) {
		$uidfield = &ui_hidden("uid_def", $uidmodes[0]->[0]).
			    $uidmodes[0]->[1];
		}
	else {
		$uidfield = &ui_radio("uid_def", $config{'uid_mode'},
				      \@uidmodes);
		}
	}
print &ui_table_row(&hlink($text{'uid'}, "uid"), $uidfield);

# Real name
if ($config{'extra_real'}) {
	# Has separate name, office, work and home phone parts
	local @real = split(/,/, $uinfo{'real'}, 5);
	print &ui_table_row(&hlink($text{'real'}, "real"),
		&ui_textbox("real", $real[0], 20));

	print &ui_table_row(&hlink($text{'office'}, "office"),
		&ui_textbox("office", $real[1], 20));

	print &ui_table_row(&hlink($text{'workph'}, "workph"),
		&ui_textbox("workph", $real[2], 20));

	print &ui_table_row(&hlink($text{'homeph'}, "homeph"),
		&ui_textbox("homeph", $real[3], 20));

	print &ui_table_row(&hlink($text{'extra'}, "extra"),
		&ui_textbox("extra", $real[4], 20));
	}
else {
	# Just a name
	print &ui_table_row(&hlink($text{'real'}, "real"),
		&ui_textbox("real", $uinfo{'real'}, 40));
	}

# Show input for home directory
if ($access{'autohome'}) {
	# AUtomatic, cannot be changed
	$homefield = $text{'uedit_auto'}.
		     ($n eq "" ? "" : "( <tt>$uinfo{'home'}</tt>" );
	}
else {
	if ($config{'home_base'}) {
		# Can be automatic
		local $grp = &my_getgrgid($uinfo{'gid'});
		local $hb = $n eq "" ||
			    &auto_home_dir($config{'home_base'},
				    $uinfo{'user'}, $grp) eq $uinfo{'home'};
		$homefield = &ui_radio("home_base", $hb ? 1 : 0,
			[ [ 1, $text{'uedit_auto'} ],
			  [ 0, &ui_filebox("home", $hb ? "" : $uinfo{'home'},
					   25, 0, undef, undef, 1) ] ]);
		}
	else {
		# Allow any directory
		$homefield = &ui_filebox("home", $uinfo{'home'}, 25, 0,
					 undef, undef, 1);
		}
	}
print &ui_table_row(&hlink($text{'home'}, "home"),
	$homefield);

# Show shell drop-down
if ($access{'shells'} ne "*") {
	push(@shlist, $uinfo{'shell'} || [ "", "&lt;None&gt;" ]) if (%uinfo);
	push(@shlist, split(/\s+/, $access{'shells'}));
	$shells = 1;
	}
$shells = 1 if ($access{'noother'});
@shlist = &unique(@shlist);
push(@shlist, [ "*", $text{'uedit_other'} ]) if (!$shells);
print &ui_table_row(&hlink($text{'shell'}, "shell"),
	&ui_select("shell", $uinfo{'shell'}, \@shlist, 1, 0, 0, 0,
	   "onChange='form.othersh.disabled = form.shell.value != \"*\"'").
	($shells ? "" : &ui_filebox("othersh", undef, 40, 1)), 3);

# Get the password, generate random if needed
$pass = %uinfo ? $uinfo{'pass'} : $config{'lock_string'};
if (!%uinfo && $config{'random_password'}) {
	&seed_random();
	foreach (1 .. 15) {
		$random_password .= $random_password_chars[
					rand(scalar(@random_password_chars))];
		}
	}

# Check if temporary locking is supported
if (&supports_temporary_disable()) {
	if (%uinfo && $pass ne $config{'lock_string'} && $pass ne "") {
		# Can disable if not already locked, or if a new account
		$can_disable = 1;
		if ($pass =~ /^\Q$disable_string\E/) {
			$disabled = 1;
			$pass =~ s/^\Q$disable_string\E//;
			}
		}
	elsif (!%uinfo) {
		$can_disable = 1;
		}
	}

# Show password field
$passmode = $pass eq "" && $random_password eq "" ? 0 :
	    $pass eq $config{'lock_string'} && $random_password eq "" ? 1 :
	    $random_password ne "" ? 3 :
	    $pass && $pass ne $config{'lock_string'} &&
		$random_password eq "" ? 2 : -1;
$pffunc = $config{'passwd_stars'} ? \&ui_password : \&ui_textbox;
print &ui_table_row(&hlink($text{'pass'}, "pass"),
	&ui_radio_table("passmode", $passmode,
	  [ [ 0, $config{'empty_mode'} ? $text{'none1'} : $text{'none2'} ],
	    [ 1, $text{'nologin'} ],
	    [ 3, $text{'clear'},
	      &$pffunc("pass", $config{'random_password'} && $n eq "" ?
				$random_password : "", 15) ],
	    $access{'nocrypt'} ?
		( [ 2, $text{'nochange'},
		    &ui_hidden("encpass", $pass) ] ) :
		( [ 2, $text{'encrypted'},
		    &ui_textbox("encpass", $passmode == 2 ? $pass : "", 40) ] )
	  ]).
	  ($can_disable ? "&nbsp;&nbsp;".&ui_checkbox("disable", 1,
				$text{'uedit_disabled'}, $disabled) : ""),
	  3);

print &ui_table_end();

$pft = &passfiles_type();
if (($pft == 1 || $pft == 6) && $access{'peopt'}) {
	# Additional user fields for BSD users
	print &ui_table_start($text{'uedit_passopts'}, "width=100%", 4);

	# Last change date
	if ($uinfo{'change'}) {
		@tm = localtime($uinfo{'change'});
		$cday = $tm[3];
		$cmon = $tm[4]+1;
		$cyear = $tm[5]+1900;
		$chour = sprintf "%2.2d", $tm[2];
		$cmin = sprintf "%2.2d", $tm[1];
		}
	print "<td>";
	&date_input($cday, $cmon, $cyear, 'change');
	print &ui_table_row(&hlink($text{'change2'}, "change2"),
		&date_input($cday, $cmon, $cyear, 'change').
		" ".&ui_textbox("changeh", $chour, 3).
		":".&ui_textbox("changemi", $cmin, 3));

	# Expiry date
	if ($n eq "") {
		if ($config{'default_expire'} =~
		    /^(\d+)\/(\d+)\/(\d+)$/) {
			$eday = $1;
			$emon = $2;
			$eyear = $3;
			$ehour = "00";
			$emin = "00";
			}
		}
	elsif ($uinfo{'expire'}) {
		@tm = localtime($uinfo{'expire'});
		$eday = $tm[3];
		$emon = $tm[4]+1;
		$eyear = $tm[5]+1900;
		$ehour = sprintf "%2.2d", $tm[2];
		$emin = sprintf "%2.2d", $tm[1];
		}
	print &ui_table_row(&hlink($text{'expire2'}, "expire2"),
		&date_input($eday, $emon, $eyear, 'expire').
		" ".&ui_textbox("expireh", $ehour, 3).
		":".&ui_textbox("expiremi", $emin, 3));

	# BSD login class
	print &ui_table_row(&hlink($text{'class'}, "class"),
		&ui_textbox("class", $uinfo{'class'}, 10));

	print &ui_table_end();
	}
elsif (($pft == 2 || $pft == 5) && $access{'peopt'}) {
	# System has a shadow password file as well.. which means it supports
	# password expiry and so on
	print &ui_table_start($text{'uedit_passopts'}, "width=100%", 4);

	# Last change date, with checkbox to force change
	local $max = $n eq "" ? $config{'default_max'} : $uinfo{'max'};
	print &ui_table_row(&hlink($text{'change'}, "change"),
		($uinfo{'change'} ? &make_date(timelocal(
					gmtime($uinfo{'change'} * 60*60*24)),1) :
		 $n eq "" ? $text{'uedit_never'} :
			    $text{'uedit_unknown'}).
		 (($max || $gconfig{'os_type'} =~ /-linux$/) && $pft == 2 ?
		    &ui_checkbox("forcechange", 1, $text{'uedit_forcechange'}) :
		    ""));

	if ($pft == 2) {
		# Expiry date
		if ($n eq "") {
			if ($config{'default_expire'} =~
			    /^(\d+)\/(\d+)\/(\d+)$/) {
				$eday = $1;
				$emon = $2;
				$eyear = $3;
				}
			}
		elsif ($uinfo{'expire'}) {
			@tm = localtime(timelocal(gmtime($uinfo{'expire'} *
							 60*60*24)));
			$eday = $tm[3];
			$emon = $tm[4]+1;
			$eyear = $tm[5]+1900;
			}
		print &ui_table_row(&hlink($text{'expire'}, "expire"),
			&date_input($eday, $emon, $eyear, 'expire'));
		}
	else {
		# Ask at first login?
		print &ui_table_row(&hlink($text{'ask'}, "ask"),
			&ui_yesno_radio("ask", $uinfo{'change'} eq '0'));
		}

	# Minimum and maximum days for changing
	print &ui_table_row(&hlink($text{'min'}, "min"),
		&ui_textbox("min", $n eq "" ? $config{'default_min'} :
					$uinfo{'min'}, 5));

	print &ui_table_row(&hlink($text{'max'}, "max"),
		&ui_textbox("max", $n eq "" ? $config{'default_max'} :
					$uinfo{'max'}, 5));

	if ($pft == 2) {
		# Warning and inactive days. Only available when full shadow
		# files are used
		print &ui_table_row(&hlink($text{'warn'}, "warn"),
			&ui_textbox("warn", $n eq "" ? $config{'default_warn'}
						     : $uinfo{'warn'}, 5));

		print &ui_table_row(&hlink($text{'inactive'}, "inactive"),
			&ui_textbox("inactive", $n eq "" ?
					$config{'default_inactive'} :
					$uinfo{'inactive'}, 5));

		}

	print &ui_table_end();
	}
elsif ($pft == 4 && $access{'peopt'}) {
	# System has extra AIX password information
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'uedit_passopts'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	print "<tr> <td>",&hlink("<b>$text{'change'}</b>","change"),
	      "</td>\n";
	if ($uinfo{'change'}) {
		@tm = localtime($uinfo{'change'});
		printf "<td>%s/%s/%s %2.2d:%2.2d:%2.2d</td>\n",
			$tm[3], $text{"smonth_".($tm[4]+1)}, $tm[5]+1900,
			$tm[2], $tm[1], $tm[0];
		}
	elsif ($n eq "") { print "<td>$text{'uedit_never'}</td>\n"; }
	else { print "<td>$text{'uedit_unknown'}</td>\n"; }

	print "<td>",&hlink("<b>$text{'expire'}</b>","expire"),"</td>\n";
	if ($uinfo{'expire'}) {
		$uinfo{'expire'} =~ /^(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
		$emon = $1;
		$eday = $2;
		$ehour = $3;
		$emin = $4;
		$eyear = $5;
		if ($eyear > 38) {
			$eyear += 1900;
			}
		else {
			$eyear += 2000;
			}
		}
	$emon =~ s/0(\d)/$1/;	# strip leading 0 
	print "<td>";
	&date_input($eday, $emon, $eyear, 'expire');
	print " &nbsp; <input name=expireh size=3 value=\"$ehour\">";
	print "<b>:</b><input name=expiremi size=3 value=\"$emin\"></td> </tr>\n";

	print "<tr> <td>",&hlink("<b>$text{'min_weeks'}</b>","min_weeks"),"</td>\n";
	print "<td><input size=5 name=min value=\"$uinfo{'min'}\"></td>\n";

	print "<td>",&hlink("<b>$text{'max_weeks'}</b>","max_weeks"),"</td>\n";
	print "<td><input size=5 name=max value=\"$uinfo{'max'}\"></td></tr>\n";

	print "<tr> <td valign=top>",&hlink("<b>$text{'warn'}</b>","warn"),"</td>\n";
	print "<td valign=top><input size=5 name=warn value=\"$uinfo{'warn'}\"></td>\n";

	print "<td valign=top>",&hlink("<b>$text{'flags'}</b>","flags"),
	      "</td> <td>\n";
	printf "<input type=checkbox name=flags value=admin %s> %s<br>\n",
		$uinfo{'admin'} ? 'checked' : '', $text{'uedit_admin'};
	printf "<input type=checkbox name=flags value=admchg %s> %s<br>\n",
		$uinfo{'admchg'} ? 'checked' : '', $text{'uedit_admchg'};
	printf "<input type=checkbox name=flags value=nocheck %s> %s\n",
		$uinfo{'nocheck'} ? 'checked' : '', $text{'uedit_nocheck'};
	print "</td> </tr>\n";

	print "</table></td></tr></table><p>\n";
	}

# Output group memberships
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'uedit_gmem'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
print "<tr> <td valign=top>",&hlink("<b>$text{'group'}</b>","group"),
      "</td> <td valign=top>\n";
if ($n eq "" && $access{'gcreate'}) {
	printf "<input type=radio name=gidmode value=2 %s> %s<br>\n",
		$config{'new_user_group'} ? 'checked' : '', $text{'uedit_samg'};
	printf "<input type=radio name=gidmode value=1> %s\n",
		$text{'uedit_newg'};
	print "<input name=newgid size=13><br>\n";
	printf "<input type=radio name=gidmode value=0 %s> %s\n",
		$config{'new_user_group'} ? '' : 'checked', $text{'uedit_oldg'};
	}
if ($access{'ugroups'} eq "*" || $access{'uedit_gmode'} >= 3) {
	local $w = 300;
	local $h = 200;
	if ($gconfig{'db_sizeuser'}) {
		($w, $h) = split(/x/, $gconfig{'db_sizeuser'});
		}
	printf "<input name=gid size=13 value=\"%s\">\n",
		$n eq "" ? $config{'default_group'}
			 : scalar(&my_getgrgid($uinfo{'gid'}));
	print "<input type=button onClick='ifield = document.forms[0].gid; chooser = window.open(\"my_group_chooser.cgi?multi=0&group=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=$w,height=$h\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\"></td>\n";
	}
else {
	print "<select name=gid>\n";
	local $cg = %uinfo ? &my_getgrgid($uinfo{'gid'}) : undef;
	@gl = &unique($cg ? ($cg) : (), &split_quoted_string($access{'ugroups'}));
	foreach $g (@gl) {
		printf "<option %s>%s\n",
			$cg eq $g ? "selected" : "", $g;
		}
	print "</select></td>\n";
	}

if ($config{'secmode'} != 1) {
	# Work out which secondary groups the user is in
	@defsecs = &split_quoted_string($config{'default_secs'});
	@glist = &list_groups();
	@glist = sort { $a->{'group'} cmp $b->{'group'} } @glist
		if ($config{'sort_mode'});
	%ingroups = ( );
	foreach $g (@glist) {
		@mems = split(/,/ , $g->{'members'});
		$ismem = &indexof($uinfo{'user'}, @mems) >= 0;
		if ($n eq "") {
			$ismem = 1 if (&indexof($g->{'group'}, @defsecs) >= 0);
			}
		$ingroups{$g->{'group'}} = $ismem;
		}
	print "<td valign=top>",
	      &hlink("<b>$text{'uedit_2nd'}</b>","2nd"),"</td>\n";
	}

if ($config{'secmode'} == 0) {
	# Show secondary groups with select menu
	print "<td><select name=sgid multiple size=5>\n";
	foreach $g (@glist) {
		next if (!&can_use_group(\%access, $g->{'group'}) &&
			 !$ingroups{$g->{'group'}});
		printf "<option value=\"%s\" %s>%s (%s)\n",
		    $g->{'group'}, $ingroups{$g->{'group'}} ? "selected" : "",
		    $g->{'group'}, $g->{'gid'};
		}
	print "</select></td>\n";
	}
elsif ($config{'secmode'} == 2) {
	# Show a text box
	@insecs = ( );
	foreach $g (@glist) {
		if ($ingroups{$g->{'group'}}) {
			push(@insecs, $g->{'group'});
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

if ($n ne "") {
	# Editing a user - show options for moving home directory, changing IDs
	# and updating in other modules
	if ($access{'movehome'} == 1 || $access{'chuid'} == 1 ||
	    $access{'chgid'} == 1 || $access{'mothers'} == 1) {
		print &ui_table_start($text{'onsave'}, "width=100%", 2,
				      [ "width=30%" ]);

		# Move home directory
		if ($access{'movehome'} == 1) {
			print &ui_table_row(
				&hlink($text{'uedit_movehome'}, "movehome"),
				&ui_yesno_radio("movehome", 1));
			}

		# Change UID on files
		if ($access{'chuid'} == 1) {
			print &ui_table_row(
				&hlink($text{'uedit_chuid'},"chuid"),
				&ui_radio("chuid", 1,
					  [ [ 0, $text{'no'} ],
					    [ 1, $text{'home'} ],
					    [ 2, $text{'uedit_allfiles'} ] ]));
			}

		# Change GID on files
		if ($access{'chgid'} == 1) {
			print &ui_table_row(
				&hlink($text{'uedit_chgid'},"chgid"),
				&ui_radio("chgid", 1,
					  [ [ 0, $text{'no'} ],
					    [ 1, $text{'home'} ],
					    [ 2, $text{'uedit_allfiles'} ] ]));
			}

		# Modify in other modules
		if ($access{'mothers'} == 1) {
			print &ui_table_row(
				&hlink($text{'uedit_mothers'},"others"),
				&ui_yesno_radio("others",
					$config{'default_other'} ? 1 : 0));
			}

		# Rename group, if the same and if editable
		@ginfo = &my_getgrgid($uinfo{'gid'});
		if ($ginfo[0] eq $uinfo{'user'}) {
			($group) = grep { $_->{'gid'} == $uinfo{'gid'} }
					&list_groups();
			if (&can_edit_group(\%access, $group)) {
				print &ui_table_row(
					&hlink($text{'uedit_grename'},"grename"),
					&ui_yesno_radio("grename", 1));
				}
			}

		print &ui_table_end(),"<p>\n";
		}
	}
else {
	# Creating a user - show options for creating home directory, copying
	# skel files and creating in other modules
	if ($access{'makehome'} == 1 || $access{'copy'} == 1 ||
	    $access{'cothers'} == 1) {
		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>$text{'uedit_oncreate'}</b></td> </tr>\n";
		print "<tr $cb> <td><table>\n";

		if ($access{'makehome'} == 1) {
			print "<tr> <td>",&hlink($text{'uedit_makehome'},"makehome"),"</td>\n";
			print "<td><input type=radio name=makehome value=1 checked> $text{'yes'}</td>\n";
			print "<td><input type=radio name=makehome value=0> $text{'no'}</td> </tr>\n";
			}

		if ($config{'user_files'} =~ /\S/ && $access{'copy'} == 1) {
			print "<tr> <td>",&hlink($text{'uedit_copy'},
						 "copy_files"),"</td>\n";
			print "<td><input type=radio name=copy_files ",
			      "value=1 checked> $text{'yes'}</td>\n";
			print "<td><input type=radio name=copy_files ",
			      "value=0> $text{'no'}</td> </tr>\n";
			}

		if ($access{'cothers'} == 1) {
			print "<tr> <td>",&hlink($text{'uedit_cothers'},"others"),"</td>\n";
			printf "<td><input type=radio name=others value=1 %s> $text{'yes'}</td>\n",
				$config{'default_other'} ? "checked" : "";
			printf "<td><input type=radio name=others value=0 %s> $text{'no'}</td> </tr>\n",
				$config{'default_other'} ? "" : "checked";
			}

		print "</table></td> </tr></table><p>\n";
		}
	}
if ($n ne "") {
	print "<table width=100%>\n";
	print "<tr> <td><input type=submit value=\"$text{'save'}\"></td>\n";

	print "</form><form action=\"list_logins.cgi\">\n";
	print "<input type=hidden name=username value=\"$uinfo{'user'}\">\n";
	print "<td align=center>\n";
	print "<input type=submit value=\"$text{'uedit_logins'}\"></td>\n";

	if (&foreign_available("mailboxes") &&
	    &foreign_installed("mailboxes", 1)) {
		# Link to the mailboxes module, if installed
		print "</form><form action=../mailboxes/list_mail.cgi>\n";
		print "<input type=hidden name=user value='$uinfo{'user'}'>\n";
		print "<td align=center>\n";
		print "<input type=submit value='$text{'uedit_mail'}'></td>\n";
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
			print "</form><form action=../usermin/switch.cgi ",
			      "target=_new>\n";
			print "<input type=hidden name=user ",
			      "value='$uinfo{'user'}'>\n";
			print "<td align=center>\n";
			print "<input type=submit value='$text{'uedit_swit'}'>",
			      "</td>\n";
			}
		}

	if ($access{'udelete'}) {
		print "</form><form action=\"delete_user.cgi\">\n";
		print "<input type=hidden name=num value=\"$n\">\n";
		print "<input type=hidden name=user value=\"$uinfo{'user'}\">\n";
		print "<td align=right><input type=submit value=\"$text{'delete'}\"></td> </tr>\n";
		}
	print "</form></table><p>\n";
	}
else {
	print "<input type=submit value=\"$text{'create'}\"></form><p>\n";
	}

&ui_print_footer("index.cgi?mode=users", $text{'index_return'});


