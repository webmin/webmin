=head1 acl-lib.pl

Library for editing webmin users, passwords and access rights.

 foreign_require("acl", "acl-lib.pl");
 @users = acl::list_users();
 $newguy = { 'name' => 'newguy',
             'pass' => acl::encrypt_password('smeg'),
             'modules' => [ 'useradmin' ] };
 acl::create_user($newguy);

=cut

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
do 'md5-lib.pl';
%access = &get_module_acl();
$access{'switch'} = 0 if (&is_readonly_mode());

# XXX LDAP support
#	XXX schema test / creation?
# XXX CHANGELOG / docs
# XXX test with Virtualmin

=head2 list_users

Returns a list of hashes containing Webmin user details. Useful keys include :

=item name - Login name

=item pass - Encrypted password

=item modules - Array references of modules

=item theme - Custom theme, if any

=cut
sub list_users
{
my (%miniserv, @rv, %acl, %logout);
local %_;
&read_acl(undef, \%acl);
&get_miniserv_config(\%miniserv);
foreach my $a (split(/\s+/, $miniserv{'logouttimes'})) {
	if ($a =~ /^([^=]+)=(\S+)$/) {
		$logout{$1} = $2;
		}
	}
open(PWFILE, $miniserv{'userfile'});
while(<PWFILE>) {
	s/\r|\n//g;
	local @user = split(/:/, $_);
	if (@user) {
		local(%user);
		$user{'name'} = $user[0];
		$user{'pass'} = $user[1];
		$user{'sync'} = $user[2];
		$user{'cert'} = $user[3];
		if ($user[4] =~ /^(allow|deny)\s+(.*)/) {
			$user{$1} = $2;
			}
		if ($user[5] =~ /days\s+(\S+)/) {
			$user{'days'} = $1;
			}
		if ($user[5] =~ /hours\s+(\d+\.\d+)-(\d+\.\d+)/) {
			$user{'hoursfrom'} = $1;
			$user{'hoursto'} = $2;
			}
		$user{'lastchange'} = $user[6];
		$user{'olds'} = [ split(/\s+/, $user[7]) ];
		$user{'minsize'} = $user[8];
		$user{'nochange'} = int($user[9]);
		$user{'temppass'} = int($user[10]);
		$user{'modules'} = $acl{$user[0]};
		$user{'lang'} = $gconfig{"lang_$user[0]"};
		$user{'notabs'} = $gconfig{"notabs_$user[0]"};
		$user{'skill'} = $gconfig{"skill_$user[0]"};
		$user{'risk'} = $gconfig{"risk_$user[0]"};
		$user{'rbacdeny'} = $gconfig{"rbacdeny_$user[0]"};
		if ($gconfig{"theme_$user[0]"}) {
			($user{'theme'}, $user{'overlay'}) =
				split(/\s+/, $gconfig{"theme_$user[0]"});
			}
		elsif (defined($gconfig{"theme_$user[0]"})) {
			$user{'theme'} = "";
			}
		$user{'readonly'} = $gconfig{"readonly_$user[0]"};
		$user{'ownmods'} = [ split(/\s+/,
					   $gconfig{"ownmods_$user[0]"}) ];
		$user{'logouttime'} = $logout{$user[0]};
		$user{'real'} = $gconfig{"realname_$user[0]"};
		push(@rv, \%user);
		}
	}
close(PWFILE);

# If a user DB is enabled, get users from it too
if ($miniserv{'userdb'}) {
	my ($dbh, $proto) = &connect_userdb($miniserv{'userdb'});
	&error("Failed to connect to user database : $dbh") if (!ref($dbh));
	if ($proto eq "mysql" || $proto eq "postgresql") {
		# Fetch users with SQL
		my %userid;
		my $cmd = $dbh->prepare("select id,name,pass from webmin_user");
		$cmd && $cmd->execute() ||
			&error("Failed to query users : ".$dbh->errstr);
		while(my ($id, $name, $pass) = $cmd->fetchrow()) {
			my $u = { 'name' => $name,
				  'pass' => $pass,
				  'proto' => $proto,
				  'id' => $id };
			push(@rv, $u);
			$userid{$id} = $u;
			}
		$cmd->finish();

		# Add user attributes
		my $cmd = $dbh->prepare(
			"select id,attr,value from webmin_user_attr");
		$cmd && $cmd->execute() ||
			&error("Failed to query user attrs : ".$dbh->errstr);
		while(my ($id, $attr, $value) = $cmd->fetchrow()) {
			if ($attr eq "olds" || $attr eq "modules" ||
			    $attr eq "ownmods") {
				$value = [ split(/\s+/, $value) ];
				}
			$userid{$id}->{$attr} = $value;
			}
		$cmd->finish();
		}
	elsif ($proto eq "ldap") {
		# Find users with LDAP query
		# XXX
		}
	&disconnect_userdb($miniserv{'userdb'}, $dbh);
	}

return @rv;
}

=head2 list_groups

Returns a list of hashes, one per Webmin group. Group membership is stored in
/etc/webmin/webmin.groups, and other attributes in the config file. Useful
keys include :

=item name - Group name

=item members - Array reference of member users

=item modules - Modules to grant to members

=cut
sub list_groups
{
my @rv;
my %miniserv;
&get_miniserv_config(\%miniserv);

# Add groups from local files
open(GROUPS, "$config_directory/webmin.groups");
while(<GROUPS>) {
	s/\r|\n//g;
	local @g = split(/:/, $_);
	local $group = { 'name' => $g[0],
			 'members' => [ split(/\s+/, $g[1]) ],
			 'modules' => [ split(/\s+/, $g[2]) ],
			 'desc' => $g[3],
			 'ownmods' => [ split(/\s+/, $g[4]) ] };
	push(@rv, $group);
	}
close(GROUPS);

# If a user DB is enabled, get groups from it too
if ($miniserv{'userdb'}) {
	my ($dbh, $proto) = &connect_userdb($miniserv{'userdb'});
	&error("Failed to connect to group database : $dbh") if (!ref($dbh));
	if ($proto eq "mysql" || $proto eq "postgresql") {
		# Fetch groups with SQL
		my %groupid;
		my $cmd = $dbh->prepare(
			"select id,name,description from webmin_group");
		$cmd && $cmd->execute() ||
			&error("Failed to query groups : ".$dbh->errstr);
		while(my ($id, $name, $desc) = $cmd->fetchrow()) {
			my $g = { 'name' => $name,
				  'desc' => $desc,
				  'proto' => $proto,
				  'id' => $id };
			push(@rv, $g);
			$groupid{$id} = $g;
			}
		$cmd->finish();

		# Add group attributes
		my $cmd = $dbh->prepare(
			"select id,attr,value from webmin_group_attr");
		$cmd && $cmd->execute() ||
			&error("Failed to query group attrs : ".$dbh->errstr);
		while(my ($id, $attr, $value) = $cmd->fetchrow()) {
			if ($attr eq "members" || $attr eq "modules" ||
			    $attr eq "ownmods") {
				$value = [ split(/\s+/, $value) ];
				}
			$groupid{$id}->{$attr} = $value;
			}
		$cmd->finish();
		}
	elsif ($proto eq "ldap") {
		# Find groups with LDAP query
		# XXX
		}
	&disconnect_userdb($miniserv{'userdb'}, $dbh);
	}

return @rv;
}

=head2 list_modules

Returns a list of the dirs of all modules available on this system.

=cut
sub list_modules
{
return map { $_->{'dir'} } &list_module_infos();
}

=head2 list_module_infos

