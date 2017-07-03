# ldap-useradmin-lib.pl
# Module sponsored by
# Sanitaetsbetrieb Brixen  - Azienda Sanitaria di Bressanone
# www.sb-brixen.it         - www.as-bressanone.it

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("useradmin");
&foreign_require("ldap-client");
%access = &get_module_acl();
$useradmin::access{'udelete'} = 1;	# needed for users_table / groups_table
$useradmin::access{'gdelete'} = 1;

%utext = &load_language("useradmin");
foreach $t (keys %utext) {
	$text{$t} ||= $utext{$t};
	}
%mconfig = %useradmin::config;
foreach my $k (keys %config) {
	if ($config{$k} ne "") {
		$mconfig{$k} = $config{$k};
		}
	}

eval "use Net::LDAP";
if ($@) { $net_ldap_error = $@; }
else { $got_net_ldap++; }
eval "use Net::IMAP";
if ($@) { $net_imap_error = $@; }
else { $got_net_imap++; }

$secret_file = "/etc/ldap.secret";
$samba_class = $config{'samba_class'} || "sambaAccount";
$samba_class =~ s/^\s+//; $samba_class =~ s/\s+$//;
$samba_schema = lc($samba_class) eq lc("sambaSamAccount") ? 3 : 2;
$samba_group_class = $config{'samba_gclass'} || "sambaGroup";
$samba_group_class =~ s/^\s+//; $samba_group_class =~ s/\s+$//;
$samba_group_schema = lc($samba_group_class) eq lc("sambaSamGroup") ||
		      lc($samba_group_class) eq lc("sambaGroupMapping") ? 3 : 2;
$cyrus_class = $config{'imap_class'} || "SuSEeMailObject";
$cyrus_class =~ s/^\s+//; $cyrus_class =~ s/\s+$//;

if ($config{'charset'}) {
	$force_charset = $config{'charset'};
	}

# Search types
$match_modes = [ [ 0, $text{'index_equals'} ], [ 1, $text{'index_contains'} ],
                 [ 2, $text{'index_nequals'} ], [ 3, $text{'index_ncontains'} ],
		 [ 6, $text{'index_lower'} ], [ 7, $text{'index_higher'} ] ];

# ldap_connect(return-error)
# Connect to the LDAP server and return a handle to the Net::LDAP object
sub ldap_connect
{
my $cfile = &ldap_client::get_ldap_config_file();
if (!$cfile || !-r $cfile) {
	# LDAP client config file not known .. force manual specification
	foreach my $f ("ldap_host", "login") {
		if (!$config{$f}) {
			if ($_[0]) { return $text{'conn_e'.$f}; }
			else { &error($text{'conn_e'.$f}); }
			}
		}
	}

local $ldap = &ldap_client::generic_ldap_connect(
		$config{'ldap_host'}, $config{'ldap_port'},
		$config{'ldap_tls'}, $config{'login'}, $config{'pass'});
if (ref($ldap)) { return $ldap; }
elsif ($_[0]) { return $ldap; }
else { &error($ldap); }
}

# get_user_base()
sub get_user_base
{
local $conf = &ldap_client::get_config();
local $base = $config{'user_base'} ||
	      &ldap_client::find_svalue("nss_base_passwd", $conf) ||
	      &ldap_client::find_svalue("base", $conf);
$base =~ s/\?.*$//;
return $base;
}

# get_group_base()
sub get_group_base
{
local $conf = &ldap_client::get_config();
local $base = $config{'group_base'} ||
	      &ldap_client::find_svalue("nss_base_group", $conf) ||
	      &ldap_client::find_svalue("base", $conf);
$base =~ s/\?.*$//;
return $base;
}

# imap_connect(return-error)
# Connect and login to the IMAP server
sub imap_connect
{
local $imap = new Net::IMAP($config{'imap_host'});
if (!$imap) {
	local $err = &text('imap_econn', "<tt>$config{'imap_host'}</tt>");
	if ($_[0]) { return $err; }
	else { &error($err); }
	}
local $rv = $imap->login($config{'imap_login'}, $config{'imap_pass'});
if ($rv->{'Status'} ne 'ok') {
	local $err = &text('imap_elogin', "<tt>$config{'imap_host'}</tt>",
			   "<tt>$config{'imap_login'}</tt>", $rv->{'Text'});
	if ($_[0]) { return $err; }
	else { &error($err); }
	}
return $imap;
}

# samba_password(password)
# Converts a plain text string into two Samba passwords (nt and lm) with the
# ntpasswd program.
sub samba_password
{
local ($nt, $lm);
&foreign_check("samba") || &error($text{'usave_esamba'});
&foreign_require("samba", "smbhash.pl");
$nt = &samba::nthash($_[0]);
$lm = &samba::lmhash($_[0]);
return ($nt, $lm);
}

