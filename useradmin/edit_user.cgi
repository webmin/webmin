#!/usr/local/bin/perl
# edit_user.cgi
# Display a form for editing a user, or creating a new user

require './user-lib.pl';
use Time::Local;
&ReadParse();

# Show header and get the user
@ulist = &list_users();
$n = $in{'user'};
if ($n eq '') {
	# Creating a new user
	$access{'ucreate'} || &error($text{'uedit_ecreate'});
	&ui_print_header(undef, $text{'uedit_title2'}, "", "create_user");
	if ($in{'clone'} ne '') {
		($clone_hash) = grep { $_->{'user'} eq $in{'clone'} } @ulist;
		$clone_hash || &error($text{'uedit_egone'});
		%uinfo = %$clone_hash;
		&can_edit_user(\%access, \%uinfo) || &error($text{'uedit_eedit'});
		$uinfo{'user'} = '';
		}
	}
else {
	# Editing an existing one
	($uinfo_hash) = grep { $_->{'user'} eq $n } @ulist;
	$uinfo_hash || &error($text{'uedit_egone'});
	%uinfo = %$uinfo_hash;
	&can_edit_user(\%access, \%uinfo) || &error($text{'uedit_eedit'});
	&ui_print_header(undef, $text{'uedit_title'}, "", "edit_user");
	}
@tds = ( "width=30%" );

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

# Start of the form
print &ui_form_start("save_user.cgi", "post");
print &ui_hidden("old", $n) if ($n ne "");
print &ui_table_start($text{'uedit_details'}, "width=100%", 2, \@tds);

# Username
if ($n eq "" && $config{'new_user_group'} && $access{'gcreate'}) {
	$onch = "newgid.value = user.value";
	}
if ($access{'urename'} || $n eq "") {
	print &ui_table_row(&hlink($text{'user'}, "user"),
		&ui_textbox("user", $uinfo{'user'}, 40, 0, undef,
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
		push(@uidmodes, [ 1, $text{'uedit_uid_def'} ]);
		}
	if ($access{'calcuid'}) {
		push(@uidmodes, [ 2, $text{'uedit_uid_calc'} ]);
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
		&ui_textbox("real", $real[0], 40));

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
	$uinfo{'real'} =~ s/,*$//;	# Strip empty extra fields
	print &ui_table_row(&hlink($text{'real'}, "real"),
		&ui_textbox("real", $uinfo{'real'}, 40));
	}

# Show input for home directory
if ($access{'autohome'}) {
	# Automatic, cannot be changed
	$homefield = $text{'uedit_auto'}.
		     ($n eq "" ? "" : " ( <tt>$uinfo{'home'}</tt> )" );
	}
else {
	if ($config{'home_base'}) {
		# Can be automatic
		local $grp = &my_getgrgid($uinfo{'gid'});
		local $hb = $n eq "" ||
			    &auto_home_dir($config{'home_base'},
				    $uinfo{'user'}, $grp) eq $uinfo{'home'};
		$homefield = &ui_radio("home_base", $hb ? 1 : 0,
			[ [ 1, $text{'uedit_auto'}."<br>" ],
			  [ 0, $text{'uedit_manual'}." ".
			       &ui_filebox("home", $hb ? "" : $uinfo{'home'},
					   40, 0, undef, undef, 1) ] ]);
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
push(@shlist, $uinfo{'shell'}) if ($n ne "" && $uinfo{'shell'});
if ($access{'shells'} ne "*") {
	# Limit to shells from ACL
	@shlist = $n ne "" ? ($uinfo{'shell'}) : ();
	push(@shlist, split(/\s+/, $access{'shells'}));
	$shells = 1;
	}
$shells = 1 if ($access{'noother'});
@shlist = &unique(@shlist);
if ($n ne "" && !$uinfo{'shell'}) {
	# No shell!
	push(@shlist, [ "", "&lt;None&gt;" ]);
	}
push(@shlist, [ "*", $text{'uedit_other'} ]) if (!$shells);
$firstshell = ref($shlist[0]) ? $shlist[0]->[0] : $shlist[0];
print &ui_table_row(&hlink($text{'shell'}, "shell"),
	&ui_select("shell", $n eq "" ? $config{'default_shell'} || $firstshell
				     : $uinfo{'shell'},
	   \@shlist, 1, 0, 0, 0,
	   "onChange='form.othersh.disabled = form.shell.value != \"*\"'").
	   ($shells ? "" : &ui_filebox("othersh", undef, 40, 1)));

# Get the password, generate random if needed
$pass = $in{'clone'} ne "" ? $uinfo{'pass'} :
	$n ne "" ? $uinfo{'pass'} : $config{'lock_string'};
if ($n eq "" && $config{'random_password'}) {
	$random_password = &generate_random_password();
	}

# Check if temporary locking is supported
if (&supports_temporary_disable()) {
	if ($n ne "" && $pass ne $config{'lock_string'} && $pass ne "") {
		# Can disable if not already locked, or if a new account
		$can_disable = 1;
		if ($pass =~ /^\Q$disable_string\E/) {
			$disabled = 1;
			$pass =~ s/^\Q$disable_string\E//;
			}
		}
	elsif ($n eq "") {
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
		    &ui_textbox("encpass", $passmode == 2 ? $pass : "", 60) ] )
	  ]).
	  ($can_disable ? "&nbsp;&nbsp;".&ui_checkbox("disable", 1,
				$text{'uedit_disabled'}, $disabled) : "")
	  );