Returns a list of the details of all modules that can be used on this system,
each of which is a hash reference in the same format as their module.info files.

=cut
sub list_module_infos
{
local @mods = grep { &check_os_support($_) } &get_all_module_infos();
return sort { $a->{'desc'} cmp $b->{'desc'} } @mods;
}

=head2 create_user(&details, [clone])

Creates a new Webmin user, based on the hash reference in the details parameter.
This must be in the same format as those returned by list_users. If the clone
parameter is given, it must be a username to copy detailed access control
settings from for this new user.

=cut
sub create_user
{
my %user = %{$_[0]};
my $clone = $_[1];
my %miniserv;
my @mods = &list_modules();

&get_miniserv_config(\%miniserv);

if ($miniserv{'userdb'} && !$miniserv{'userdb_addto'}) {
	# Adding to user database
	my ($dbh, $proto) = &connect_userdb($miniserv{'userdb'});
        &error("Failed to connect to user database : $dbh") if (!ref($dbh));
	if ($proto eq "mysql" || $proto eq "postgresql") {
		# Add user with SQL
		my $cmd = $dbh->prepare("insert into webmin_user (name,pass) values (?, ?)");
		$cmd && $cmd->execute($user{'name'}, $user{'pass'}) ||
			&error("Failed to add user : ".$dbh->errstr);
		$cmd->finish();
		my $cmd = $dbh->prepare("select max(id) from webmin_user");
		$cmd->execute();
		my ($id) = $cmd->fetchrow();
		$cmd->finish();

		# Add other attributes
		my $cmd = $dbh->prepare("insert into webmin_user_attr (id,attr,value) values (?, ?, ?)");
		foreach my $attr (keys %user) {
			next if ($attr eq "name" || $attr eq "pass");
			my $value = $user{$attr};
			if ($attr eq "olds" || $attr eq "modules" ||
			    $attr eq "ownmods") {
				$value = join(" ", @$value);
				}
			$cmd->execute($id, $attr, $value) ||
				&error("Failed to add user attribute : ".
					$dbh->errstr);
			$cmd->finish();
			}
		}
	elsif ($proto eq "ldap") {
		# Add user to LDAP
		# XXX
		}
	&disconnect_userdb($miniserv{'userdb'}, $dbh);
	$user{'proto'} = $proto;
	}
else {
	# Adding to local files
	&lock_file($ENV{'MINISERV_CONFIG'});
	if ($user{'theme'}) {
		$miniserv{"preroot_".$user{'name'}} =
			$user{'theme'}.($user{'overlay'} ? " ".$user{'overlay'} : "");
		}
	elsif (defined($user{'theme'})) {
		$miniserv{"preroot_".$user{'name'}} = "";
		}
	if (defined($user{'logouttime'})) {
		my @logout = split(/\s+/, $miniserv{'logouttimes'});
		push(@logout, "$user{'name'}=$user{'logouttime'}");
		$miniserv{'logouttimes'} = join(" ", @logout);
		}
	&put_miniserv_config(\%miniserv);
	&unlock_file($ENV{'MINISERV_CONFIG'});

	my @times;
	push(@times, "days", $user{'days'}) if ($user{'days'} ne '');
	push(@times, "hours", $user{'hoursfrom'}."-".$user{'hoursto'})
		if ($user{'hoursfrom'});
	&lock_file($miniserv{'userfile'});
	&open_tempfile(PWFILE, ">>$miniserv{'userfile'}");
	&print_tempfile(PWFILE,
		"$user{'name'}:$user{'pass'}:$user{'sync'}:$user{'cert'}:",
		($user{'allow'} ? "allow $user{'allow'}" :
		 $user{'deny'} ? "deny $user{'deny'}" : ""),":",
		join(" ", @times),":",
		$user{'lastchange'},":",
		join(" ", @{$user{'olds'}}),":",
		$user{'minsize'},":",
		$user{'nochange'},":",
		$user{'temppass'},
		"\n");
	&close_tempfile(PWFILE);
	&unlock_file($miniserv{'userfile'});

	&lock_file(&acl_filename());
	&open_tempfile(ACL, ">>".&acl_filename());
	&print_tempfile(ACL, &acl_line(\%user, \@mods));
	&close_tempfile(ACL);
	&unlock_file(&acl_filename());

	delete($gconfig{"lang_".$user{'name'}});
	$gconfig{"lang_".$user{'name'}} = $user{'lang'} if ($user{'lang'});
	delete($gconfig{"notabs_".$user{'name'}});
	$gconfig{"notabs_".$user{'name'}} = $user{'notabs'} if ($user{'notabs'});
	delete($gconfig{"skill_".$user{'name'}});
	$gconfig{"skill_".$user{'name'}} = $user{'skill'} if ($user{'skill'});
	delete($gconfig{"risk_".$user{'name'}});
	$gconfig{"risk_".$user{'name'}} = $user{'risk'} if ($user{'risk'});
	delete($gconfig{"rbacdeny_".$user{'name'}});
	$gconfig{"rbacdeny_".$user{'name'}} = $user{'rbacdeny'} if ($user{'rbacdeny'});
	delete($gconfig{"ownmods_".$user{'name'}});
	$gconfig{"ownmods_".$user{'name'}} = join(" ", @{$user{'ownmods'}})
		if (@{$user{'ownmods'}});
	delete($gconfig{"theme_".$user{'name'}});
	if ($user{'theme'}) {
		$gconfig{"theme_".$user{'name'}} =
			$user{'theme'}.($user{'overlay'} ? " ".$user{'overlay'} : "");
		}
	elsif (defined($user{'theme'})) {
		$gconfig{"theme_".$user{'name'}} = '';
		}
	$gconfig{"readonly_".$user{'name'}} = $user{'readonly'}
		if (defined($user{'readonly'}));
	$gconfig{"realname_".$user{'name'}} = $user{'real'}
		if (defined($user{'real'}));
	&write_file("$config_directory/config", \%gconfig);
	}

# Copy ACLs from user being cloned
if ($clone) {
	&copy_acl_files($clone, $user{'name'}, [ "", @mods ]);
	}
}

=head2 modify_user(old-name, &details)

Updates an existing Webmin user, identified by the old-name paramter. The
details hash must be in the same format as returned by list_users or passed
to create_user.