# encrypt_password(string, [salt])
sub encrypt_password
{
local ($pass, $salt) = @_;
&seed_random();
if ($config{'md5'} == 5) {
	# SHA encryption
	local $qp = quotemeta($pass);
	local $out = &backquote_command("$config{'slappasswd'} -h '{sha}' -s $qp 2>/dev/null");
	if ($out && !$?) {
		$out =~ s/\s+$//;
		$out =~ s/^\{sha\}//i;
		return $out;
		}
	# Fall back to built-in code
	$out = &useradmin::encrypt_sha1($pass);
	$out =~ s/^\{sha\}//i;
	return $out;
	}
if ($config{'md5'} == 4) {
	# LDAP SSHA encryption
	local $qp = quotemeta($pass);
	local $out = &backquote_command("$config{'slappasswd'} -h '{ssha}' -s $qp 2>/dev/null");
	if ($?) {
		&error("$config{'slappasswd'} command failed to generate ssha password : $out");
		}
	$out =~ s/\s+$//;
	$out =~ s/^\{ssha\}//i;
	return $out;
	}
if ($config{'md5'} == 3) {
	# LDAP MD5 encryption
	local $qp = quotemeta($pass);
	local $out = &backquote_command("$config{'slappasswd'} -h '{md5}' -s $qp 2>/dev/null");
	$out =~ s/\s+$//;
	$out =~ s/^\{md5\}//i;
	return $out;
	}
if ($config{'md5'} == 1) {
	# Unix MD5 encryption
	&foreign_require("useradmin", "user-lib.pl");
	return &useradmin::encrypt_md5($pass, $salt);
	}
elsif ($config{'md5'} == 0) {
	# Standard Unix crypt
	$salt ||= chr(int(rand(26))+65).chr(int(rand(26))+65);
	return &unix_crypt($pass, $salt);
	}
else {
	# No encryption!
	return $pass;
	}
}

# list_users()
# Returns a list of users, in the same format as the useradmin module
sub list_users
{
if (!scalar(@list_users_cache)) {
	local $ldap = &ldap_connect();
	local $base = &get_user_base();
	local $rv = $ldap->search(base => $base,
				  filter => &user_filter());
	local $u;
	foreach $u ($rv->all_entries) {
		local %uinfo = &dn_to_hash($u);
		push(@list_users_cache, \%uinfo);
		}
	$ldap->unbind();
	}
return @list_users_cache;
}

# create_user(&user)
# Given a user details hash in the same format as the useradmin module, add
# it to the LDAP database
sub create_user
{
local $ldap = &ldap_connect();
local $base = &get_user_base();
$_[0]->{'dn'} = "uid=$_[0]->{'user'},$base";
local @classes = ( "posixAccount", "shadowAccount",
		   split(/\s+/, $config{'other_class'}),
		   @{$_[0]->{'ldap_class'}} );
local $schema = $ldap->schema();
if ($schema->objectclass("person") && $config{'person'}) {
	push(@classes, "person");
	}
@classes = &uniquelc(@classes);
@classes = grep { /\S/ } @classes;	# Remove empty
local @attrs = &user_to_dn($_[0]);
push(@attrs, &split_props($config{'props'}, $_[0]));
push(@attrs, @{$_[0]->{'ldap_attrs'}});
push(@attrs, "objectClass" => \@classes);
if (&indexoflc("person", @classes) >= 0 && !&in_props(\@attrs, "sn")) {
	# Person needs 'sn'
	push(@attrs, "sn", &in_props(\@attrs, "cn"));
	}
local $rv = $ldap->add($_[0]->{'dn'}, attr => \@attrs);
if ($rv->code) {
	&error(&text('usave_eadd', $rv->error));
	}
push(@list_users_cache, $_[0]) if (scalar(@list_users_cache));
$ldap->unbind();
&useradmin::refresh_nscd() if (!$batch_mode);
}

# delete_user(&user)
# Given a user details hash in the same format as the useradmin module, removes
# it from the LDAP database
sub delete_user
{
local $ldap = &ldap_connect();
local $rv = $ldap->delete($_[0]->{'dn'});
if ($rv->code) {
	&error(&text('usave_edelete', $rv->error));
	}
$ldap->unbind();
@list_users_cache = grep { $_ ne $_[0] } @list_users_cache
        if (scalar(@list_users_cache));
&useradmin::refresh_nscd() if (!$batch_mode);
}

# modify_user(&olduser, &newuser)
sub modify_user
{
local $ldap = &ldap_connect();
local $base = &get_user_base();
local @attrs = &user_to_dn($_[1]);
push(@attrs, &split_props($config{'mod_props'}, $_[1]));
push(@attrs, @{$_[1]->{'ldap_attrs'}});
if ($_[1]->{'ldap_class'} &&
    (!ref($_[1]->{'ldap_class'}) || @{$_[1]->{'ldap_class'}})) {
	push(@attrs, "objectClass" => $_[1]->{'ldap_class'});
	}
if (&indexoflc("person", @{$_[1]->{'ldap_class'}}) >= 0 &&
    !&in_props(\@attrs, "sn")) {
	# Person needs 'sn'
	push(@attrs, "sn", &in_props(\@attrs, "cn"));
	}
local %replace;
for(my $i=0; $i<@attrs; $i+=2) {
	$replace{$attrs[$i]} ||= [ ];
	local $v = $attrs[$i+1];
	push(@{$replace{$attrs[$i]}}, ref($v) ? @$v : $v);
	}
if ($_[0]->{'pass'} eq $_[1]->{'pass'}) {
	# Don't change password attribute if not change
	delete($replace{'userPassword'});
	}
# Do rename to new DN first
if ($_[0]->{'user'} ne $_[1]->{'user'}) {
	local $newdn = $_[0]->{'dn'};
	if ($newdn !~ s/^uid=$_[0]->{'user'},/uid=$_[1]->{'user'},/) {
		$newdn = "uid=$_[1]->{'user'},$base";
		}
	if (!&same_dn($newdn, $_[0]->{'dn'})) {
		$rv = $ldap->moddn($_[0]->{'dn'},
				   newrdn => "uid=$_[1]->{'user'}");
		if ($rv->code) {
			&error(&text('usave_emoddn', $rv->error));
			}
		$_[1]->{'dn'} = $newdn;
		}
	}
local $rv = $ldap->modify($_[1]->{'dn'}, replace => \%replace);
if ($rv->code) {
	&error(&text('usave_emod', $rv->error));
	}
if ($_[0] ne $_[1] && &indexof($_[0], @list_users_cache) != -1) {
	# Update old object in cache
	%{$_[0]} = %{$_[1]};
	}
$ldap->unbind();
&useradmin::refresh_nscd() if (!$batch_mode);
}

