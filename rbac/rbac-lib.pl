#, $in{'mode'} == 1 Functions for parsing the various RBAC configuration files

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();

####################### functions for users #######################

# list_user_attrs()
# Returns a list of user attribute objects
sub list_user_attrs
{
if (!scalar(@list_user_attrs_cache)) {
	@list_user_attrs_cache = ( );
	local $lnum = 0;
	open(ATTR, $config{'user_attr'});
	while(<ATTR>) {
		s/\r|\n//g;
		s/#.*$//;
		local @w = split(/:/, $_, -1);
		if (@w == 5) {
			local $attr = { 'user' => $w[0],
					'qualifier' => $w[1],
					'res1' => $w[2],
					'res2' => $w[3],
					'type' => 'user',
					'line' => $lnum,
					'index' => scalar(@list_user_attrs_cache) };
			local $a;
			foreach $a (split(/;/, $w[4])) {
				local ($an, $av) = split(/=/, $a, 2);
				$attr->{'attr'}->{$an} = $av;
				}
			push(@list_user_attrs_cache, $attr);
			}
		$lnum++;
		}
	close(ATTR);
	}
return \@list_user_attrs_cache;
}

# create_user_attr(&attr)
# Add a new user attribute
sub create_user_attr
{
local ($attr) = @_;
&list_user_attrs();	# init cache
local $lref = &read_file_lines($config{'user_attr'});
$attr->{'line'} = scalar(@$lref);
push(@$lref, &user_attr_line($attr));
$attr->{'index'} = scalar(@list_user_attrs_cache);
push(@list_user_attrs_cache, $attr);
&flush_file_lines();
}

# modify_user_attr(&attr)
# Updates an existing user attribute in the config file
sub modify_user_attr
{
local ($attr) = @_;
local $lref = &read_file_lines($config{'user_attr'});
$lref->[$attr->{'line'}] = &user_attr_line($attr);
&flush_file_lines();
}

# delete_user_attr(&attr)
# Removes one user attribute entry
sub delete_user_attr
{
local ($attr) = @_;
local $lref = &read_file_lines($config{'user_attr'});
splice(@$lref, $attr->{'line'}, 1);
splice(@list_user_attrs_cache, $attr->{'index'}, 1);
local $c;
foreach $c (@list_user_attrs_cache) {
	$c->{'line'}-- if ($c->{'line'} > $attr->{'line'});
	$c->{'index'}-- if ($c->{'index'} > $attr->{'index'});
	}
&flush_file_lines();
}

# user_attr_line(&attr)
# Returns the text for a user attribute line
sub user_attr_line
{
local ($attr) = @_;
local $rv = $attr->{'user'}.":".$attr->{'qualifier'}.":".$attr->{'res1'}.":".
	    $attr->{'res2'}.":";
$rv .= join(";", map { $_."=".$attr->{'attr'}->{$_} }
		     keys %{$attr->{'attr'}});
return $rv;
}

# attr_input(name, value, [type], [acl-restrict])
# Returns HTML for selecting one or more user attrs
sub attr_input
{
local ($name, $value, $type, $restrict) = @_;
local @values = split(/,+/, $value);
local $users = &list_user_attrs();
local ($u, @sel);
foreach $u (@$users) {
	local $utype = $u->{'attr'}->{'type'} || "normal";
	if ((!$type || $utype eq $type) &&
	    (!$restrict || &can_assign_role($u))) {
		push(@sel, [ $u->{'user'} ]);
		}
	}
if (@sel) {
	return &ui_select($name, \@values, \@sel, 5, 1, 1);
	}
else {
	return $text{'attr_none'.$type};
	}
}

# attr_parse(name)
# Returns a comma-separated list of values from an attrs field
sub attr_parse
{
return join(",", split(/\0/, $in{$_[0]}));
}

# all_recursive_roles(username)
# Returns all roles and sub-roles for some user
sub all_recursive_roles
{
local $users = &list_user_attrs();
local ($user) = grep { $_->{'user'} eq $_[0] } @$users;
local (@rv, $r);
foreach $r (split(/,/, $user->{'attr'}->{'roles'})) {
	push(@rv, $r, &all_recursive_roles($r));
	}
return @rv;
}

####################### functions for profiles #######################