=cut
sub modify_user
{
my $username = $_[0];
my %user = %{$_[1]};
my (%miniserv, @pwfile, @acl, @mods, $m);
local $_;
&get_miniserv_config(\%miniserv);

if ($user{'proto'}) {
	# In users and groups DB
	my ($dbh, $proto) = &connect_userdb($miniserv{'userdb'});
	&error("Failed to connect to user database : $dbh") if (!ref($dbh));
	if ($proto eq "mysql" || $proto eq "postgresql") {
		# Get old password, for change detection
		my $cmd = $dbh->prepare(
			"select pass from webmin_user where id = ?");
		$cmd && $cmd->execute($user{'id'}) ||
			&error("Failed to get old password : ".$dbh->errstr);
		my ($oldpass) = $cmd->fetchrow();
		$cmd->finish();
		&add_old_password(\%user, $oldpass, \%miniserv);

		# Update primary details
		my $cmd = $dbh->prepare("update webmin_user set name = ?, ".
				        "pass = ? where id = ?");
		$cmd && $cmd->execute($user{'name'}, $user{'pass'},
				      $user{'id'}) ||
			&error("Failed to update user : ".$dbh->errstr);
		$cmd->finish();

		# Re-save attributes
		my $cmd = $dbh->prepare("delete from webmin_user_attr ".
					"where id = ?");
		$cmd && $cmd->execute($user{'id'}) ||
			&error("Failed to delete attrs : ".$dbh->errstr);
		my $cmd = $dbh->prepare("insert into webmin_user_attr ".
					"(id,attr,value) values (?, ?, ?)");
		foreach my $attr (keys %user) {
			next if ($attr eq "name" || $attr eq "pass");
			my $value = $user{$attr};
			if ($attr eq "olds" || $attr eq "modules" ||
			    $attr eq "ownmods") {
				$value = join(" ", @$value);
				}
			$cmd->execute($user{'id'}, $attr, $value) ||
				&error("Failed to add user attribute : ".
					$dbh->errstr);
			$cmd->finish();
			}
		}
	elsif ($proto eq "ldap") {
		# XXX update in ldap
		}
	}
else {
	# In local files
	&lock_file($ENV{'MINISERV_CONFIG'});
	delete($miniserv{"preroot_".$username});
	if ($user{'theme'}) {
		$miniserv{"preroot_".$user{'name'}} =
		  $user{'theme'}.($user{'overlay'} ? " ".$user{'overlay'} : "");
		}
	elsif (defined($user{'theme'})) {
		$miniserv{"preroot_".$user{'name'}} = "";
		}
	local @logout = split(/\s+/, $miniserv{'logouttimes'});
	@logout = grep { $_ !~ /^$username=/ } @logout;
	if (defined($user{'logouttime'})) {
		push(@logout, "$user{'name'}=$user{'logouttime'}");
		}
	$miniserv{'logouttimes'} = join(" ", @logout);
	&put_miniserv_config(\%miniserv);
	&unlock_file($ENV{'MINISERV_CONFIG'});

	local @times;
	push(@times, "days", $user{'days'}) if ($user{'days'} ne '');
	push(@times, "hours", $user{'hoursfrom'}."-".$user{'hoursto'})
		if ($user{'hoursfrom'});
	&lock_file($miniserv{'userfile'});
	open(PWFILE, $miniserv{'userfile'});
	@pwfile = <PWFILE>;
	close(PWFILE);
	&open_tempfile(PWFILE, ">$miniserv{'userfile'}");
	foreach (@pwfile) {
		if (/^([^:]+):([^:]*)/ && $1 eq $username) {
			&add_old_password(\%user, "$2", \%miniserv);
			&print_tempfile(PWFILE,
				"$user{'name'}:$user{'pass'}:",
				"$user{'sync'}:$user{'cert'}:",
				($user{'allow'} ? "allow $user{'allow'}" :
				 $user{'deny'} ? "deny $user{'deny'}" : ""),":",
				join(" ", @times),":",
				$user{'lastchange'},":",
				join(" ", @{$user{'olds'}}),":",
				$user{'minsize'},":",
				$user{'nochange'},":",
				$user{'temppass'},
				"\n");
			}
		else {
			&print_tempfile(PWFILE, $_);
			}
		}
	&close_tempfile(PWFILE);
	&unlock_file($miniserv{'userfile'});

	&lock_file(&acl_filename());
	@mods = &list_modules();
	open(ACL, &acl_filename());
	@acl = <ACL>;
	close(ACL);
	&open_tempfile(ACL, ">".&acl_filename());
	foreach (@acl) {
		if (/^(\S+):/ && $1 eq $username) {
			&print_tempfile(ACL, &acl_line($_[1], \@mods));
			}
		else {
			&print_tempfile(ACL, $_);
			}
		}
	&close_tempfile(ACL);
	&unlock_file(&acl_filename());

	delete($gconfig{"lang_".$username});
	$gconfig{"lang_".$user{'name'}} = $user{'lang'} if ($user{'lang'});
	delete($gconfig{"notabs_".$username});
	$gconfig{"notabs_".$user{'name'}} = $user{'notabs'}
		if ($user{'notabs'});
	delete($gconfig{"skill_".$username});
	$gconfig{"skill_".$user{'name'}} = $user{'skill'} if ($user{'skill'});
	delete($gconfig{"risk_".$username});
	$gconfig{"risk_".$user{'name'}} = $user{'risk'} if ($user{'risk'});
	delete($gconfig{"rbacdeny_".$username});
	$gconfig{"rbacdeny_".$user{'name'}} = $user{'rbacdeny'}
		if ($user{'rbacdeny'});
	delete($gconfig{"ownmods_".$username});
	$gconfig{"ownmods_".$user{'name'}} = join(" ", @{$user{'ownmods'}})
		if (@{$user{'ownmods'}});
	delete($gconfig{"theme_".$username});
	if ($user{'theme'}) {
		$gconfig{"theme_".$user{'name'}} =
		  $user{'theme'}.($user{'overlay'} ? " ".$user{'overlay'} : "");
		}
	elsif (defined($user{'theme'})) {
		$gconfig{"theme_".$user{'name'}} = '';
		}
	delete($gconfig{"readonly_".$username});
	$gconfig{"readonly_".$user{'name'}} = $user{'readonly'}
		if (defined($user{'readonly'}));
	delete($gconfig{"realname_".$username});
	$gconfig{"realname_".$user{'name'}} = $user{'real'}
		if (defined($user{'real'}));
	&write_file("$config_directory/config", \%gconfig);
	}

if ($username ne $user{'name'} && !$user{'proto'}) {
	# Rename all .acl files if user renamed
	foreach $m (@mods, "") {
		local $file = "$config_directory/$m/$username.acl";
		if (-r $file) {
			&rename_file($file,
				"$config_directory/$m/$user{'name'}.acl");
			}
		}
	local $file = "$config_directory/$username.acl";
	if (-r $file) {
		&rename_file($file, "$config_directory/$user{'name'}.acl");
		}
	}

if ($miniserv{'session'} && $username ne $user{'name'}) {
	# Modify all sessions for the renamed user
	&rename_session_user(\&miniserv, $username, $user{'name'});
	}
}

=head2 add_old_password(&user, oldpass, &miniserv)

Internal function to update the olds list of old passwords for a user

=cut
sub add_old_password
{
my ($user, $oldpass, $miniserv) = @_;
if ($oldpass ne $user->{'pass'} &&
    "!".$oldpass ne $user->{'pass'} &&
    $oldpass ne "!".$user->{'pass'} &&
    $user->{'pass'} ne 'x' &&
    $user->{'pass'} ne 'e' &&
    $user->{'pass'} ne '*LK*') {
	# Password change detected .. update change time
	# and save the old one
	local $nolock = $oldpass;
	$nolock =~ s/^\!//;
	unshift(@{$user->{'olds'}}, $nolock);
	if ($miniserv->{'pass_oldblock'}) {
		while(scalar(@{$user->{'olds'}}) >
		      $miniserv->{'pass_oldblock'}) {
			pop(@{$user->{'olds'}});
			}
		}
	$user->{'lastchange'} = time();
	}
}

=head2 delete_user(name)

Deletes the named user, including all .acl files for detailed module access
control settings.