# list_groups()
# Returns a list of groups, in the same format as the useradmin module
sub list_groups
{
if (!scalar(@list_groups_cache)) {
	local $ldap = &ldap_connect();
	local $base = &get_group_base();
	local $rv = $ldap->search(base => $base,
				  filter => &group_filter());
	local $g;
	foreach $g ($rv->all_entries) {
		local %ginfo = &dn_to_hash($g);
		push(@list_groups_cache, \%ginfo);
		}
	$ldap->unbind();
	}
return @list_groups_cache;
}

# create_group(&group)
# Given a group details hash in the same format as the useradmin module, add
# it to the LDAP database
sub create_group
{
local $ldap = &ldap_connect();
local $base = &get_group_base();
$_[0]->{'dn'} = "cn=$_[0]->{'group'},$base";
local @classes = ( "posixGroup" );
push(@classes, split(/\s+/, $config{'gother_class'}));
@classes = &uniquelc(@classes);
local @attrs = &group_to_dn($_[0]);
push(@attrs, @{$_[0]->{'ldap_attrs'}});
push(@attrs, "objectClass" => \@classes);
local $rv = $ldap->add($_[0]->{'dn'}, attr => \@attrs);
if ($rv->code) {
	&error(&text('gsave_eadd', $rv->error));
	}
push(@list_groups_cache, $_[0]) if (scalar(@list_groups_cache));
$ldap->unbind();
&useradmin::refresh_nscd() if (!$batch_mode);
}

# delete_group(&group)
# Given a group details hash in the same format as the useradmin module, removes
# it from the LDAP database
sub delete_group
{
local $ldap = &ldap_connect();
local $rv = $ldap->delete($_[0]->{'dn'});
if ($rv->code) {
	&error(&text('gsave_edelete', $rv->error));
	}
$ldap->unbind();
@list_groups_cache = grep { $_ ne $_[0] } @list_groups_cache
        if (scalar(@list_groups_cache));
&useradmin::refresh_nscd() if (!$batch_mode);
}

# modify_group(&oldgroup, &newgroup)
sub modify_group
{
local $ldap = &ldap_connect();
local $base = &get_group_base();
local @attrs = &group_to_dn($_[1]);
push(@attrs, @{$_[0]->{'ldap_attrs'}});
# Do rename to new DN first
if ($_[0]->{'group'} ne $_[1]->{'group'}) {
	local $newdn = $_[0]->{'dn'};
	if ($newdn !~ s/^cn=$_[0]->{'group'},/cn=$_[1]->{'group'},/) {
		$newdn = "cn=$_[1]->{'group'},$base";
		}
	if (!&same_dn($newdn, $_[0]->{'dn'})) {
		$rv = $ldap->moddn($_[0]->{'dn'}, newrdn => "cn=$_[1]->{'group'}");
		if ($rv->code) {
			&error(&text('gsave_emoddn', $rv->error));
			}
		$_[1]->{'dn'} = $newdn;
		}
	}
local $rv = $ldap->modify($_[1]->{'dn'}, replace => { @attrs });
if ($rv->code) {
	&error(&text('gsave_emod', $rv->error));
	}
if ($_[0] ne $_[1] && &indexof($_[0], @list_groups_cache) != -1) {
	# Update old object in cache
	%{$_[0]} = %{$_[1]};
	}
$ldap->unbind();
&useradmin::refresh_nscd() if (!$batch_mode);
}

# dn_to_hash(&ldap-object)
# Given a LDAP object containing user or group details, convert it to a hash
# in the same format uses by the useradmin module
sub dn_to_hash
{
if ($_[0]->get_value("uid")) {
	local %user = ( 'dn' => $_[0]->dn(),
			'user' => $_[0]->get_value("uid"),
			'uid' => $_[0]->get_value("uidNumber"),
			'gid' => $_[0]->get_value("gidNumber"),
			'real' => $_[0]->get_value("cn"),
			'home' => $_[0]->get_value("homeDirectory"),
			'shell' => $_[0]->get_value("loginShell"),
			'pass' => $_[0]->get_value("userPassword"),
			'change' => $_[0]->get_value("shadowLastChange") || "",
			'expire' => $_[0]->get_value("shadowExpire") || "",
			'min' => $_[0]->get_value("shadowMin") || "",
			'max' => $_[0]->get_value("shadowMax") || "",
			'warn' => $_[0]->get_value("shadowWarning") || "",
			'inactive' => $_[0]->get_value("shadowInactive") || "",
		      );
	$user{'pass'} =~ s/^(\!?)\{[a-z0-9]+\}/$1/i;
	$user{'all_ldap_attrs'} = { map { lc($_), scalar($_[0]->get_value($_)) }
					$_[0]->attributes() };
	$user{'ldap_class'} = [ $_[0]->get_value('objectClass') ];
	return %user;
	}
else {
	local @members = $_[0]->get_value('memberUid');
	local %group = ( 'dn' => $_[0]->dn(),
			 'group' => $_[0]->get_value("cn"),
			 'gid' => $_[0]->get_value("gidNumber"),
			 'pass' => $_[0]->get_value("userPassword") || "",
			 'members' => join(",", @members) || "",
			 'desc' => $_[0]->get_value("description"),
			);
	return %group;
	}
}