# list_prof_attrs()
# Returns a list of all profiles
sub list_prof_attrs
{
if (!scalar(@list_prof_attrs_cache)) {
	@list_prof_attrs_cache = ( );
	local $lnum = 0;
	open(ATTR, $config{'prof_attr'});
	while(<ATTR>) {
		s/\r|\n//g;
		s/#.*$//;
		local @w = split(/:/, $_, -1);
		if (@w == 5) {
			local $attr = { 'name' => $w[0],
					'res1' => $w[1],
					'res2' => $w[2],
					'desc' => $w[3],
					'line' => $lnum,
					'type' => 'prof',
					'index' => scalar(@list_prof_attrs_cache) };
			local $a;
			foreach $a (split(/;/, $w[4])) {
				local ($an, $av) = split(/=/, $a, 2);
				$attr->{'attr'}->{$an} = $av;
				}
			push(@list_prof_attrs_cache, $attr);
			}
		$lnum++;
		}
	close(ATTR);
	$lnum++;
	}
return \@list_prof_attrs_cache;
}

# create_prof_attr(&attr)
# Add a new profile
sub create_prof_attr
{
local ($attr) = @_;
&list_prof_attrs();	# init cache
local $lref = &read_file_lines($config{'prof_attr'});
$attr->{'line'} = scalar(@$lref);
push(@$lref, &prof_attr_line($attr));
$attr->{'index'} = scalar(@list_prof_attrs_cache);
push(@list_prof_attrs_cache, $attr);
&flush_file_lines();
}

# modify_prof_attr(&attr)
# Updates an existing profile in the config file
sub modify_prof_attr
{
local ($attr) = @_;
local $lref = &read_file_lines($config{'prof_attr'});
$lref->[$attr->{'line'}] = &prof_attr_line($attr);
&flush_file_lines();
}

# delete_prof_attr(&attr)
# Removes one profile
sub delete_prof_attr
{
local ($attr) = @_;
local $lref = &read_file_lines($config{'prof_attr'});
splice(@$lref, $attr->{'line'}, 1);
splice(@list_prof_attrs_cache, $attr->{'index'}, 1);
local $c;
foreach $c (@list_prof_attrs_cache) {
	$c->{'line'}-- if ($c->{'line'} > $attr->{'line'});
	$c->{'index'}-- if ($c->{'index'} > $attr->{'index'});
	}
&flush_file_lines();
}

# prof_attr_line(&attr)
# Returns the text for a prof attribute line
sub prof_attr_line
{
local ($attr) = @_;
local $rv = $attr->{'name'}.":".$attr->{'res1'}.":".$attr->{'res2'}.":".
	    $attr->{'desc'}.":";
$rv .= join(";", map { $_."=".$attr->{'attr'}->{$_} }
		     keys %{$attr->{'attr'}});
return $rv;
}

# profiles_input(name, comma-sep-value, acl-restrict)
# Returns HTML for a field for selecting multiple profiles
sub profiles_input
{
local ($name, $value, $restrict) = @_;
local @values = split(/,/, $value);
local $profs = &list_prof_attrs();
local @canprofs = $restrict ? grep { &can_assign_profile($_) } @$profs
			    : @$profs;
if (@canprofs) {
	return &ui_select($name, \@values,
			  [ map { [ $_->{'name'}, "$_->{'name'} ($_->{'desc'})" ] }
				sort { $a->{'name'} cmp $b->{'name'} }
				@canprofs ], 10, 1, 1);
	}
else {
	return $text{'prof_none'};
	}
}

# profiles_parse(name)
# Returns a comma-separated list of values from a profiles field
sub profiles_parse
{
return join(",", split(/\0/, $in{$_[0]}));
}

# all_recursive_profs(username|profilename)
# Returns all profiles and sub-profiles for some user
sub all_recursive_profs
{
local $users = &list_user_attrs();
local ($user) = grep { $_->{'user'} eq $_[0] } @$users;
local $profs = &list_prof_attrs();
local ($prof) = grep { $_->{'name'} eq $_[0] } @$profs;
local (@rv, $r);
if ($user) {
	# Return all profiles from roles, direct profiles and sub-profiles
	foreach $r (split(/,/, $user->{'attr'}->{'roles'})) {
		push(@rv, &all_recursive_profs($r));
		}
	foreach $r (split(/,/, $user->{'attr'}->{'profiles'})) {
		push(@rv, $r, &all_recursive_profs($r));
		}
	}
elsif ($prof) {
	# Return all sub-profiles
	foreach $r (split(/,/, $prof->{'attr'}->{'profs'})) {
		push(@rv, &all_recursive_profs($r));
		}
	}
return @rv;
}