=cut
sub delete_user
{
my ($username) = @_;
my (@pwfile, @acl, %miniserv);
local $_;

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
delete($miniserv{"preroot_".$username});
my @logout = split(/\s+/, $miniserv{'logouttimes'});
@logout = grep { $_ !~ /^$username=/ } @logout;
$miniserv{'logouttimes'} = join(" ", @logout);
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

&lock_file($miniserv{'userfile'});
open(PWFILE, $miniserv{'userfile'});
@pwfile = <PWFILE>;
close(PWFILE);
&open_tempfile(PWFILE, ">$miniserv{'userfile'}");
foreach (@pwfile) {
	if (!/^([^:]+):/ || $1 ne $username) {
		&print_tempfile(PWFILE, $_);
		}
	}
&close_tempfile(PWFILE);
&unlock_file($miniserv{'userfile'});

&lock_file(&acl_filename());
open(ACL, &acl_filename());
@acl = <ACL>;
close(ACL);
&open_tempfile(ACL, ">".&acl_filename());
foreach (@acl) {
	if (!/^([^:]+):/ || $1 ne $username) {
		&print_tempfile(ACL, $_);
		}
	}
&close_tempfile(ACL);
&unlock_file(&acl_filename());

delete($gconfig{"lang_".$username});
delete($gconfig{"notabs_".$username});
delete($gconfig{"skill_".$username});
delete($gconfig{"risk_".$username});
delete($gconfig{"ownmods_".$username});
delete($gconfig{"theme_".$username});
delete($gconfig{"readonly_".$username});
&write_file("$config_directory/config", \%gconfig);

# Delete all module .acl files
&unlink_file(map { "$config_directory/$_/$username.acl" } &list_modules());
&unlink_file("$config_directory/$username.acl");

if ($miniserv{'session'}) {
	# Delete all sessions for the deleted user
	&delete_session_user(\%miniserv, $username);
	}

if ($miniserv{'userdb'}) {
	# Also delete from user database
	my ($dbh, $proto) = &connect_userdb($miniserv{'userdb'});
	&error("Failed to connect to user database : $dbh") if (!ref($dbh));
	if ($proto eq "mysql" || $proto eq "postgresql") {
		# Find the user with SQL query
		my $cmd = $dbh->prepare(
			"select id from webmin_user where name = ?");
		$cmd && $cmd->execute($username) ||
			&error("Failed to find user : ".$dbh->errstr);
		my ($id) = $cmd->fetchrow();
		$cmd->finish();

		if (defined($id)) {
			# Delete the user
			my $cmd = $dbh->prepare(
				"delete from webmin_user where id = ?");
			$cmd && $cmd->execute($id) ||
				&error("Failed to delete user : ".$dbh->errstr);
			$cmd->finish();

			# Delete attributes
			my $cmd = $dbh->prepare(
				"delete from webmin_user_attr where id = ?");
			$cmd && $cmd->execute($id) ||
				&error("Failed to delete user attrs : ".
				       $dbh->errstr);
			$cmd->finish();

			# Delete ACLs
			my $cmd = $dbh->prepare(
				"delete from webmin_user_acl where id = ?");
			$cmd && $cmd->execute($id) ||
				&error("Failed to delete user acls : ".
				       $dbh->errstr);
			$cmd->finish();
			}
		}
	elsif ($proto eq "ldap") {
		# Find user with LDAP query
		# XXX
		}
	&disconnect_userdb($miniserv{'userdb'}, $dbh);
	}
}

=head2 create_group(&group, [clone])

Add a new webmin group, based on the details in the group hash. The required
keys are :

=item name - Unique name of the group

=item modules - An array reference of module names

=item members - An array reference of group member names. Sub-groups must have their names prefixed with an @.

=cut
sub create_group
{
my %group = %{$_[0]};
my $clone = $_[1];
my %miniserv;
&get_miniserv_config(\%miniserv);

if ($miniserv{'userdb'} && !$miniserv{'userdb_addto'}) {
	# Adding to group database
	my ($dbh, $proto, $prefix, $args) =&connect_userdb($miniserv{'userdb'});
        &error("Failed to connect to group database : $dbh") if (!ref($dbh));
	if ($proto eq "mysql" || $proto eq "postgresql") {
		# Add group with SQL
		my $cmd = $dbh->prepare("insert into webmin_group (name,description) values (?, ?)");
		$cmd && $cmd->execute($group{'name'}, $group{'desc'}) ||
			&error("Failed to add group : ".$dbh->errstr);
		$cmd->finish();
		my $cmd = $dbh->prepare("select max(id) from webmin_group");
		$cmd->execute();
		my ($id) = $cmd->fetchrow();
		$cmd->finish();

		# Add other attributes
		my $cmd = $dbh->prepare("insert into webmin_group_attr (id,attr,value) values (?, ?, ?)");
		foreach my $attr (keys %group) {
			next if ($attr eq "name" || $attr eq "desc");
			my $value = $group{$attr};
			if ($attr eq "members" || $attr eq "modules" ||
			    $attr eq "ownmods") {
				$value = join(" ", @$value);
				}
			$cmd->execute($id, $attr, $value) ||
				&error("Failed to add group attribute : ".
					$dbh->errstr);
			$cmd->finish();
			}
		}
	elsif ($proto eq "ldap") {
		# Add group to LDAP
		my $dn = "cn=".$group{'name'}.",".$prefix;
		my @attrs = ( "objectClass", $args->{'groupclass'},
			      "cn", $group{'name'},
			      "webminDesc", $group{'desc'} );
		my @webminattrs;
		foreach my $attr (keys %group) {
			next if ($attr eq "name" || $attr eq "desc" ||
				 $attr eq "modules");
			my $value = $group{$attr};
			if ($attr eq "members" || $attr eq "ownmods") {
				$value = join(" ", @$value);
				}
			push(@webminattrs, $attr."=".$value);
			}
		if (@webminattrs) {
			push(@attrs, "webminAttr", \@webminattrs);
			}
		if (@{$group{'modules'}}) {
			push(@attrs, "webminModule", $group{'modules'});
			}
		my $rv = $dbh->add($dn, attr => \@attrs);
		if (!$rv || $rv->code) {
			&error("Failed to add group to LDAP : ".
			       ($rv ? $rv->error : "Unknown error"));
			}
		}
	&disconnect_userdb($miniserv{'userdb'}, $dbh);
	$group{'proto'} = $proto;
	}
else {
	# Adding to local files
	&lock_file("$config_directory/webmin.groups");
	open(GROUP, ">>$config_directory/webmin.groups");
	print GROUP &group_line(\%group),"\n";
	close(GROUP);
	&unlock_file("$config_directory/webmin.groups");
	}

if ($clone) {
	# Clone ACLs from original group
	&copy_acl_files($clone, $group{'name'}, [ "", &list_modules() ],
			"group", "group");
	}
}

=head2 modify_group(old-name, &group)

Update a webmin group, identified by the name parameter. The group's new
details are in the group hash ref, which must be in the same format as
returned by list_groups.

=cut
sub modify_group
{
my $groupname = $_[0];
my %group = %{$_[1]};
my %miniserv;
&get_miniserv_config(\%miniserv);

if ($group{'proto'}) {
	# In users and groups DB
	my ($dbh, $proto) = &connect_userdb($miniserv{'userdb'});
	&error("Failed to connect to group database : $dbh") if (!ref($dbh));
	if ($proto eq "mysql" || $proto eq "postgresql") {
		# Update primary details
		my $cmd = $dbh->prepare("update webmin_group set name = ?, ".
				        "description = ? where id = ?");
		$cmd && $cmd->execute($group{'name'}, $group{'desc'},
				      $group{'id'}) ||
			&error("Failed to update group : ".$dbh->errstr);
		$cmd->finish();

		# Re-save attributes
		my $cmd = $dbh->prepare("delete from webmin_group_attr ".
					"where id = ?");
		$cmd && $cmd->execute($group{'id'}) ||
			&error("Failed to delete attrs : ".$dbh->errstr);
		my $cmd = $dbh->prepare("insert into webmin_group_attr ".
					"(id,attr,value) values (?, ?, ?)");
		foreach my $attr (keys %group) {
			next if ($attr eq "name" || $attr eq "desc");
			my $value = $group{$attr};
			if ($attr eq "members" || $attr eq "modules" ||
			    $attr eq "ownmods") {
				$value = join(" ", @$value);
				}
			$cmd->execute($group{'id'}, $attr, $value) ||
				&error("Failed to add group attribute : ".
					$dbh->errstr);
			$cmd->finish();
			}
		}
	elsif ($proto eq "ldap") {
		# XXX update in ldap
		}
	}
else {
	# Update local file
	&lock_file("$config_directory/webmin.groups");
	local $lref = &read_file_lines("$config_directory/webmin.groups");
	foreach $l (@$lref) {
		if ($l =~ /^([^:]+):/ && $1 eq $groupname) {
			$l = &group_line(\%group);
			}
		}
	&flush_file_lines("$config_directory/webmin.groups");
	&unlock_file("$config_directory/webmin.groups");
	}

if ($groupname ne $group{'name'} && !$group{'proto'}) {
	# Rename all .gacl files if group renamed
	foreach my $m (@{$group{'modules'}}, "") {
		local $file = "$config_directory/$m/$groupname.gacl";
		if (-r $file) {
			&rename_file($file,
			     "$config_directory/$m/$group{'name'}.gacl");
			}
		}
	}
}