# user_to_dn(&user)
# Given a useradmin-style user hash, returns a list of properties
sub user_to_dn
{
local $pfx = $_[0]->{'pass'} =~ /^\{[a-z0-9]+\}/i ? undef :
	     $_[0]->{'pass'} =~ /^\$1\$/ ? "{md5}" :
	     $_[0]->{'pass'} =~ /^[a-zA-Z0-9\.\/]{13}$/ ? "{crypt}" :
	     $config{'md5'} == 1 || $config{'md5'} == 3 ? "{md5}" :
	     $config{'md5'} == 4 ? "{ssha}" : 
	     $config{'md5'} == 0 ? "{crypt}" : "";
local $pass = $_[0]->{'pass'};
local $disabled;
if ($pass =~ s/^\!//) {
	$disabled = "!";
	}
$cn = $_[0]->{'real'} eq '' ? $_[0]->{'user'} : $_[0]->{'real'};
return ( "cn" => $cn,
	 "uid" => $_[0]->{'user'},
	 "uidNumber" => $_[0]->{'uid'},
	 "loginShell" => $_[0]->{'shell'},
	 "homeDirectory" => $_[0]->{'home'},
	 "gidNumber" => $_[0]->{'gid'},
	 "userPassword" => $disabled.$pfx.$pass,
	 $_[0]->{'change'} eq '' ? ( ) :
		( "shadowLastChange" => $_[0]->{'change'} ),
	 $_[0]->{'expire'} eq '' ? ( ) :
		( "shadowExpire" => $_[0]->{'expire'} ),
	 $_[0]->{'min'} eq '' ? ( ) :
		( "shadowMin" => $_[0]->{'min'} ),
	 $_[0]->{'max'} eq '' ? ( ) :
		( "shadowMax" => $_[0]->{'max'} ),
	 $_[0]->{'warn'} eq '' ? ( ) :
		( "shadowWarning" => $_[0]->{'warn'} ),
	 $_[0]->{'inactive'} eq '' ? ( ) :
		( "shadowInactive" => $_[0]->{'inactive'} )
	);
}

sub group_to_dn
{
local @members = split(/,/, $_[0]->{'members'});
return ( "cn" => $_[0]->{'group'},
	 "gidNumber" => $_[0]->{'gid'},
	 "userPassword" => $_[0]->{'pass'},
	 @members ? ( "memberUid" => \@members ) : ( ),
	 defined($_[0]->{'desc'}) ? ( "description" => $_[0]->{'desc'} ) : ( ),
       );
}

# making_changes()
# Called before the LDAP database has been updated, to run the pre-changes
# command.
sub making_changes
{
if ($config{'pre_command'} =~ /\S/) {
	local $out = &backquote_logged("($config{'pre_command'}) 2>&1 </dev/null");
	return $? ? $out : undef;
	}
return undef;
}

# made_changes()
# Called after the LDAP database has been updated, to run the post-changes
# command.
sub made_changes
{
if ($config{'post_command'} =~ /\S/) {
	local $out = &backquote_logged("($config{'post_command'}) 2>&1 </dev/null");
	return $? ? $out : undef;
	}
return undef;
}

# set_user_envs(&hash, action, [plainpass], [secondary],
#		[&olduser], [oldplainpass])
# Just call the useradmin function of the same name
sub set_user_envs
{
local $rv = &useradmin::set_user_envs(@_);
if ($_[0]->{'all_ldap_attrs'}) {
	foreach my $a (keys %{$_[0]->{'all_ldap_attrs'}}) {
		my $v = $_[0]->{'all_ldap_attrs'}->{$a};
		$ENV{'USERADMIN_LDAP_'.uc($a)} = $v;
		}
	}
if ($_[5]->{'all_ldap_attrs'}) {
	foreach my $a (keys %{$_[5]->{'all_ldap_attrs'}}) {
		my $v = $_[5]->{'all_ldap_attrs'}->{$a};
		$ENV{'USERADMIN_OLD_LDAP_'.uc($a)} = $v;
		}
	}
return $rv;
}

# Just call the useradmin function of the same name
sub set_group_envs
{
return &useradmin::set_group_envs(@_);
}

# Locks a dummy file, to indicate that the DB is in use
sub lock_user_files
{
&lock_file("$module_config_directory/ldapdb");
}

sub unlock_user_files
{
&unlock_file("$module_config_directory/ldapdb");
}

# split_props(text, &user)
sub split_props
{
local %pmap;
foreach $p (split(/\t+/, &substitute_template($_[0], $_[1]))) {
	if ($p =~ /^(\S+):\s*(.*)/) {
		push(@{$pmap{$1}}, $2);
		}
	}
local @rv;
local $k;
foreach $k (keys %pmap) {
	local $v = $pmap{$k};
	if (@$v == 1) {
		push(@rv, $k, $v->[0]);
		}
	else {
		push(@rv, $k, $v);
		}
	}
return @rv;
}

