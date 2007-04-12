# passwd-lib.pl
# Common functions for the password module

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
%access = &get_module_acl();

# can_edit_passwd(&user)
sub can_edit_passwd
{
if ($access{'mode'} == 0) {
	# Can change any
	return 1;
	}
elsif ($access{'mode'} == 3) {
	# Only own password
	return $_[0]->[0] eq $remote_user;
	}
elsif ($access{'mode'} == 4) {
	# UID within range
	return (!$access{'low'} || $_[0]->[2] >= $access{'low'}) &&
	       (!$access{'high'} || $_[0]->[2] <= $access{'high'});
	}
elsif ($access{'mode'} == 5) {
	# Member of some group (except for exclusion list)
	return 0 if (&indexof($_[0]->[0],
			      split(/\s+/, $access{'notusers'})) >= 0);
	local $g = getgrgid($_[0]->[3]);
	return 1 if (&indexof($g, split(/\s+/, $access{'users'})) >= 0);
	if ($access{'sec'}) {
		local $gname;
		foreach $gname (split(/\s+/, $access{'users'})) {
			local @g = getgrnam($gname);
			return 1 if (&indexof($_[0]->[0],
					      split(/,/, $g[3])) >= 0);
			}
		}
	return 0;
	}
elsif ($access{'mode'} == 6) {
	# Users matching regexp
	return $_[0]->[0] =~ /$access{'users'}/;
	}
else {
	# Users on / not on some list
	local $idx = &indexof($_[0]->[0], split(/\s+/, $access{'users'}));
	return $access{'mode'} == 1 && $idx >= 0 ||
	       $access{'mode'} == 2 && $idx < 0;
	}
}

# find_user(name)
# Looks up the user structure for some name, in the useradmin, ldap-useradmin
# and nis modules
sub find_user
{
local $mod;
foreach $mod ([ "useradmin", "user-lib.pl" ],
	      [ "ldap-useradmin", "ldap-useradmin-lib.pl" ],
#             [ "nis", "nis-lib.pl" ],
	     ) {
	next if (!&foreign_installed($mod->[0], 1));
	&foreign_require($mod->[0], $mod->[1]);
	local @ulist = &foreign_call($mod->[0], "list_users");
	local ($user) = grep { $_->{'user'} eq $_[0] } @ulist;
	if ($user) {
		$user->{'mod'} = $mod->[0];
		return $user;
		}
	}
return undef;
}

# change_password(&user, pass, do-others)
# Actually update a user's password
sub change_password
{
local ($user, $pass, $others) = @_;
local $mod = $user->{'mod'} || "useradmin";
local $pft = $mod eq "useradmin" ? &useradmin::passfiles_type() :
	     $mod eq "ldap-useradmin" ? 1 : 0;

# Do the change!
$user->{'olduser'} = $user->{'user'};
$user->{'pass'} = &foreign_call($mod, "encrypt_password", $pass);
$user->{'passmode'} = 3;

# Modification ALain De Witte - on change of the password set
# ADMCHG flag for AIX
$user->{'admchg'} = 1;

$user->{'plainpass'} = $pass;
if ($pft == 2 || $pft == 5) {
	if ($in{'expire'}) {
		$user->{'change'} = 0;
		}
	else {
		$user->{'change'} = int(time() / (60*60*24));
		}
	}
elsif ($pft == 4) {
	$user->{'change'} = time();
	}
&foreign_call($mod, "lock_user_files");
&foreign_call($mod, "set_user_envs", $user, 'MODIFY_USER',
	      $in{'new'});
&foreign_call($mod, "making_changes");
&foreign_call($mod, "modify_user", $user, $user);
&foreign_call($mod, "made_changes");
&foreign_call($mod, "unlock_user_files");
if ($others) {
	&foreign_call($mod, "other_modules",
		      "useradmin_modify_user", $user);
	}
}

1;