=head2 delete_group(name)

Delete a webmin group, identified by the name parameter.

=cut
sub delete_group
{
my ($groupname) = @_;
my %miniserv;
&get_miniserv_config(\%miniserv);

# Delete from local files
&lock_file("$config_directory/webmin.groups");
local $lref = &read_file_lines("$config_directory/webmin.groups");
@$lref = grep { !/^([^:]+):/ || $1 ne $groupname } @$lref;
&flush_file_lines();
&unlock_file("$config_directory/webmin.groups");
&unlink_file(map { "$config_directory/$_/$groupname.gacl" } &list_modules());

if ($miniserv{'userdb'}) {
	# Also delete from group database
	my ($dbh, $proto) = &connect_userdb($miniserv{'userdb'});
	&error("Failed to connect to group database : $dbh") if (!ref($dbh));
	if ($proto eq "mysql" || $proto eq "postgresql") {
		# Find the group with SQL query
		my $cmd = $dbh->prepare(
			"select id from webmin_group where name = ?");
		$cmd && $cmd->execute($groupname) ||
			&error("Failed to find group : ".$dbh->errstr);
		my ($id) = $cmd->fetchrow();
		$cmd->finish();

		if (defined($id)) {
			# Delete the group
			my $cmd = $dbh->prepare(
				"delete from webmin_group where id = ?");
			$cmd && $cmd->execute($id) ||
			    &error("Failed to delete group : ".$dbh->errstr);
			$cmd->finish();

			# Delete attributes
			my $cmd = $dbh->prepare(
				"delete from webmin_group_attr where id = ?");
			$cmd && $cmd->execute($id) ||
				&error("Failed to delete group attrs : ".
				       $dbh->errstr);
			$cmd->finish();

			# Delete ACLs
			my $cmd = $dbh->prepare(
				"delete from webmin_group_acl where id = ?");
			$cmd && $cmd->execute($id) ||
				&error("Failed to delete group acls : ".
				       $dbh->errstr);
			$cmd->finish();
			}
		}
	elsif ($proto eq "ldap") {
		# Find group with LDAP query
		# XXX
		}
	&disconnect_userdb($miniserv{'userdb'}, $dbh);
	}

}

=head2 group_line(&group)

Internal function to generate a group file line

=cut
sub group_line
{
return join(":", $_[0]->{'name'},
		 join(" ", @{$_[0]->{'members'}}),
		 join(" ", @{$_[0]->{'modules'}}),
		 $_[0]->{'desc'},
		 join(" ", @{$_[0]->{'ownmods'}}) );
}

=head2 acl_line(&user, &allmodules)

Internal function to generate an ACL file line.

=cut
sub acl_line
{
local(%user);
%user = %{$_[0]};
return "$user{'name'}: ".join(' ', @{$user{'modules'}})."\n";
}

=head2 can_edit_user(user, [&groups])

Returns 1 if the current Webmin user can edit some other user.

=cut
sub can_edit_user
{
return 1 if ($access{'users'} eq '*');
if ($access{'users'} eq '~') {
	return $base_remote_user eq $_[0];
	}
local $u;
local $glist = $_[1] ? $_[1] : [ &list_groups() ];
foreach $u (split(/\s+/, $access{'users'})) {
	if ($u =~ /^_(\S+)$/) {
		foreach $g (@$glist) {
			return 1 if ($g->{'name'} eq $1 &&
				     &indexof($_[0], @{$g->{'members'}}) >= 0);
			}
		}
	else {
		return 1 if ($u eq $_[0]);
		}
	}
return 0;
}

=head2 open_session_db(\%miniserv)

Opens the session database, and ties it to the sessiondb hash. Parameters are :

=item miniserv - The Webmin miniserv.conf file as a hash ref, as supplied by get_miniserv_config

=cut
sub open_session_db
{
local $sfile = $_[0]->{'sessiondb'} ? $_[0]->{'sessiondb'} :
	       $_[0]->{'pidfile'} =~ /^(.*)\/[^\/]+$/ ? "$1/sessiondb"
						      : return;
eval "use SDBM_File";
dbmopen(%sessiondb, $sfile, 0700);
eval { $sessiondb{'1111111111'} = 'foo bar' };
if ($@) {
	dbmclose(%sessiondb);
	eval "use NDBM_File";
	dbmopen(%sessiondb, $sfile, 0700);
	}
else {
	delete($sessiondb{'1111111111'});
	}
}

=head2 delete_session_id(\%miniserv, id)

Deletes one session from the database. Parameters are :

=item miniserv - The Webmin miniserv.conf file as a hash ref, as supplied by get_miniserv_config.

=item user - ID of the session to remove.

=cut
sub delete_session_id
{
return 1 if (&is_readonly_mode());
&open_session_db($_[0]);
local $ex = exists($sessiondb{$_[1]});
delete($sessiondb{$_[1]});
dbmclose(%sessiondb);
return $ex;
}

=head2 delete_session_user(\%miniserv, user)

Deletes all sessions for some user. Parameters are :

=item miniserv - The Webmin miniserv.conf file as a hash ref, as supplied by get_miniserv_config.

=item user - Name of the user whose sessions get removed.

=cut
sub delete_session_user
{
return 1 if (&is_readonly_mode());
&open_session_db($_[0]);
foreach my $s (keys %sessiondb) {
	local ($u,$t) = split(/\s+/, $sessiondb{$s});
	if ($u eq $_[1]) {
		delete($sessiondb{$s});
		}
	}
dbmclose(%sessiondb);
}

=head2 rename_session_user(\%miniserv, olduser, newuser)

Changes the username in all sessions for some user. Parameters are :

=item miniserv - The Webmin miniserv.conf file as a hash ref, as supplied by get_miniserv_config.

=item olduser - The original username.

=item newuser - The new username.

=cut
sub rename_session_user
{
return 1 if (&is_readonly_mode());
&open_session_db(\%miniserv);
foreach my $s (keys %sessiondb) {
	local ($u,$t) = split(/\s+/, $sessiondb{$s});
	if ($u eq $_[1]) {
		$sessiondb{$s} = "$_[2] $t";
		}
	}
dbmclose(%sessiondb);
}

=head2 update_members(&allusers, &allgroups, &modules, &members)

Update the modules for members users and groups of some group. The parameters
are :

=item allusers - An array ref of all Webmin users, as returned by list_users.

=item allgroups - An array ref of all Webmin groups.