print &ui_table_end();

$pft = &passfiles_type();
if (($pft == 1 || $pft == 6) && $access{'peopt'}) {
	# Additional user fields for BSD users
	print &ui_table_start($text{'uedit_passopts'}, "width=100%", 4, \@tds);

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
		":".&ui_textbox("changemi", $cmin, 3), 3);

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
		":".&ui_textbox("expiremi", $emin, 3), 3);

	# BSD login class
	print &ui_table_row(&hlink($text{'class'}, "class"),
		&ui_textbox("class", $uinfo{'class'}, 10));

	print &ui_table_end();
	}
elsif (($pft == 2 || $pft == 5) && $access{'peopt'}) {
	# System has a shadow password file as well.. which means it supports
	# password expiry and so on
	print &ui_table_start($text{'uedit_passopts'}, "width=100%", 4, \@tds);

	# Last change date
	local $max = $n eq "" ? $config{'default_max'} : $uinfo{'max'};
	print &ui_table_row(&hlink($text{'change'}, "change"),
		($uinfo{'change'} ? &make_date(timelocal(
				       gmtime($uinfo{'change'} * 60*60*24)),1) :
		 $n eq "" ? $text{'uedit_never'} :
			    $text{'uedit_unknown'}));

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

	# Force change at next login
	if (($max || $gconfig{'os_type'} =~ /-linux$/) && $pft == 2) {
		print &ui_table_row(
			&hlink($text{'uedit_forcechange'}, 'forcechange'),
			&ui_yesno_radio("forcechange", 0));
		}

	print &ui_table_end();
	}
