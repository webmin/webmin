# htaccess-lib.pl
# Common functions for the htaccess and htpasswd file management module

use strict;
use warnings;
our (%config, %module_info, @remote_user_info, $user_module_config_directory,
     $remote_user, $module_config_directory);
BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
do 'htpasswd-file-lib.pl';

our ($default_dir, @accessdirs, $directories_file, $apachemod,
     $can_htpasswd, $can_htgroups, $can_create, $can_sync, %access);
our ($old_uid, $old_gid);
if ($module_info{'usermin'}) {
	# Allowed directories are in module configuration
	&switch_to_remote_user();
	&create_user_config_dirs();
	$default_dir = &resolve_links($remote_user_info[7]);
	push(@accessdirs, $default_dir) if ($config{'home'});
	foreach my $d (split(/\t+/, $config{'dirs'})) {
		push(@accessdirs, $d =~ /^\// ? $d : "$default_dir/$d");
		}
	@accessdirs = &expand_root_variables(@accessdirs);
	$directories_file = "$user_module_config_directory/directories";
	$apachemod = "htaccess";
	$can_htpasswd = $config{'can_htpasswd'};
	$can_htgroups = $config{'can_htgroups'};
	$can_create = !$config{'nocreate'};
	}
else {
	# Allowed directories come from ACL
	%access = &get_module_acl();
	my @uinfo;
	if (&supports_users() && $access{'home'} && $remote_user) {
		# Include user home
		@uinfo = getpwnam($remote_user);
		if (scalar(@uinfo)) {
			push(@accessdirs, &resolve_links($uinfo[7]));
			}
		}
	foreach my $d (split(/\t+/, $access{'dirs'})) {
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
my @rv;
my $fh;
open($fh, $directories_file) || return ();
while(<$fh>) {
	s/\r|\n//g;
	my @dir = split(/\t+/, $_);
	next if (!@dir);
	if ($_[0] || -d $dir[0] && -r "$dir[0]/$config{'htaccess'}") {
		push(@rv, \@dir);
		}
	}
close($fh);
return @rv;
}

# save_directories(&dirs)
# Save the list of known directories, which must be in the same format as
# returned by list_directories
sub save_directories
{
my $d;
my $fh = "DIRS";
&open_tempfile($fh, ">$directories_file");
foreach $d (@{$_[0]}) {
	my @safed = map { defined($_) ? $_ : "" } @$d;
	&print_tempfile($fh, join("\t", @safed),"\n");
	}
&close_tempfile($fh);
}

# can_access_dir(dir)
# Returns 1 if files can be created under some directory, 0 if not
sub can_access_dir
{
return 1 if (!$ENV{'GATEWAY_INTERFACE'});
my $d;
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
	my @uinfo = getpwnam($access{'user'} eq "*" ? $remote_user
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

# expand_root_variables(dir, ...)
# Replaces $USER and $HOME in a list of dirs
sub expand_root_variables
{
my @rv;
my %hash = ( 'user' => $remote_user_info[0],
		'home' => $remote_user_info[7],
		'uid' => $remote_user_info[2],
		'gid' => $remote_user_info[3] );
my @ginfo = getgrgid($remote_user_info[3]);
$hash{'group'} = $ginfo[0];
foreach my $dir (@_) {
	push(@rv, &substitute_template($dir, \%hash));
	}
return @rv;
}

1;