# build_user_used([&uid-hash], [&shell-list], [&username-hash])
# Fills in a hash with used UIDs, shells and usernames
sub build_user_used
{
setpwent();
local @u;
while(@u = getpwent()) {
	$_[0]->{$u[2]}++ if ($_[0]);
	push(@{$_[1]}, $u[8]) if ($_[1] && $u[8]);
	$_[2]->{$u[0]}++ if ($_[2]);
	}
endpwent();
local $u;
foreach $u (&list_users()) {
	$_[0]->{$u->{'uid'}}++ if ($_[0]);
	push(@{$_[1]}, $u->{'shell'}) if ($_[1] && $u->{'shell'});
	$_[2]->{$u->{'user'}}++ if ($_[2]);
	}
}

# build_group_used([&uid-hash], [&groupname-hash])
sub build_group_used
{
setgrent();
local @g;
while(@g = getgrent()) {
	$_[0]->{$g[2]}++ if ($_[0]);
	$_[1]->{$g[0]}++ if ($_[1]);
	}
endgrent();
local $g;
foreach $g (&list_groups()) {
	$_[0]->{$g->{'gid'}}++ if ($_[0]);
	$_[1]->{$g->{'group'}}++ if ($_[1]);
	}
}

# allocate_uid(&uids-used)
sub allocate_uid
{
local $rv = $mconfig{'base_uid'};
while($_[0]->{$rv}) {
	$rv++;
	}
return $rv;
}

# allocate_gid(&gids-used)
sub allocate_gid
{
local $rv = $mconfig{'base_gid'};
while($_[0]->{$rv}) {
	$rv++;
	}
return $rv;
}

# check_uid_used(&ldap, uid)
# Returns 1 if some UID has been already used, either by LDAP or a local user
sub check_uid_used
{
local ($ldap, $uid) = @_;
local $localuser = getpwuid($uid);
return 1 if ($localuser);
local $rv = $ldap->search('base' => &get_user_base(),
			  'filter' => "(uidNumber=$uid)");
return $rv->count ? 1 : 0;
}

# check_user_used(&ldap, user)
# Returns 1 if some username has been already used, either by LDAP or a
# local user
sub check_user_used
{
local ($ldap, $user) = @_;
local @localuser = getpwnam($user);
return 1 if (@localuser);
local $rv = $ldap->search('base' => &get_user_base(),
			  'filter' => "(uid=$user)");
return $rv->count ? 1 : 0;
}

# check_gid_used(&ldap, gid)
# Returns 1 if some GID has been already used, either by LDAP or a local group
sub check_gid_used
{
local ($ldap, $gid) = @_;
local $localgroup = getgrgid($gid);
return 1 if ($localgroup);
local $rv = $ldap->search('base' => &get_group_base(),
			  'filter' => "(gidNumber=$gid)");
return $rv->count ? 1 : 0;
}

# check_group_used(&ldap, group)
# Returns 1 if some groupname has been already used, either by LDAP or a
# local group
sub check_group_used
{
local ($ldap, $group) = @_;
local @localgroup = getgrnam($group);
return 1 if (@localgroup);
local $rv = $ldap->search('base' => &get_group_base(),
			  'filter' => "(cn=$group)");
return $rv->count ? 1 : 0;
}

# same_dn(dn1, dn2)
# Returns 1 if two DNs are the same
sub same_dn
{
local $dn0 = join(",", split(/,\s*/, $_[0]));
local $dn1 = join(",", split(/,\s*/, $_[1]));
return lc($dn0) eq lc($dn1);
}

# all_getpwnam(username)
# Look up a user by name, and return his details in array format. Searches
# both LDAP and the local users DB.
sub all_getpwnam
{
local @uinfo = getpwnam($_[0]);
if (scalar(@uinfo)) {
	return wantarray ? @uinfo : $uinfo[2];
	}
local $u;
foreach $u (&list_users()) {
	return &pw_user_rv($u, wantarray, 'uid')
		if ($u->{'user'} eq $_[0]);
	}
return wantarray ? () : undef;
}

# all_getpwuid(uid)
# Look up a user by UID, and return his details in array format. Searches
# both LDAP and the local users DB.
sub all_getpwuid
{
local @uinfo = getpwuid($_[0]);
if (scalar(@uinfo)) {
	return wantarray ? @uinfo : $uinfo[0];
	}
local $u;
foreach $u (&list_users()) {
	return &pw_user_rv($u, wantarray, 'user')
		if ($u->{'uid'} == $_[0]);
	}
return wantarray ? () : undef;
}

# all_getgrgid(gid)
# Look up a group by GID, and return its details in array format. Searches
# both LDAP and the local groups DB.
sub all_getgrgid
{
local @ginfo = getgrgid($_[0]);
if (scalar(@ginfo)) {
	return wantarray ? @ginfo : $ginfo[0];
	}
local $g;
foreach $g (&list_groups()) {
	return &gr_group_rv($g, wantarray, 'group')
		if ($g->{'gid'} == $_[0]);
	}
return wantarray ? () : undef;
}

# all_getgrnam(groupname)
# Look up a group by name, and return its details in array format. Searches
# both LDAP and the local groups DB.
sub all_getgrnam
{
local @ginfo = getgrnam($_[0]);
if (scalar(@ginfo)) {
	return wantarray ? @ginfo : $ginfo[2];
	}
local $g;
foreach $g (&list_groups()) {
	return &gr_group_rv($g, wantarray, 'gid')
		if ($g->{'group'} eq $_[0]);
	}
return wantarray ? () : undef;
}