####################### functions for authorizations #######################

# list_auth_attrs()
# Returns a user of all authorizations
sub list_auth_attrs
{
if (!scalar(@list_auth_attrs_cache)) {
	@list_auth_attrs_cache = ( );
	local $lnum = 0;
	open(ATTR, $config{'auth_attr'});
	while(<ATTR>) {
		s/\r|\n//g;
		s/#.*$//;
		local @w = split(/:/, $_, -1);
		if (@w == 6) {
			local $attr = { 'name' => $w[0],
					'res1' => $w[1],
					'res2' => $w[2],
					'short' => $w[3],
					'desc' => $w[4],
					'line' => $lnum,
					'type' => 'auth',
					'index' => scalar(@list_auth_attrs_cache) };
			local $a;
			foreach $a (split(/;/, $w[5])) {
				local ($an, $av) = split(/=/, $a, 2);
				$attr->{'attr'}->{$an} = $av;
				}
			push(@list_auth_attrs_cache, $attr);
			}
		$lnum++;
		}
	close(ATTR);
	$lnum++;
	}
return \@list_auth_attrs_cache;
}

# create_auth_attr(&attr)
# Add a new authorization
sub create_auth_attr
{
local ($attr) = @_;
&list_auth_attrs();	# init cache
local $lref = &read_file_lines($config{'auth_attr'});
$attr->{'line'} = scalar(@$lref);
push(@$lref, &auth_attr_line($attr));
$attr->{'index'} = scalar(@list_auth_attrs_cache);
push(@list_auth_attrs_cache, $attr);
&flush_file_lines();
}

# modify_auth_attr(&attr)
# Updates an existing authorization in the config file
sub modify_auth_attr
{
local ($attr) = @_;
local $lref = &read_file_lines($config{'auth_attr'});
$lref->[$attr->{'line'}] = &auth_attr_line($attr);
&flush_file_lines();
}

# delete_auth_attr(&attr)
# Removes one authorization
sub delete_auth_attr
{
local ($attr) = @_;
local $lref = &read_file_lines($config{'auth_attr'});
splice(@$lref, $attr->{'line'}, 1);
splice(@list_auth_attrs_cache, $attr->{'index'}, 1);
local $c;
foreach $c (@list_auth_attrs_cache) {
	$c->{'line'}-- if ($c->{'line'} > $attr->{'line'});
	$c->{'index'}-- if ($c->{'index'} > $attr->{'index'});
	}
&flush_file_lines();
}

# auth_attr_line(&attr)
# Returns the text for a auth attribute line
sub auth_attr_line
{
local ($attr) = @_;
local $rv = $attr->{'name'}.":".$attr->{'res1'}.":".$attr->{'res2'}.":".
	    $attr->{'short'}.":".$attr->{'desc'}.":";
$rv .= join(";", map { $_."=".$attr->{'attr'}->{$_} }
		     keys %{$attr->{'attr'}});
return $rv;
}

# auths_input(name, value)
# Returns HTML for a text area for entering and choosing authorizations
sub auths_input
{
local ($name, $value) = @_;
return "<table cellpadding=0 cellspacing=0><tr><td>".
       &ui_textarea($name, join("\n", split(/,/, $value)), 3, 50).
       "</td><td valign=top>&nbsp;".
       &auth_chooser($name).
       "</td></tr></table>";
}

