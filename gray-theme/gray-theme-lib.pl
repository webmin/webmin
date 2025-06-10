# Functions used by theme CGIs

eval "use WebminCore;";
if ($@) {
	do '../web-lib.pl';
	do '../ui-lib.pl';
	}
&init_config();
&load_theme_library();
%text = &load_language($current_theme);
$right_frame_sections_file = "$config_directory/$current_theme/sections";
$default_domains_to_show = 10;

# get_left_frame_width()
# Returns the width of the left frame in pixels
sub get_left_frame_width
{
local $sects = &get_right_frame_sections();
return $sects->{'fsize'} ? $sects->{'fsize'} :
       &get_product_name() eq 'usermin' ? 200 :
       &foreign_available("server-manager") &&
       &foreign_available("virtual-server") ? 280 : 260;
}

# list_virtualmin_theme_overlays()
# Returns a list of overlay themes suitable for this theme
sub list_virtualmin_theme_overlays
{
&foreign_require("webmin", "webmin-lib.pl");
local @rv;
foreach my $tinfo (&webmin::list_themes()) {
	if ($tinfo->{'overlay'} &&
	    (!$tinfo->{'overlays'} ||
	     &indexof($current_theme,
		      split(/\s+/, $tinfo->{'overlays'})) >= 0)) {
		push(@rv, $tinfo);
		}
	}
return @rv;
}

sub get_virtualmin_docs
{
local ($level) = @_;
return $level == 0 ? "http://www.virtualmin.com/documentation" :
       $level == 1 ? "http://www.virtualmin.com/documentation/users/reseller" :
       $level == 2 ? "http://www.virtualmin.com/documentation/users/server-owner" :
		     "http://www.virtualmin.com/documentation";
}

sub get_vm2_docs
{
local ($level) = @_;
return "http://www.virtualmin.com/documentation/cloudmin";
}

# get_right_frame_sections()
# Returns a hash containg details of visible right-frame sections
sub get_right_frame_sections
{
local %sects;
&read_file($right_frame_sections_file, \%sects);
if ($sects{'global'}) {
	# Force use of global settings
	return \%sects;
	}
else {
	# Can try personal settings, but fall back to global
	local %usersects;
	if (&read_file($right_frame_sections_file.".".$remote_user,
		       \%usersects)) {
		return \%usersects;
		}
	else {
		return \%sects;
		}
	}
}

# save_right_frame_sections(&sects)
sub save_right_frame_sections
{
local ($sects) = @_;
&make_dir("$config_directory/$current_theme", 0700);
if ($sects->{'global'}) {
	# Update global settings, for all users
	&write_file($right_frame_sections_file, $sects);
	}
else {
	# Save own, and turn off global flag (if this is the master admin)
	if (&foreign_check("virtual-server")) {
		&foreign_require("virtual-server", "virtual-server-lib.pl");
		if (&virtual_server::master_admin()) {
			local %globalsect;
			&read_file($right_frame_sections_file, \%globalsect);
			$globalsect{'global'} = 0;
			&write_file($right_frame_sections_file, \%globalsect);
			}
		}
	&write_file($right_frame_sections_file.".".$remote_user, $sects);
	}
}

# list_right_frame_sections()
# Returns a list of possible sections for the current user, as hash refs
sub list_right_frame_sections
{
local ($hasvirt, $level, $hasvm2) = &get_virtualmin_user_level();
local @rv;
if ($level == 0) {
	# Master admin
	if ($hasvirt) {
		push(@rv, 'updates', 'status', 'newfeatures',
			  'quotas', 'bw', 'ips', 'sysinfo');
		}
	if ($hasvm2) {
		push(@rv, 'vm2servers');
		}
	}
elsif ($level == 2) {
	# Domain owner
	push(@rv, 'virtualmin');
	}
elsif ($level == 1) {
	# Reseller
	push(@rv, 'reseller', 'quotas', 'bw');
	}
elsif ($level == 4) {
	# Cloudmin system owner
	push(@rv, 'owner', 'vm2servers');
	}
else {
	# Usermin
	push(@rv, 'system');
	}
@rv = map { { 'name' => $_,
	      'title' => $virtual_server::text{'right_'.$_.'header'} } } @rv;

# Add plugin-defined sections
if (($level == 0 || $level == 1 || $level == 2) && $hasvirt &&
    defined(&virtual_server::list_plugin_sections)) {
	push(@rv, &virtual_server::list_plugin_sections($level));
	}
if (($level == 0 || $level == 4) && $hasvm2 &&
    defined(&server_manager::list_plugin_sections)) {
	push(@rv, &server_manager::list_plugin_sections($level));
	}

return @rv;
}

# get_virtualmin_user_level()
# Returns three numbers - the first being a flag if virtualmin is installed,
# the second a user type (3=usermin, 2=domain, 1=reseller, 0=master, 4=system
# owner), the third a flag for Cloudmin
sub get_virtualmin_user_level
{
local ($hasvirt, $hasvm2, $level);
$hasvm2 = &foreign_available("server-manager");
$hasvirt = &foreign_available("virtual-server");
if ($hasvm2) {
	&foreign_require("server-manager", "server-manager-lib.pl");
	}
if ($hasvirt) {
	&foreign_require("virtual-server", "virtual-server-lib.pl");
	}
if ($hasvm2) {
	$level = $server_manager::access{'owner'} ? 4 : 0;
	}
elsif ($hasvirt) {
	$level = &virtual_server::master_admin() ? 0 :
		 &virtual_server::reseller_admin() ? 1 : 2;
	}
elsif (&get_product_name() eq "usermin") {
	$level = 3;
	}
else {
	$level = 0;
	}
return ($hasvirt, $level, $hasvm2);
}

1;