sub gr_group_rv
{
return $_[1] ? ( $_[0]->{'group'}, $_[0]->{'pass'}, $_[0]->{'gid'},
		 $_[0]->{'members'} ) : $_[0]->{$_[2]};
}

sub pw_user_rv
{
return $_[0] ? ( $_[0]->{'user'}, $_[0]->{'pass'}, $_[0]->{'uid'},
		 $_[0]->{'gid'}, undef, undef, $_[0]->{'real'},
		 $_[0]->{'home'}, $_[0]->{'shell'}, undef ) : $_[0]->{$_[2]};
}

# auto_home_dir(base, username, groupname)
# Returns an automatically generated home directory, and creates needed
# parent dirs
sub auto_home_dir
{
local $pfx = $_[0] eq "/" ? "/" : $_[0]."/";
if ($mconfig{'home_style'} == 0) {
	return $pfx.$_[1];
	}
elsif ($mconfig{'home_style'} == 1) {
	&useradmin::mkdir_if_needed($pfx.substr($_[1], 0, 1));
	return $pfx.substr($_[1], 0, 1)."/".$_[1];
	}
elsif ($mconfig{'home_style'} == 2) {
	&useradmin::mkdir_if_needed($pfx.substr($_[1], 0, 1));
	&useradmin::mkdir_if_needed($pfx.substr($_[1], 0, 1)."/".
			 substr($_[1], 0, 2));
	return $pfx.substr($_[1], 0, 1)."/".
	       substr($_[1], 0, 2)."/".$_[1];
	}
elsif ($mconfig{'home_style'} == 3) {
	&useradmin::mkdir_if_needed($pfx.substr($_[1], 0, 1));
	&useradmin::mkdir_if_needed($pfx.substr($_[1], 0, 1)."/".
			 substr($_[1], 1, 1));
	return $pfx.substr($_[1], 0, 1)."/".
	       substr($_[1], 1, 1)."/".$_[1];
	}
elsif ($mconfig{'home_style'} == 4) {
	return $_[0];
	}
elsif ($mconfig{'home_style'} == 5) {
	return $pfx.$_[2]."/".$_[1];
	}
}

# imap_error(text, &rv)
sub imap_error
{
&error_setup(undef);
&error(&text('usave_eimap', $_[0], $_[1]->{'Text'}));
}

# setup_imap(&user, quota-in-kb)
# Create an IMAP account for a user
sub setup_imap
{
local ($user, $quota) = @_;

# Check if the user already exists
local $imap = &imap_connect();
local $rv = $imap->status("user".$user{'imap_foldersep'}.$user->{'user'}, "messages");
if ($rv->{'Status'} eq 'ok') {
	# Already exists, so do nothing
	$imap->logout();
	}
else {
	# Create the user on the IMAP server
	$rv = $imap->create("user".$config{'imap_foldersep'}.$user->{'user'});
	$rv->{'Status'} eq 'ok' ||
		&imap_error($text{'usave_eicreate'}, $rv);

	# Grant all rights to admin user
	$rv = $imap->setacl("user".$config{'imap_foldersep'}.$user->{'user'},
			    $config{'imap_login'}, "lrswipcda");
	$rv->{'Status'} eq 'ok' ||
		&imap_error($text{'usave_eiacl'}, $rv);

	if (defined($quota) && $config{'quota_support'}) {
		# Set his IMAP quota
		$rv = $imap->setquota("user".$config{'imap_foldersep'}.$user->{'user'},
				      "STORAGE", $quota);
		$rv->{'Status'} eq 'ok' ||
			&imap_error($text{'usave_eiquota'}, $rv);
		}

	# Subscribe the user to his inbox by logging in
	# as him
	$imap->logout();
	$uimap = new Net::IMAP($config{'imap_host'});
	$rv = $uimap->login($user->{'user'}, $user->{'plainpass'});
	$rv->{'Status'} eq 'ok' ||
		&imap_error($text{'usave_eilogin'}, $rv);
	$rv = $uimap->subscribe("INBOX");
	$rv->{'Status'} eq 'ok' ||
		&imap_error(&text('usave_eisub', "INBOX"), $rv);

	foreach $f (split(/\t+/, $config{'imap_folders'})) {
		local $fp = $config{'imap_folderalt'} ?
				"user$config{'imap_foldersep'}$user->{'user'}$config{'imap_foldersep'}$f" : $f;
		$rv = $uimap->create($fp);
		$rv->{'Status'} eq 'ok' ||
		    &imap_error(&text('usave_eifolder',$f),$rv);
		$rv = $uimap->subscribe($fp);
		$rv->{'Status'} eq 'ok' ||
		    &imap_error(&text('usave_eisub', $f), $rv);
		}

	$uimap->logout();
	}

# Re-connect for later LDAP operations
$ldap = &ldap_connect();
}

# set_imap_quota(&user, quota-in-kb)
# Change the quota for an IMAP user
sub set_imap_quota
{
local ($user, $quota) = @_;

# Check if the user already exists
local $imap = &imap_connect();
local $rv = $imap->status("user".$config{'imap_foldersep'}.$user->{'user'}, "messages");
if ($rv->{'Status'} eq 'ok') {
	# Set his IMAP quota
	$rv = $imap->setquota("user".$config{'imap_foldersep'}.$user->{'user'},
			      "STORAGE", $quota);
	$rv->{'Status'} eq 'ok' ||
		&imap_error($text{'usave_eiquota'}, $rv);
	}
}