# auth_chooser(field)
# Returns HTML for a button that pops up an authorization chooser window
sub auth_chooser
{
return "<input type=button onClick='ifield = form.$_[0]; chooser = window.open(\"auth_chooser.cgi\", \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=500,height=400\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

# auths_parse(name)
# Returns a comma-separated list of auths
sub auths_parse
{
local @auths = split(/[\r\n]+/, $in{$_[0]});
local $a;
foreach $a (@auths) {
	$a =~ /^\S+$/ || &error(&text('user_eauth', $a));
	}
return join(",", @auths);
}

####################### functions for exec attributes #######################

# list_exec_attrs()
# Returns a user of all execorizations
sub list_exec_attrs
{
if (!scalar(@list_exec_attrs_cache)) {
	@list_exec_attrs_cache = ( );
	local $lnum = 0;
	open(ATTR, $config{'exec_attr'});
	while(<ATTR>) {
		s/\r|\n//g;
		s/#.*$//;
		local @w = split(/:/, $_, -1);
		if (@w == 7) {
			local $attr = { 'name' => $w[0],
					'policy' => $w[1],
					'cmd' => $w[2],
					'res1' => $w[3],
					'res2' => $w[4],
					'id' => $w[5],
					'type' => 'exec',
					'index' => scalar(@list_exec_attrs_cache) };
			local $a;
			foreach $a (split(/;/, $w[6])) {
				local ($an, $av) = split(/=/, $a, 2);
				$attr->{'attr'}->{$an} = $av;
				}
			push(@list_exec_attrs_cache, $attr);
			}
		$lnum++;
		}
	close(ATTR);
	$lnum++;
	}
return \@list_exec_attrs_cache;
}

# create_exec_attr(&attr)
# Add a new execorization
sub create_exec_attr
{
local ($attr) = @_;
&list_exec_attrs();	# init cache
local $lref = &read_file_lines($config{'exec_attr'});
$attr->{'line'} = scalar(@$lref);
push(@$lref, &exec_attr_line($attr));
$attr->{'index'} = scalar(@list_exec_attrs_cache);
push(@list_exec_attrs_cache, $attr);
&flush_file_lines();
}

# modify_exec_attr(&attr)
# Updates an existing execorization in the config file
sub modify_exec_attr
{
local ($attr) = @_;
local $lref = &read_file_lines($config{'exec_attr'});
$lref->[$attr->{'line'}] = &exec_attr_line($attr);
&flush_file_lines();
}

# delete_exec_attr(&attr)
# Removes one execorization
sub delete_exec_attr
{
local ($attr) = @_;
local $lref = &read_file_lines($config{'exec_attr'});
splice(@$lref, $attr->{'line'}, 1);
splice(@list_exec_attrs_cache, $attr->{'index'}, 1);
local $c;
foreach $c (@list_exec_attrs_cache) {
	$c->{'line'}-- if ($c->{'line'} > $attr->{'line'});
	$c->{'index'}-- if ($c->{'index'} > $attr->{'index'});
	}
&flush_file_lines();
}

# exec_attr_line(&attr)
# Returns the text for a exec attribute line
sub exec_attr_line
{
local ($attr) = @_;
local $rv = $attr->{'name'}.":".$attr->{'policy'}.":".$attr->{'cmd'}.":".
	    $attr->{'res1'}.":".$attr->{'res2'}.":".$attr->{'id'}.":";
$rv .= join(";", map { $_."=".$attr->{'attr'}->{$_} }
		     keys %{$attr->{'attr'}});
return $rv;
}

####################### policy.conf functions #######################

# get_policy_config()
# Returns a list of policy config file directives
sub get_policy_config
{
if (!scalar(@policy_conf_cache)) {
	@policy_conf_cache = ( );
	local $lnum = 0;
	open(ATTR, $config{'policy_conf'});
	while(<ATTR>) {
		s/\r|\n//g;
		s/\s+$//;
		if (/^\s*(#*)\s*([^= ]+)\s*=\s*(\S.*)$/) {
			local $pol = { 'name' => $2,
				       'value' => $3,
				       'enabled' => !$1,
				       'line' => $lnum,
				       'index' => scalar(@policy_conf_cache) };
			push(@policy_conf_cache, $pol);
			}
		$lnum++;
		}
	close(ATTR);
	$lnum++;
	}
return \@policy_conf_cache;
}

# find_policy(name, &conf, [enabled])
sub find_policy
{
local ($name, $conf, $ena) = @_;
local ($rv) = grep { lc($_->{'name'}) eq lc($name) &&
		     (!defined($ena) ||
		      defined($ena) && $ena == $_->{'enabled'}) } @$conf;
return $rv;
}

# find_policy_value(name, &conf);
sub find_policy_value
{
local ($name, $conf) = @_;
local $rv = &find_policy($name, $conf, 1);
return $rv ? $rv->{'value'} : undef;
}

# save_policy(&conf, name, [value])
# Update or delete an entry in policy.conf
sub save_policy
{
local ($conf, $name, $value) = @_;
local $old = &find_policy($name, $conf);
local $lref = &read_file_lines($config{'policy_conf'});
if (!$old && $value) {
	# Need to add
	push(@$lref, "$name=$value");
	push(@$conf, { 'name' => $name,
		       'value' => $value,
		       'index' => scalar(@$conf),
		       'line' => scalar(@$lref) - 1 });
	}
elsif ($old && $value) {
	# Need to update (and perhaps comment in)
	$old->{'value'} = $value;
	$old->{'enabled'} = 1;
	$lref->[$old->{'line'}] = "$name=$value";
	}
elsif ($old && $old->{'enabled'} && !$value) {
	# Need to comment out
	$old->{'enabled'} = 0;
	$lref->[$old->{'line'}] = "#$name=$old->{'value'}";
	}
}

####################### functions for projects #######################

# list_projects()
# Returns a list of project objects
sub list_projects
{
if (!scalar(@list_projects_cache)) {
	@list_projects_cache = ( );
	local $lnum = 0;
	open(ATTR, $config{'project'});
	while(<ATTR>) {
		s/\r|\n//g;
		s/#.*$//;
		local @w = split(/:/, $_, -1);
		if (@w >= 2) {
			local $attr = { 'name' => $w[0],
					'id' => $w[1],
					'desc' => $w[2],
					'users' => $w[3],
					'groups' => $w[4],
					'line' => $lnum,
					'type' => 'project',
					'index' => scalar(@list_projects_cache) };
			local $a;
			foreach $a (split(/;/, $w[5])) {
				local ($an, $av) = split(/=/, $a, 2);
				$attr->{'attr'}->{$an} = $av;
				}
			push(@list_projects_cache, $attr);
			}
		$lnum++;
		}
	close(ATTR);
	}
return \@list_projects_cache;
}

# create_project(&attr)
# Add a new project
sub create_project
{
local ($attr) = @_;
&list_projects();	# init cache
local $lref = &read_file_lines($config{'project'});
$attr->{'line'} = scalar(@$lref);
push(@$lref, &project_line($attr));
$attr->{'index'} = scalar(@list_projects_cache);
push(@list_projects_cache, $attr);
&flush_file_lines();
}

# modify_project(&attr)
# Updates an existing project in the config file
sub modify_project
{
local ($attr) = @_;
local $lref = &read_file_lines($config{'project'});
$lref->[$attr->{'line'}] = &project_line($attr);
&flush_file_lines();
}

# delete_project(&attr)
# Removes one project entry
sub delete_project
{
local ($attr) = @_;
local $lref = &read_file_lines($config{'project'});
splice(@$lref, $attr->{'line'}, 1);
splice(@list_projects_cache, $attr->{'index'}, 1);
local $c;
foreach $c (@list_projects_cache) {
	$c->{'line'}-- if ($c->{'line'} > $attr->{'line'});
	$c->{'index'}-- if ($c->{'index'} > $attr->{'index'});
	}
&flush_file_lines();
}

# project_line(&attr)
# Returns the text for a project file line
sub project_line
{
local ($attr) = @_;
local $rv = $attr->{'name'}.":".$attr->{'id'}.":".$attr->{'desc'}.":".
	    $attr->{'users'}.":".$attr->{'groups'}.":";
$rv .= join(";", map { defined($attr->{'attr'}->{$_}) ?
			$_."=".$attr->{'attr'}->{$_} : $_ }
		     keys %{$attr->{'attr'}});
return $rv;
}

# project_input(name, value)
# Returns HTML for selecting one project
sub project_input
{
local ($name, $value) = @_;
local $projects = &list_projects();
return &ui_select($name, $value,
		  [ map { [ $_->{'name'},
			    $_->{'name'}.($_->{'desc'} ? " ($_->{'desc'})"
						       : "") ] } @$projects ],
		  0, 0, $value ? 1 : 0);
}

# project_members_input(name, comma-separated-members)
# Returns HTML for selecting users or groups in a project. These may be all,
# none, all except or only some
sub project_members_input
{
local ($name, $users) = @_;
local @users = split(/,/, $users);
local %users = map { $_, 1 } @users;
local (@canusers, @cannotuser, $mode);
if ($users{'*'} && @users == 1) {
	$mode = 0;
	}
elsif (@users == 0 || $users{'!*'} && @users == 1) {
	$mode = 1;
	}
elsif ($users{'*'}) {
	# All except some
	$mode = 3;
	@cannotusers = map { /^\!(.*)/; $1 } grep { /^\!/ } @users[1..$#users];
	}
elsif ($users{'!*'}) {
	# Only some
	$mode = 2;
	@canusers = grep { !/^\!/ } @users[1..$#users];
	}
else {
	# Only listed
	$mode = 2;
	@canusers = @users;
	}
local $cb = $name =~ /user/ ? \&user_chooser_button : \&group_chooser_button;
return &ui_radio($name."_mode", $mode,
	[ [ 0, $text{'projects_all'.$name} ],
	  [ 1, $text{'projects_none'.$name}."<br>" ],
	  [ 2, &text('projects_only'.$name,
	     &ui_textbox($name."_can", join(" ", @canusers), 40)." ".
	     &$cb($name."_can", 1))."<br>" ],
	  [ 3, &text('projects_except'.$name,
	     &ui_textbox($name."_cannot", join(" ", @cannotusers), 40)." ".
	     &$cb($name."_cannot", 1)) ]
	]);
}

# parse_project_members(name)
sub parse_project_members
{
local ($name) = @_;
if ($in{$name."_mode"} == 0) {
	return "*";
	}
elsif ($in{$name."_mode"} == 1) {
	return "";
	}
elsif ($in{$name."_mode"} == 2) {
	$in{$name."_can"} || &error($text{'project_e'.$name.'can'});
	return join(",", split(/\s+/, $in{$name."_can"}));
	}
elsif ($in{$name."_mode"} == 3) {
	$in{$name."_cannot"} || &error($text{'project_e'.$name.'cannot'});
	return join(",", "*", map { "!$_" } split(/\s+/, $in{$name."_cannot"}));
	}
}

####################### miscellaneous functions #######################

# nice_comma_list(comma-separated-value)
# Nicely formats and shortens a comma-separated string
sub nice_comma_list
{
local @l = split(/,/, $_[0]);
if (@l > 2) {
	return join(" , ", @l[0..1], "...");
	}
else {
	return join(" , ", @l);
	}
}

# rbac_help_file(&object)
sub rbac_help_file
{
local $hf = $config{$_[0]->{'type'}.'_help_dir'}."/$_[0]->{'attr'}->{'help'}";
return -r $hf && !-d $hf ? $hf : undef;
}

# rbac_help_link(&object, desc)
sub rbac_help_link
{
local $hf = &rbac_help_file($_[0]);
local $rv = "<table cellpadding=0 cellspacing=0 width=100%><tr><td>$_[1]</td>";
if ($hf) {
	$hf = &urlize($hf);
	$rv .= "<td align=right><a onClick='window.open(\"rbac_help.cgi?help=$hf\", \"help\", \"toolbar=no,menubar=no,scrollbars=yes,width=400,height=300,resizable=yes\"); return false' href=\"rbac_help.cgi?help=$hf\"><img src=images/help.gif border=0></a></td>";
	}
$rv .= "</tr></table>";
return $rv;
}

# rbac_config_files()
# Returns a list of all config files managed by this module
sub rbac_config_files
{
return map { $config{$_} } ('user_attr', 'prof_attr', 'auth_attr',
			    'exec_attr', 'policy_conf', 'project');
}

# missing_rbac_config_file()
# Returns the path to any missing config file
sub missing_rbac_config_file
{
foreach $c (&rbac_config_files()) {
	return $c if (!-r $c);
	}
return undef;
}

# lock_rbac_files()
# Lock all config files used by RBAC
sub lock_rbac_files
{
local $c;
foreach $c (&rbac_config_files()) {
	&lock_file($c);
	}
}

# unlock_rbac_files()
# Unlock all config files used by RBAC
sub unlock_rbac_files
{
local $c;
foreach $c (&rbac_config_files()) {
	&unlock_file($c);
	}
}

# list_crypt_algorithms()
# Returns 1 list of all encryption algorithms, including the internal __unix__
sub list_crypt_algorithms
{
if (!scalar(@list_crypt_algorithms_cache)) {
	push(@list_crypt_algorithms_cache, { 'name' => '__unix__' } );
	local $lnum = 0;
	open(CRYPT, $config{'crypt_conf'});
	while(<CRYPT>) {
		s/\r|\n//g;
		s/#.*$//;
		if (/^\s*(\S+)\s+(\S+)/) {
			push(@list_crypt_algorithms_cache,
			   { 'name' => $1,
			     'lib' => $2,
			     'line' => $lnum,
			     'index' => scalar(@list_crypt_algorithms_cache) });
			}
		$lnum++;
		}
	close(CRYPT);
	}
return \@list_crypt_algorithms_cache;
}

# crypt_algorithms_input(name, value, multiple)
# Returns HTML for selecting one or many crypt algorithms
sub crypt_algorithms_input
{
local ($name, $value, $multiple) = @_;
local @values = split(/,/, $value);
local $crypts = &list_crypt_algorithms();
return &ui_select($name, \@values,
		  [ map { [ $_->{'name'}, $text{'crypt_'.$_->{'name'}} ] }
			@$crypts ], $multiple ? scalar(@$crypts) : undef,
			$multiple, 1);
}

# can_edit_user(&user)
# Returns 1 if some user can be edited
sub can_edit_user
{
local ($user) = @_;
return 0 if ($user->{'attr'}->{'type'} eq 'role' && !$access{'roles'});
return 0 if ($user->{'attr'}->{'type'} ne 'role' && !$access{'users'});
return 1;
}

# can_assign_role(&role|rolename)
# Returns 1 if some role can be assigned
sub can_assign_role
{
local ($role) = @_;
local $rolename = ref($role) ? $role->{'user'} : $role;
if ($access{'roleassign'} eq '*') {
	return 1;
	}
else {
	local @canroles;
	if ($access{'roleassign'} eq 'x') {
		# Work out Webmin user's roles
		@canroles = &all_recursive_roles($remote_user);
		}
	else {
		@canroles = split(/,/, $access{'roleassign'});
		}
	return &indexof($rolename, @canroles) != -1;
	}
}

# can_assign_profile(&profile|profilename)
# Returns 1 if some profile can be assigned
sub can_assign_profile
{
local ($prof) = @_;
local $profname = ref($prof) ? $prof->{'name'} : $prof;
if ($access{'profassign'} eq '*') {
	return 1;
	}
else {
	local @canprofs;
	if ($access{'profassign'} eq 'x') {
		# Work out Webmin user's profs
		@canprofs = &all_recursive_profs($remote_user);
		}
	else {
		@canprofs = split(/,/, $access{'profassign'});
		}
	return &indexof($profname, @canprofs) != -1;
	}
}

# list_rctls()
# Returns a list of possible resource control names
sub list_rctls
{
local @rv;
open(RCTL, "rctladm -l |");
while(<RCTL>) {
	if (/^(\S+)\s+(\S+)=(\S+)/) {
		push(@rv, $1);
		}
	}
close(RCTL);
return @rv;
}

# list_rctl_signals()
# Returns a list of allowed signals for rctl actions
sub list_rctl_signals
{
return ( [ "SIGABRT", "Abort the process" ],
	 [ "SIGHUP", "Send a hangup signal" ],
	 [ "SIGTERM", "Terminate the process" ],
	 [ "SIGKILL", "Kill the process" ],
	 [ "SIGSTOP", "Stop the process" ],
	 [ "SIGXRES", "Resource control limit exceeded" ],
	 [ "SIGXFSZ", "File size limit exceeded" ],
	 [ "SIGXCPU", "CPU time limit exceeded" ] );
}

# list_resource_controls(type, id)
# Returns a list of resource controls for some project, zone or process
sub list_resource_controls
{
local ($type, $id) = @_;
&open_execute_command(PRCTL,
		      "prctl -i ".quotemeta($type)." ".quotemeta($id), 1);
local (@rv, $res);
while(<PRCTL>) {
	s/\r|\n//g;
	next if (/^NAME/);	# skip header
	if (/^(\S+)\s*$/) {
		# Start of a new resource
		$res = $1;
		}
	elsif (/^\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/ && $res) {
		# A limit within a resource
		push(@rv, { 'res' => $res,
			    'priv' => $1,
			    'limit' => $2,
			    'flag' => $3 eq "-" ? undef : $3,
			    'action' => $4 });
		}
	}
close(PRCTL);
return @rv;
}

1;