=item modules - Modules to assign to members.

=item members - An array ref of member user and group names.

=cut
sub update_members
{
local $m;
foreach $m (@{$_[3]}) {
	if ($m !~ /^\@(.*)$/) {
		# Member is a user
		local ($u) = grep { $_->{'name'} eq $m } @{$_[0]};
		if ($u) {
			$u->{'modules'} = [ @{$_[2]}, @{$u->{'ownmods'}} ];
			&modify_user($u->{'name'}, $u);
			}
		}
	else {
		# Member is a group
		local $gname = substr($m, 1);
		local ($g) = grep { $_->{'name'} eq $gname } @{$_[1]};
		if ($g) {
			$g->{'modules'} = [ @{$_[2]}, @{$g->{'ownmods'}} ];
			&modify_group($g->{'name'}, $g);
			&update_members($_[0], $_[1], $g->{'modules'},
					$g->{'members'});
			}
		}
	}
}

=head2 copy_acl_files(from, to, &modules, [from-type], [to-type])

Copy all .acl files from some user to another user in a list of modules.
The parameters are :

=item from - Source user or group name.

=item to - Destination user or group name.

=item modules - Array ref of module names.

=item from-type - Either "user" or "group", defaults to "user"

=item to-type - Either "user" or "group", defaults to "user"

=cut
sub copy_acl_files
{
my ($from, $to, $mods, $fromtype, $totype) = @_;
$fromtype ||= "user";
$totype ||= "user";
my ($dbh, $proto, $fromid, $toid);

# Check if the source user/group is in a DB
my $userdb = &get_userdb_string();
if ($userdb) {
	($dbh, $proto) = &connect_userdb($userdb);
	&error($dbh) if (!ref($dbh));
	if ($proto eq "mysql" || $proto eq "postgresql") {
		# Search in SQL DB
		my $cmd = $dbh->prepare(
			"select id from webmin_${fromtype} where name = ?");
		$cmd && $cmd->execute($from) || &error($dbh->errstr);
		($fromid) = $cmd->fetchrow();
		$cmd->finish();
		my $cmd = $dbh->prepare(
			"select id from webmin_${totype} where name = ?");
		$cmd && $cmd->execute($to) || &error($dbh->errstr);
		($toid) = $cmd->fetchrow();
		$cmd->finish();
		}
	elsif ($proto eq "ldap") {
		# Search in LDAP
		# XXX
		}
	}

if (defined($fromid) && defined($toid)) {
	# Copy from database to database
	if ($proto eq "mysql" || $proto eq "postgresql") {
		my $delcmd = $dbh->prepare("delete from webmin_${totype}_acl where id = ? and module = ?");
		my $cmd = $dbh->prepare("insert into webmin_${totype}_acl select ?,module,attr,value from webmin_${fromtype}_acl where id = ? and module = ?");
		foreach my $m (@$mods) {
			$delcmd && $delcmd->execute($toid, $m) ||
				&error("Failed to clear ACLs : ".$dbh->errstr);
			$delcmd->finish();
			$cmd && $cmd->execute($toid, $fromid, $m) ||
				&error("Failed to copy ACLs : ".$dbh->errstr);
			$cmd->finish();
			}
		}
	elsif ($proto eq "ldap") {
		# XXX
		}
	}
elsif (!defined($fromid) && !defined($toid)) {
	# Copy files
	my $fromsuffix = $fromtype eq "user" ? "acl" : "gacl";
	my $tosuffix = $totype eq "user" ? "acl" : "gacl";
	foreach my $m (@$mods) {
		&unlink_file("$config_directory/$m/$to.$tosuffix");
		my %acl;
		if (&read_file("$config_directory/$m/$from.$fromsuffix",
			       \%acl)) {
			&write_file("$config_directory/$m/$to.$tosuffix",
				    \%acl);
			}
		}
	}
else {
	# Source and dest use different storage types
	foreach my $m (@$mods) {
		my %caccess;
		if ($fromtype eq "user") {
			%caccess = &get_module_acl($from, $m, 1, 1);
			}
		else {
			%caccess = &get_group_module_acl($from, $m, 1);
			}
		if (%caccess) {
			if ($totype eq "user") {
				&save_module_acl(\%caccess, $to, $m, 1);
				}
			else {
				&save_group_module_acl(\%caccess, $to, $m, 1);
				}
			}
		}
	}
if ($dbh) {
	&disconnect_userdb($userdb, $dbh);
	}
}

=head2 copy_group_acl_files(from, to, &modules)

Copy all .gacl files from some group to another in a list of modules. Parameters
are :

=item from - Source group name.

=item to - Destination group name.

=item modules - Array ref of module names.

=cut
sub copy_group_acl_files
{
my ($from, $to, $mods) = @_;
&copy_acl_files($from, $to, $mods, "group", "group");
}

=head2 copy_group_user_acl_files(from, to, &modules)

Copy all .acl files from some group to a user in a list of modules. Parameters
are :

=item from - Source group name.

=item to - Destination user name.

=item modules - Array ref of module names.

=cut
sub copy_group_user_acl_files
{
my ($from, $to, $mods) = @_;
&copy_acl_files($from, $to, $mods, "group", "user");
}

=head2 set_acl_files(&allusers, &allgroups, module, &members, &access)

Recursively update the ACL for all sub-users and groups of a group, by copying
detailed access control settings from the group down to users. Parameters are :

=item allusers - An array ref of Webmin users, as returned by list_users.

=item allgroups - An array ref of Webmin groups.

=item module - Name of the module to update ACL for.

=item members - Names of group members.

=item access - The module ACL hash ref to copy to users.

=cut
sub set_acl_files
{
my ($allusers, $allgroups, $mod, $members, $access) = @_;
foreach my $m (@$members) {
	if ($m !~ /^\@(.*)$/) {
		# Member is a user
		local ($u) = grep { $_->{'name'} eq $m } @$allusers;
		if ($u) {
			local $aclfile =
				"$config_directory/$mod/$u->{'name'}.acl";
			&lock_file($aclfile);
			&save_module_acl($access, $u->{'name'}, $mod, 1);
			chmod(0640, $aclfile) if (-r $aclfile);
			&unlock_file($aclfile);
			}
		}
	else {
		# Member is a group
		local $gname = substr($m, 1);
		local ($g) = grep { $_->{'name'} eq $gname } @$allgroups;
		if ($g) {
			local $aclfile =
				"$config_directory/$mod/$g->{'name'}.gacl";
			&lock_file($aclfile);
			&save_group_module_acl($access, $g->{'name'}, $mod, 1);
			chmod(0640, $aclfile) if (-r $aclfile);
			&unlock_file($aclfile);
			&set_acl_files($allusers, $allgroups, $mod,
				       $g->{'members'}, $access);
			}
		}
	}
}

=head2 get_ssleay

Returns the path to the openssl command (or equivalent) on this system.

=cut
sub get_ssleay
{
if (&has_command($config{'ssleay'})) {
	return &has_command($config{'ssleay'});
	}
elsif (&has_command("openssl")) {
	return &has_command("openssl");
	}
elsif (&has_command("ssleay")) {
	return &has_command("ssleay");
	}
else {
	return undef;
	}
}

=head2 encrypt_password(password, [salt])

Encrypts and returns a Webmin user password. If the optional salt parameter
is not given, a salt will be selected randomly.