elsif ($pft == 4 && $access{'peopt'}) {
	# System has extra AIX password information
	print &ui_table_start($text{'uedit_passopts'}, "width=100%", 4, \@tds);

	# Last change date and time
	print &ui_table_row(&hlink($text{'change'}, "change"),
		($uinfo{'change'} ? &make_date($uinfo{'change'}) :
		 $n eq "" ? $text{'uedit_never'} :
			    $text{'uedit_unknown'}));

	if ($uinfo{'expire'} =~ /^(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/) {
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
	print &ui_table_row(&hlink($text{'expire'}, "expire"),
		&ui_radio("expire_def", $uinfo{'expire'} eq '' ? 1 :
					$uinfo{'expire'} eq '0' ? 2 : 0,
			  [ [ 1, $text{'uedit_sys'} ],
			    [ 2, $text{'uedit_never'} ],
			    [ 0, &date_input($eday, $emon, $eyear, 'expire').
				 " ".&ui_textbox("expireh", $ehour, 3).
				 "/".&ui_textbox("expiremi", $emin, 3) ] ]), 3);

	# Minimum and maximum ages in weeks
	print &ui_table_row(&hlink($text{'min_weeks'}, "min_weeks"),
	   &ui_opt_textbox("min", $uinfo{'min'}, 5, $text{'uedit_sys'}), 3);

	print &ui_table_row(&hlink($text{'max_weeks'}, "max_weeks"),
	    &ui_opt_textbox("max", $uinfo{'max'}, 5, $text{'uedit_sys'}), 3);

	# Warning days
	print &ui_table_row(&hlink($text{'warn'}, "warn"),
	    &ui_opt_textbox("warn", $uinfo{'warn'}, 5, $text{'uedit_sys'}), 3);

	# AIX-specific flags
	print &ui_table_row(&hlink($text{'flags'}, "flags"),
		&ui_checkbox("flags", "admin", $text{'uedit_admin'},
			     $uinfo{'admin'})."<br>".
		&ui_checkbox("flags", "admchg", $text{'uedit_admchg'},
			     $uinfo{'admchg'})."<br>".
		&ui_checkbox("flags", "nocheck", $text{'uedit_nocheck'},
			     $uinfo{'nocheck'}), 3);

	print &ui_table_end();
	}

# Group memberships section
print &ui_table_start($text{'uedit_gmem'}, "width=100%", 4, \@tds);

# Primary group
@groupopts = ( );
$gidmode = 0;
if ($n eq "" && $access{'gcreate'}) {
	# Has option to create a group
	push(@groupopts, [ 2, $text{'uedit_samg'} ]);
	push(@groupopts, [ 1, $text{'uedit_newg'},
			   &ui_textbox("newgid", undef, 20) ]);
	$gidmode = $config{'new_user_group'} ? 2 : 0;
	}
if ($access{'ugroups'} eq "*" || $access{'uedit_gmode'} >= 3) {
	# Group can be chosen with popup window
	local $w = 300;
	local $h = 200;
	if ($gconfig{'db_sizeuser'}) {
		($w, $h) = split(/x/, $gconfig{'db_sizeuser'});
		}
	push(@groupopts, [ 0, $text{'uedit_oldg'},
		   &ui_textbox("gid", $n eq "" ? $config{'default_group'} :
				 scalar(&my_getgrgid($uinfo{'gid'})), 13)." ".
		   &popup_window_button("my_group_chooser.cgi?multi=0", $w, $h,
					1, [ [ "ifield", "gid", "group" ] ]) ]);
	}
else {
	# From fixed menu of groups
	$cg = $uinfo{'gid'} ? &my_getgrgid($uinfo{'gid'}) : undef;
	@gl = &unique($cg ? ($cg) : (),
		      &split_quoted_string($access{'ugroups'}));
	push(@groupopts, [ 0, $text{'uedit_oldg'},
			   &ui_select("gid", $cg, \@gl) ]);
	}
if (@groupopts == 1) {
	$groupfield = $groupopts[0]->[2];
	}
else {
	$groupfield = &ui_radio_table("gidmode", $gidmode, \@groupopts);
	}
print &ui_table_row(&hlink($text{'group'}, "group"), $groupfield, 3);

# Work out which secondary groups the user is in
if ($config{'secmode'} != 1) {
	@defsecs = &split_quoted_string($config{'default_secs'});
	@glist = &list_groups();
	@glist = &sort_groups(\@glist, $config{'sort_mode'});
	%ingroups = ( );
	foreach $g (@glist) {
		@mems = split(/,/ , $g->{'members'});
		$ismem = &indexof($uinfo{'user'}, @mems) >= 0;
		if ($in{'clone'} ne '') {
			$ismem ||= &indexof($in{'clone'}, @mems) >= 0;
			}
		if ($n eq "") {
			$ismem = 1 if (&indexof($g->{'group'}, @defsecs) >= 0);
			}
		$ingroups{$g->{'group'}} = $ismem;
		}
	}

if ($config{'secmode'} == 0) {
	# Show secondary groups with select menu
	@canglist = ( );
	foreach $g (@glist) {
		next if (!&can_use_group(\%access, $g->{'group'}) &&
			 !$ingroups{$g->{'group'}});
		push(@canglist, [ $g->{'group'}, &html_escape($g->{'group'}) ]);
		}
	@ingroups = map { [ $_, $_ ] } sort { $a cmp $b }
			grep { $ingroups{$_} } (keys %ingroups);
	$secfield = &ui_multi_select("sgid", \@ingroups, \@canglist, 5, 1, 0,
				     $text{'uedit_allg'}, $text{'uedit_ing'});
	}
elsif ($config{'secmode'} == 2) {
	# Show a text box
	@insecs = ( );
	foreach $g (@glist) {
		if ($ingroups{$g->{'group'}}) {
			push(@insecs, $g->{'group'});
			}
		}
	$secfield = &ui_textarea("sgid", join("\n", @insecs), 5, 20);
	}
else {
	# Don't show
	$secfield = undef;
	}
if ($secfield) {
	print &ui_table_row(&hlink($text{'uedit_2nd'}, "2nd"), $secfield, 3);
	}

print &ui_table_end();

if ($n ne "") {
	# Editing a user - show options for moving home directory, changing IDs
	# and updating in other modules
	if ($access{'movehome'} == 1 || $access{'chuid'} == 1 ||
	    $access{'chgid'} == 1 || $access{'mothers'} == 1) {
		print &ui_table_start($text{'onsave'}, "width=100%", 2, \@tds);

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
		print &ui_table_start($text{'uedit_oncreate'}, "width=100%",
				      2, \@tds);

		# Create home dir
		if ($access{'makehome'} == 1) {
			print &ui_table_row(
				&hlink($text{'uedit_makehome'}, "makehome"),
				&ui_yesno_radio("makehome", 1));
			}

		# Copy skel files
		if ($config{'user_files'} =~ /\S/ && $access{'copy'} == 1) {
			print &ui_table_row(
				&hlink($text{'uedit_copy'}, "copy_files"),
				&ui_yesno_radio("copy_files", 1));
			}

		# Create in other modules
		if ($access{'cothers'} == 1) {
			print &ui_table_row(
				&hlink($text{'uedit_cothers'},"others"),
				&ui_yesno_radio("others",
					        $config{'default_other'}));
			}

		print &ui_table_end();
		}
	}

if ($n ne "") {
	# Buttons for saving and other actions
	@buts = ( [ undef, $text{'save'} ] );

	# List logins by user
	push(@buts, [ "list", $text{'uedit_logins'} ]);

	# Link to the mailboxes module, if installed
	if (&foreign_available("mailboxes") &&
	    &foreign_installed("mailboxes", 1)) {
		push(@buts, [ "mailboxes", $text{'uedit_mail'} ]);
		}

	# Link to Usermin for switching user
	if (&foreign_available("usermin") &&
	    &foreign_installed("usermin", 1) &&
	    (%uacl = &get_module_acl("usermin") &&
	    $uacl{'sessions'})) {
		# Link to Usermin module for switching to some user
		&foreign_require("usermin", "usermin-lib.pl");
		local %uminiserv;
		&usermin::get_usermin_miniserv_config(\%uminiserv);
		if ($uminiserv{'session'}) {
			push(@buts, [ "switch", $text{'uedit_swit'}, undef, 0,
				"onClick='form.target=\"_blank\"'" ]);
			}
		}

	# Clone user
	if ($access{'ucreate'}) {
		push(@buts, [ "clone", $text{'uedit_clone'} ]);
		}

	# Delete user
	if ($access{'udelete'}) {
		push(@buts, [ "delete", $text{'delete'} ]);
		}
	print &ui_form_end(\@buts);
	}
else {
	# Create button
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("index.cgi?mode=users", $text{'index_return'});