# setup_addressbook(&user)
sub setup_addressbook
{
local $ldap = &ldap_connect();
local $rv = $ldap->add("ou=$_[0]->{'user'}, $config{'addressbook'}", attr =>
		 [ "ou" => $_[0]->{'user'},
		   "objectClass" => [ "top", "organizationalUnit" ]
		 ] );
if ($rv->code) {
	&error(&text('usave_ebook', $rv->error));
	}
$ldap->unbind();
}

# other_modules(function, arg, ...)
# Call some function in the useradmin_update.pl file in other modules
sub other_modules
{
return &useradmin::other_modules(@_);
}

# lock_user_files()
# Does nothing, because no locking is needed for LDAP
sub lock_user_files
{
}

# unlock_user_files()
# Does nothing, because no locking is needed for LDAP
sub unlock_user_files
{
}

# in_schema(schema, attrname)
sub in_schema
{
return $_[0] && $_[0]->attribute($_[1]);
}

# extra_fields_input(fields-list, &user|&group, &tds)
sub extra_fields_input
{
my ($fields, $uinfo, $tds) = @_;
my @fields = map { [ split(/\s+/, $_, 2) ] } split(/\t/, $fields);
if (@fields) {
	print &ui_table_start($text{'uedit_fields'}, "width=100%", 4, $tds);
	my $i = 0;
	foreach my $f (@fields) {
		my ($multi) = ($f->[0] =~ s/\+$//);
		my @v;
		if ($in{'new'}) {
			$v[0] = $in{lc($f->[0])};
			}
		else {
			@v = $uinfo->get_value($f->[0]);
			}
		my $input;
		if ($config{'multi_fields'} || @v > 1 || $multi) {
			$input = &ui_textarea("field_$i",
					      join("\n", @v), 3, 25);
			}
		else {
			$input = &ui_textbox("field_$i", $v[0], 25);
			}

		print &ui_table_row($f->[1], $input);
		$i++;
		}
	print &ui_table_end();
	}
}

# parse_extra_fields(fields-list, &props, &rprops, &ldap, [dn])
sub parse_extra_fields
{
local ($fields, $props, $rprops, $ldap, $dn) = @_;
local @fields = map { [ split(/\s+/, $_, 2) ] } split(/\t/, $fields);
local %noclash = map { lc($_), 1 } split(/\s+/, $config{'noclash'});
local %already = map { lc($_), 1 } (@$props, @$rprops);
local $i = 0;
local $f;
foreach $f (@fields) {
	$f->[0] =~ s/\+$//;
	if ($already{lc($f->[0])}) {
		# Skip fields set by Webmin
		$i++;
		next;
		}
	if ($in{"field_$i"} eq "") {
		push(@$rprops, $f->[0]);
		}
	else {
		$in{"field_$i"} =~ s/\r//g;
		local @v = split(/\n/, $in{"field_$i"});
		if ($noclash{lc($f->[0])}) {
			($dup, $dupwhat) = &check_duplicates($ldap, $f->[0],
						\@v, $dn);
			if ($dup && $dup->get_value('uid')) {
				&error(&text('usave_eattrdupu',
					$dup->get_value('uid'),
					$f->[1], $dupwhat));
				}
			elsif ($dup && $dup->get_value('cn')) {
				&error(&text('usave_eattrdupg',
					$dup->get_value('cn'),
					$f->[1], $dupwhat));
				}
			elsif ($dup) {
				&error(&text('usave_eattrdup',
					$dup->dn(), $f->[1], $dupwhat));
				}
			}
		push(@$props, $f->[0], @v == 1 ? $v[0] : \@v);
		}
	$i++;
	}
}

# can_edit_user(&user)
sub can_edit_user
{
return &useradmin::can_edit_user(\%access, $_[0]);
}

# can_edit_group(&group)
sub can_edit_group
{
return &useradmin::can_edit_group(\%access, $_[0]);
}

# samba_properties(new, &user, passmode, password, schema, &props, &ldap)
# Fills the &props array with properties needed for a Samba user
sub samba_properties
{
local ($new, $user, $passmode, $pass, $schema, $props, $ldap) = @_;
# Work out the Samba password
local $xes = ("X" x 32);
local ($nt, $lm, $opts);
if ($passmode == 0) {
	# No password needed
	$nt = "NO PASSWORDXXXXXXXXXXXXXXXXXXXXX";
	$lm = $nt;
	$opts = "UN";
	}
elsif ($passmode == 1 || $passmode == 2) {
	# No login allowed, or pre-encrypted password
	# that we cannot support
	$nt = $xes;
	$lm = $xes;
	$opts = "UD";
	}
elsif ($passmode == 3) {
	# Plain-text password to convert
	($nt, $lm) = &samba_password($pass);
	$opts = "U";
	push(@$props, "sambaPwdLastSet", time())
		if (&in_schema($schema, "sambaPwdLastSet"));
	push(@$props, "sambaPwdCanChange", time())
		if (&in_schema($schema, "sambaPwdCanChange"));
	}
elsif ($passmode == 4) {
	# No change
	}
if (defined($nt)) {
	if ($samba_schema == 3) {
		push(@$props, "sambaNTPassword", $nt)
			if (&in_schema($schema, "sambaNTPassword"));
		push(@$props, "sambaLMPassword", $lm)
			if (&in_schema($schema, "sambaLMPassword"));
		}
	else {
		push(@$props, "ntPassword", $nt)
			if (&in_schema($schema, "ntPassword"));
		push(@$props, "lmPassword", $lm)
			if (&in_schema($schema, "lmPassword"));
		}
	}

if ($new) {
	# Set other samba-related options
	push(@$props, "ntuid", $user->{'user'})
		if (&in_schema($schema, "ntuid") && $samba_schema == 2);

	push(@$props, "rid", $user->{'uid'}*2+1000)
		if (&in_schema($schema, "rid") && $samba_schema == 2);
	push(@$props, "sambaSID",
		     $config{'samba_domain'}.'-'.($user->{'uid'}*2+1000))
		if (&in_schema($schema, "sambaSID") &&
		    $samba_schema == 3);

	if (&in_schema($schema, "sambaPrimaryGroupSID") &&
	    $samba_schema == 3 && $config{'samba_gid'} ne 'none') {
		# Set primary group SID
		if ($config{'samba_gid'}) {
			# Fixed value
			push(@$props, "sambaPrimaryGroupSID",
				      $config{'samba_gid'});
			}
		else {
			# Find existing group with the same GID
			local $base = &get_group_base();
			local $rv = $ldap->search(base => $base,
			    filter => "(&".&group_filter().
				      "(gidNumber=$user->{'gid'}))");
			local ($ginfo) = $rv->all_entries;
			if ($ginfo && $ginfo->get_value("sambaSID")) {
				# We can get the SID from the actual group
				push(@$props, "sambaPrimaryGroupSID",
					      $ginfo->get_value("sambaSID"));
				}
			else {
				# Based on the GID
				push(@$props, "sambaPrimaryGroupSID",
					      $user->{'gid'}*2+1001);
				}
			}
		}
	}

if (defined($opts)) {
	push(@$props, "acctFlags", sprintf("[%-11s]", $opts))
		if (&in_schema($schema, "acctFlags") && $samba_schema == 2);

	push(@$props, "sambaAcctFlags", sprintf("[%-11s]",$opts))
		if (&in_schema($schema, "sambaAcctFlags") &&
		    $samba_schema == 3);
	}

push(@$props, &split_props($config{'samba_props'}, $user));
}

# samba_removes(&user, schema, &props)
# Adds to a list of properties to remove for a Samba user
sub samba_removes
{
local ($user, $schema, $rprops) = @_;
if ($samba_schema == 2) {
	push(@$rprops, "ntPassword", "lmPassword",
		       "ntuid", "rid", "acctFlags")
	}
if ($samba_schema == 3) {
	push(@$rprops, "sambaNTPassword", "sambaLMPassword",
		       "sambaSID", "sambaAcctFlags", "sambaPrimaryGroupSID",
		       "sambaPwdLastSet", "sambaPwdCanChange");
	}

push(@$rprops, &split_first($config{'samba_props'}));
}

# split_first(string)
# Returns only the property names from a multi-line name: value property list
sub split_first
{
local @rv;
foreach $p (split(/\t+/, $_[0])) {
	if ($p =~ /^(\S+):\s*(.*)/) {
		push(@rv, $1);
		}
	}
return @rv;
}

# check_duplicates(&ldap, name, &values, [dn])
# Returns a DN object and the clashing value if some other user has an
# attribute with the same name and value
sub check_duplicates
{
local ($ldap, $name, $values, $dn) = @_;
local $base = &get_user_base();
foreach my $v (@$values) {
	local $search = "($name=$v)";
	$rv = $ldap->search(base => $base, filter => $search);
	next if ($rv->code);
	foreach my $u ($rv->all_entries) {
		if ($u->dn() ne $dn) {
			return ($u, $v);
			}
		}
	}
return ();
}

# delete_ldap_subtree(&ldap, dn)
# Deletes an LDAP entry and all those below it. Returns undef on success, or
# an errpr message on failure.
sub delete_ldap_subtree
{
local ($ldap, $dn) = @_;
local $rv = $ldap->search(base => $dn, scope => 'one',
			  filter => '(objectClass=*)');
if ($rv->code) {
	print "subtree search error ",$rv->error,"<br>\n";
	}
foreach my $e ($rv->all_entries) {
	&delete_ldap_subtree($ldap, $e->dn());
	}
local $rv = $ldap->delete($dn);
return $rv->code ? $rv->error : undef;
}

# remove_accents(text)
# Given some text with european accented characters, convert them to ascii
sub remove_accents
{
local ($string) = @_;
eval "use Text::Unidecode; use utf8;";
if (!$@) {
	utf8::decode($string);
	$string = Text::Unidecode::unidecode($string);
	}
$string =~ s/[\177-\377]//g;	# Fallback - remove all non-ascii chars
return $string;
}

# in_props(&props, name)
# Looks up the value of a named property in a list
sub in_props
{
local ($props, $name) = @_;
for(my $i=0; $i<@$props; $i++) {
	if (lc($props->[$i]) eq lc($name)) {
		return $props->[$i+1];
		}
	}
return undef;
}

# user_filter()
# Returns an LDAP filter expression to find users
sub user_filter
{
my $rv = "(objectClass=posixAccount)";
if ($config{'user_filter'}) {
	$rv = "(&".$rv."(".$config{'user_filter'}."))";
	}
return $rv;
}

# group_filter()
# Returns an LDAP filter expression to find groups
sub group_filter
{
my $rv = "(objectClass=posixGroup)";
if ($config{'group_filter'}) {
	$rv = "(&".$rv."(".$config{'group_filter'}."))";
	}
return $rv;
}

1;