=cut
sub encrypt_password
{
local ($pass, $salt) = @_;
if ($gconfig{'md5pass'}) {
	# Use MD5 encryption
	$salt ||= '$1$'.substr(time(), -8).'$xxxxxxxxxxxxxxxxxxxxxx';
	return &encrypt_md5($pass, $salt);
	}
else {
	# Use Unix DES
	&seed_random();
	$salt ||= chr(int(rand(26))+65).chr(int(rand(26))+65);
	return &unix_crypt($pass, $salt);
	}
}

=head2 get_unixauth(\%miniserv)

Returns a list of Unix users/groups/all and the Webmin user that they
authenticate as, as array references.

=cut
sub get_unixauth
{
local @rv;
local @ua = split(/\s+/, $_[0]->{'unixauth'});
foreach my $ua (@ua) {
	if ($ua =~ /^(\S+)=(\S+)$/) {
		push(@rv, [ $1, $2 ]);
		}
	else {
		push(@rv, [ "*", $ua ]);
		}
	}
return @rv;
}

=head2 save_unixauth(\%miniserv, &authlist)

Updates %miniserv with the given Unix auth list, which must be in the format
returned by get_unixauth.

=cut
sub save_unixauth
{
local @ua;
foreach my $ua (@{$_[1]}) {
	if ($ua->[0] ne "*") {
		push(@ua, "$ua->[0]=$ua->[1]");
		}
	else {
		push(@ua, $ua->[1]);
		}
	}
$_[0]->{'unixauth'} = join(" ", @ua);
}

=head2 delete_from_groups(user|@group)

Removes the specified user from all groups.

=cut
sub delete_from_groups
{
local ($user) = @_;
foreach my $g (&list_groups()) {
	local @mems = @{$g->{'members'}};
	local $i = &indexof($user, @mems);
	if ($i >= 0) {
		splice(@mems, $i, 1);
		$g->{'members'} = \@mems;
		&modify_group($g->{'name'}, $g);
		}
	}
}

=head2 check_password_restrictions(username, password)

Checks if some new password is valid for a user, and if not returns
an error message.

