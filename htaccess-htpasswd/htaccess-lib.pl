# htaccess-lib.pl
# Common functions for the htaccess and htpasswd file management module

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
do 'htpasswd-file-lib.pl';

@accessdirs = ( );
if ($module_info{'usermin'}) {
	# Allowed directories are in module configuration
	&switch_to_remote_user();
	&create_user_config_dirs();
	$default_dir = &resolve_links($remote_user_info[7]);
	push(@accessdirs, $default_dir) if ($config{'home'});
	local $d;
	foreach $d (split(/\t+/, $config{'dirs'})) {
		push(@accessdirs, $d =~ /^\// ? $d : "$default_dir/$d");
		}
	$directories_file = "$user_module_config_directory/directories";
	$apachemod = "htaccess";
	$can_htpasswd = $config{'can_htpasswd'};
	$can_htgroups = $config{'can_htgroups'};
	$can_create = !$config{'nocreate'};
	}
else {
	# Allowed directories come from ACL
	%access = &get_module_acl();
	local @uinfo;
	if (&supports_users()) {
		# Include user home
		@uinfo = getpwnam($remote_user);
		if ($access{'home'} && defined(@uinfo)) {
			push(@accessdirs, &resolve_links($uinfo[7]));
			}
		}
	local $d;
	foreach $d (split(/\t+/, $access{'dirs'})) {
		push(@accessdirs, $d =~ /^\// || !@uinfo ?
			$d : &resolve_links("$uinfo[7]/$d"));
		}
	$directories_file = "$module_config_directory/directories";
	$directories_file .= ".".$remote_user if ($access{'userdirs'});
	$apachemod = "apache";
	$can_htpasswd = 1;
	$can_htgroups = 1;
	$default_dir = $accessdirs[0];
	$can_sync = $access{'sync'};
	$can_create = !$access{'uonly'};
	}

# list_directories([even-if-missing])
# Returns a list of protected directories known to this module, and the
# users file, encryption mode, sync mode and groups file for each
sub list_directories
{
local @rv;
open(DIRS, $directories_file);
while(<DIRS>) {
	s/\r|\n//g;
	local @dir = split(/\t+/, $_);
	next if (!@dir);
	if ($_[0] || -d $dir[0] && -r "$dir[0]/$config{'htaccess'}") {
		push(@rv, \@dir);
		}
	}
closedir(DIRS);
return @rv;
}

# save_directories(&dirs)
# Save the list of known directories, which must be in the same format as
# returned by list_directories
sub save_directories
{
local $d;
&open_tempfile(DIRS, ">$directories_file");
foreach $d (@{$_[0]}) {
	&print_tempfile(DIRS, join("\t", @$d),"\n");
	}
&close_tempfile(DIRS);
}

# can_access_dir(dir)
# Returns 1 if files can be created under some directory, 0 if not
sub can_access_dir
{
return 1 if (!$ENV{'GATEWAY_INTERFACE'});
local $d;
foreach $d (@accessdirs) {
	return 1 if (&is_under_directory(&resolve_links($d),
					 &resolve_links($_[0])));
	}
return 0;
}

# switch_user()
# Switch to the Unix user that files are accessed as.
# No need to do anything for Usermin, because the switch was done above.
sub switch_user
{
if (!$module_info{'usermin'} &&
    $access{'user'} ne 'root' && !defined($old_uid) && &supports_users()) {
	local @uinfo = getpwnam($access{'user'} eq "*" ? $remote_user
						       : $access{'user'});
	$old_uid = $>;
	$old_gid = $);
	$) = "$uinfo[3] $uinfo[3]";
	$> = $uinfo[2];
	}
}

sub switch_back
{
if (defined($old_uid)) {
	$> = $old_uid;
	$) = $old_gid;
	$old_uid = $old_gid = undef;
	}
}

1;