=cut
sub check_password_restrictions
{
local ($name, $pass) = @_;
local %miniserv;
&get_miniserv_config(\%miniserv);
local ($user) = grep { $_->{'name'} eq $name } &list_users();
local $minsize = $user ? $user->{'minsize'} : undef;
$minsize ||= $miniserv{'pass_minsize'};
if (length($pass) < $minsize) {
	return &text('cpass_minsize', $minsize);
	}
foreach my $re (split(/\t+/, $miniserv{'pass_regexps'})) {
	if ($re =~ /^\!(.*)$/) {
		$re = $1;
		$pass !~ /$re/ || return ($miniserv{'pass_regdesc'} ||
					  $text{'cpass_notre'});
		}
	else {
		$pass =~ /$re/ || return ($miniserv{'pass_regdesc'} ||
					  $text{'cpass_re'});
		}
	}
if ($miniserv{'pass_nouser'}) {
	$pass =~ /\Q$name\E/i && return $text{'cpass_name'};
	}
if ($miniserv{'pass_nodict'}) {
	local $temp = &transname();
	&open_tempfile(TEMP, ">$temp", 0, 1);
	&print_tempfile(TEMP, $pass,"\n");
	&close_tempfile(TEMP);
	local $unknown;
	if (&has_command("ispell")) {
		open(SPELL, "ispell -a <$temp |");
		while(<SPELL>) {
			if (/^(#|\&|\?)/) {
				$unknown++;
				}
			}
		close(SPELL);
		}
	elsif (&has_command("spell")) {
		open(SPELL, "spell <$temp |");
		local $line = <SPELL>;
		$unknown++ if ($line);
		close(SPELL);
		}
	else {
		return &text('cpass_spellcmd', "<tt>ispell</tt>",
					       "<tt>spell</tt>");
		}
	$unknown || return $text{'cpass_dict'};
	}
if ($miniserv{'pass_oldblock'} && $user) {
	local $c = 0;
	foreach my $o (@{$user->{'olds'}}) {
		local $enc = &encrypt_password($pass, $o);
		$enc eq $o && return $text{'cpass_old'};
		last if ($c++ > $miniserv{'pass_oldblock'});
		}
	}
return undef;
}

=head2 hash_session_id(sid)

Returns an MD5 or Unix-crypted session ID.

=cut
sub hash_session_id
{
local ($sid) = @_;
local $use_md5 = &md5_perl_module();
if (!$hash_session_id_cache{$sid}) {
        if ($use_md5) {
                # Take MD5 hash
                $hash_session_id_cache{$sid} = &hash_md5_session($sid);
                }
        else {
                # Unix crypt
                $hash_session_id_cache{$sid} = &unix_crypt($sid, "XX");
                }
        }
return $hash_session_id_cache{$sid};
}

=head2 hash_md5_session(string)

Returns a string encrypted in MD5 format.

=cut
sub hash_md5_session
{
local $passwd = $_[0];
local $use_md5 = &md5_perl_module();

# Add the password
local $ctx = eval "new $use_md5";
$ctx->add($passwd);

# Add some more stuff from the hash of the password and salt
local $ctx1 = eval "new $use_md5";
$ctx1->add($passwd);
$ctx1->add($passwd);
local $final = $ctx1->digest();
for($pl=length($passwd); $pl>0; $pl-=16) {
	$ctx->add($pl > 16 ? $final : substr($final, 0, $pl));
	}

# This piece of code seems rather pointless, but it's in the C code that
# does MD5 in PAM so it has to go in!
local $j = 0;
local ($i, $l);
for($i=length($passwd); $i; $i >>= 1) {
	if ($i & 1) {
		$ctx->add("\0");
		}
	else {
		$ctx->add(substr($passwd, $j, 1));
		}
	}
$final = $ctx->digest();

# Convert the 16-byte final string into a readable form
local $rv;
local @final = map { ord($_) } split(//, $final);
$l = ($final[ 0]<<16) + ($final[ 6]<<8) + $final[12];
$rv .= &to64($l, 4);
$l = ($final[ 1]<<16) + ($final[ 7]<<8) + $final[13];
$rv .= &to64($l, 4);
$l = ($final[ 2]<<16) + ($final[ 8]<<8) + $final[14];
$rv .= &to64($l, 4);
$l = ($final[ 3]<<16) + ($final[ 9]<<8) + $final[15];
$rv .= &to64($l, 4);
$l = ($final[ 4]<<16) + ($final[10]<<8) + $final[ 5];
$rv .= &to64($l, 4);
$l = $final[11];
$rv .= &to64($l, 2);

return $rv;
}

=head2 md5_perl_module

Returns a Perl module for MD5 hashing, or undef if none.

=cut
sub md5_perl_module
{
eval "use MD5";
if (!$@) {
        $use_md5 = "MD5";
        }
else {
        eval "use Digest::MD5";
        if (!$@) {
                $use_md5 = "Digest::MD5";
                }
        }
}

=head2 session_db_key(sid)

Returns the session DB key for some session ID. Assumes that open_session_db
has already been called.

=cut
sub session_db_key
{
local ($sid) = @_;
local $hash = &hash_session_id($sid);
return $sessiondb{$hash} ? $hash : $sid;
}

=head2 setup_anonymous_access(path, module)

Grants anonymous access to some path. By default, the user for other anonymous
access will be used, or if there is none, a user named 'anonymous' will be
created and granted access to the module.

=cut
sub setup_anonymous_access
{
local ($path, $mod) = @_;

# Find out what users and paths we grant access to currently
my %miniserv;
&get_miniserv_config(\%miniserv);
local @anon = split(/\s+/, $miniserv{'anonymous'});
local $found = 0;
local $user;
foreach my $a (@anon) {
        local ($p, $u) = split(/=/, $a);
	$found++ if ($p eq $path);
	$user = $u;
	}
return 1 if ($found);		# Already setup

if (!$user) {
	# Create a user if need be
	$user = "anonymous";
	local $uinfo = { 'name' => $user,
			 'pass' => '*LK*',
			 'modules' => [ $mod ],
		       };
	&create_user($uinfo);
	}
else {
	# Make sure the user has the module
	local ($uinfo) = grep { $_->{'name'} eq $user } &list_users();
	if ($uinfo && &indexof($mod, @{$uinfo->{'modules'}}) < 0) {
		push(@{$uinfo->{'modules'}}, $mod);
		&modify_user($uinfo->{'name'}, $uinfo);
		}
	else {
		print STDERR "Anonymous access is granted to user $user, but he doesn't exist!\n";
		}
	}

# Grant access to the user and path
push(@anon, "$path=$user");
$miniserv{'anonymous'} = join(" ", @anon);
&put_miniserv_config(\%miniserv);
&reload_miniserv();
}

=head2 join_userdb_string(proto, user, pass, host, prefix, &args)

Creates a string in the format accepted by split_userdb_string

=cut
sub join_userdb_string
{
my ($proto, $user, $pass, $host, $prefix, $args) = @_;
return "" if (!$proto);
my $argstr;
if (keys %$args) {
	$argstr = "?".join("&", map { $_."=".$args->{$_} } (keys %$args));
	}
return $proto."://".$user.":".$pass."\@".$host."/".$prefix.$argstr;
}

=head2 validate_userdb(string, [no-table-check])

Checks if some user database is usable, and if not returns an error message

=cut
sub validate_userdb
{
my ($str, $notablecheck) = @_;
my ($proto, $user, $pass, $host, $prefix, $args) = &split_userdb_string($str);
if ($proto eq "mysql" || $proto eq "postgresql") {
	# Load DBI driver
	eval 'use DBI;';
	return &text('sql_emod', 'DBI') if ($@);
	if ($proto eq "mysql") {
		eval 'use DBD::mysql;';
		return &text('sql_emod', 'DBD::mysql') if ($@);
		my $drh = DBI->install_driver("mysql");
		return $text{'sql_emysqldriver'} if (!$drh);
		}
	else {
		eval 'use DBD::Pg;';
		return &text('sql_emod', 'DBD::Pg') if ($@);
		my $drh = DBI->install_driver("Pg");
		return $text{'sql_epostgresqldriver'} if (!$drh);
		}

	# Connect to the database
	my $dbh = &connect_userdb($str);
	ref($dbh) || return $dbh;

	# Validate critical tables
	if (!$notablecheck) {
		my %tables =
		  ( "webmin_user" => [ "id", "name", "pass" ],
		    "webmin_group" => [ "id", "name", "description" ],
		    "webmin_user_attr" => [ "id", "attr", "value" ],
		    "webmin_group_attr" => [ "id", "attr", "value" ],
		    "webmin_user_acl" => [ "id", "module", "attr", "value" ],
		    "webmin_group_acl" => [ "id", "module", "attr", "value"],
		  );
		foreach my $t (keys %tables) {
			my @cols = @{$tables{$t}};
			my $sql = "select ".join(",", @cols)." from $t limit 1";
			my $cmd = $dbh->prepare($sql);
			if (!$cmd || !$cmd->execute()) {
				return &text('sql_etable', $t,
					     &html_escape($dbh->errstr));
				}
			$cmd->finish();
			}
		}
	&disconnect_userdb($str, $dbh);
	return undef;
	}
elsif ($proto eq "ldap") {
	# Load LDAP module
	eval 'use Net::LDAP;';
	return &text('sql_emod', 'Net::LDAP') if ($@);

	# Try to connect
	my $dbh = &connect_userdb($str);
	ref($dbh) || return $dbh;

	# Check for Webmin object classes
	my $schema = $dbh->schema();
	my @allocs = map { $_->{'name'} }
			$schema->all_objectclasses();
	&indexof($args->{'userclass'}, @allocs) >= 0 ||
		return &text('sql_eclass', $args->{'userclass'});
	&indexof($args->{'groupclass'}, @allocs) >= 0 ||
		return &text('sql_eclass', $args->{'groupclass'});

	# Check that base DN exists
	if (!$notablecheck) {
		my $superprefix = $prefix;
		$superprefix =~ s/^[^,]+,//;	# Make parent DN
		my $rv = $dbh->search(base => $superprefix,
				      filter => '(objectClass=*)',
				      scope => 'one');
		my $niceprefix = lc($prefix);
		$niceprefix =~ s/\s//g;
		my $found = 0;
		foreach my $d ($rv->all_entries) {
			my $niced = lc($d->dn());
			$niced =~ s/\s//g;
			$found++ if ($niced eq $niceprefix);
			}
		$found || return &text('sql_eldapdn', $prefix);
		}
	&disconnect_userdb($str, $dbh);
	return undef;
	}
else {
	return "Unknown user database type $proto";
	}
}

=head2 userdb_table_sql(string)

Returns SQL statements needed to create all required tables. Mainly for
internal use.

=cut
sub userdb_table_sql
{
my ($str) = @_;
my ($key, $auto, $idattrkey);
if ($str =~ /^mysql:/) {
	return ( "create table webmin_user ".
		   "(id int(20) not null primary key auto_increment, ".
		   "name varchar(255) not null, pass varchar(255))",
		 "create table webmin_group ".
		   "(id int(20) not null primary key auto_increment, ".
		   "name varchar(255) not null, ".
		   "description varchar(255))",
		 "create table webmin_user_attr ".
		   "(id int(20) not null, ".
		   "attr varchar(32) not null, ".
		   "value varchar(255), ".
		   "primary key(id, attr))",
		 "create table webmin_group_attr ".
		   "(id int(20) not null, ".
		   "attr varchar(32) not null, ".
		   "value varchar(255), ".
		   "primary key(id, attr))",
		 "create table webmin_user_acl ".
		   "(id int(20) not null, ".
		   "module varchar(32) not null, ".
		   "attr varchar(32) not null, ".
		   "value varchar(255), ".
		   "primary key(id, module, attr))",
		 "create table webmin_group_acl ".
		   "(id int(20) not null, ".
		   "module varchar(32) not null, ".
		   "attr varchar(32) not null, ".
		   "value varchar(255), ".
		   "primary key(id, module, attr))",
		);
	}
elsif ($str =~ /^postgresql:/) {
	return ( "create table webmin_user ".
		   "(id serial not null primary key, ".
		   "name varchar(255), ".
		   "pass varchar(255))",
		 "create table webmin_group ".
		   "(id serial not null primary key, ".
		   "name varchar(255), ".
		   "description varchar(255))",
		 "create table webmin_user_attr ".
		   "(id int8 not null, ".
		   "attr varchar(255) not null, ".
		   "value varchar(255), ".
		   "primary key(id, attr))",
		 "create table webmin_group_attr ".
		   "(id int8 not null, ".
		   "attr varchar(255) not null, ".
		   "value varchar(255), ".
		   "primary key(id, attr))",
		 "create table webmin_user_acl ".
		   "(id int8 not null, ".
		   "module varchar(255) not null, ".
		   "attr varchar(255) not null, ".
		   "value varchar(255), ".
		   "primary key(id, module, attr))",
		 "create table webmin_group_acl ".
		   "(id int8 not null, ".
		   "module varchar(255) not null, ".
		   "attr varchar(255) not null, ".
		   "value varchar(255), ".
		   "primary key(id, module, attr))",
	       );
	}
}

1;

