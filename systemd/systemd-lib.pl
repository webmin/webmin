=head1 systemd-lib.pl

Common functions for listing, creating and managing systemd system and user units.

=cut

use strict;
use warnings;
use lib "..";
use Cwd qw(abs_path);
use Symbol qw(gensym);

use WebminCore;

our (%access, %config, %gconfig, %in, %text, @list_units_cache, $remote_user,
     $module_var_directory);
our ($unit_config_change_flag, $daemon_reload_time_flag);

init_config();
%access = get_module_acl();
$config{"desc"} = 1 if (!defined($config{"desc"}));
$config{"logs_lines"} = 200
	if (!defined($config{"logs_lines"}) ||
	    $config{"logs_lines"} !~ /^\d+$/ ||
	    $config{"logs_lines"} < 1);
$config{"logs_current_boot"} = 0
	if (!defined($config{"logs_current_boot"}));
$config{"show_runtime_units"} = 1
	if (!defined($config{"show_runtime_units"}));
$config{"default_create_scope"} = "system"
	if (!defined($config{"default_create_scope"}) ||
	    $config{"default_create_scope"} !~ /^(system|user)$/);
$config{"manual_vendor_units"} = 1
	if (!defined($config{"manual_vendor_units"}));
$config{"default_linger"} = 1
	if (!defined($config{"default_linger"}));
$config{"show_unit_suffixes"} = 0
	if (!defined($config{"show_unit_suffixes"}));
$config{"show_dropin_inventory"} = 1
	if (!defined($config{"show_dropin_inventory"}));
$config{"create_return_index"} = 0
	if (!defined($config{"create_return_index"}) ||
	    $config{"create_return_index"} !~ /^[01]$/);
$config{"visible_tabs"} ||= default_visible_tabs();
$unit_config_change_flag = $module_var_directory."/unit-change-flag";
$daemon_reload_time_flag = $module_var_directory."/daemon-reload-flag";

=head2 systemd_acl_keys()

Returns all boolean ACL keys understood by this module.

=cut
sub systemd_acl_keys
{
return (qw(view view_user status status_user logs logs_user
	   start start_user stop stop_user restart restart_user
	   boot boot_user mask mask_user
	   create create_user edit edit_user delete delete_user
	   dropin dropin_user manual manual_user reload linger backup));
}

=head2 systemd_user_unit_acl(user)

Returns a safe ACL hash for managing one Unix user's systemd user units,
without granting any system-unit access.

=cut
sub systemd_user_unit_acl
{
my ($user) = @_;
my %acl = map { $_, 0 } systemd_acl_keys();
foreach my $key (qw(view_user status_user logs_user start_user stop_user
		    restart_user boot_user create_user edit_user
		    delete_user dropin_user manual_user linger)) {
	$acl{$key} = 1;
	}
$acl{'noconfig'} = 1;
$acl{'mode'} = 1;
$acl{'users'} = defined($user) ? $user : "";
$acl{'uidmin'} = "";
$acl{'uidmax'} = "";
return %acl;
}

=head2 systemd_acl_bool(&acl, key)

Returns a boolean ACL value.

=cut
sub systemd_acl_bool
{
my ($acl, $key) = @_;
$acl ||= \%access;
return $acl->{$key} ? 1 : 0 if (exists($acl->{$key}));
return 0;
}

=head2 systemd_acl_error(reason-key)

Throws a standardized ACL denial error.  The key should be the suffix after
C<eacl_>, such as C<pview> or C<pedit_user>.

=cut
sub systemd_acl_error
{
my ($reason) = @_;
my $prefix = $text{'eacl_np'} || "Access denied:";
my $msg = $text{'eacl_'.$reason} || $text{'eacl_penter'} ||
	  "Access to this systemd action is not permitted.";
error($prefix." ".$msg);
}

=head2 systemd_acl_any(&acl, keys...)

Returns 1 if any named ACL key is allowed.

=cut
sub systemd_acl_any
{
my ($acl, @keys) = @_;
foreach my $key (@keys) {
	return 1 if (systemd_acl_bool($acl, $key));
	}
return 0;
}

=head2 systemd_acl_user_allowed(&acl, user)

Returns 1 if the ACL's Unix-user filter permits access to a systemd user
manager owned by C<user>.  The filter intentionally mirrors Cron's mode/users
ACL model so Virtualmin templates can grant per-owner access predictably.

=cut
sub systemd_acl_user_allowed
{
my ($acl, $user) = @_;
$acl ||= \%access;
return 0 if (!$user);
my $mode = defined($acl->{'mode'}) ? $acl->{'mode'} : 0;
$mode = 0 if ($mode !~ /^[0-5]$/);
if ($mode == 1 || $mode == 2) {
	my %umap = map { $_, 1 } split(/\s+/, $acl->{'users'} || "");
	return 0 if ($mode == 1 && !$umap{$user});
	return 0 if ($mode == 2 && $umap{$user});
	return 1;
	}
elsif ($mode == 3) {
	return defined($remote_user) && $remote_user eq $user ? 1 : 0;
	}
elsif ($mode == 4) {
	my @uinfo = getpwnam($user);
	my $uidmin = defined($acl->{'uidmin'}) ? $acl->{'uidmin'} : "";
	my $uidmax = defined($acl->{'uidmax'}) ? $acl->{'uidmax'} : "";
	return 0 if (!@uinfo);
	return 0 if ($uidmin ne "" && $uinfo[2] < $uidmin);
	return 0 if ($uidmax ne "" && $uinfo[2] > $uidmax);
	return 1;
	}
elsif ($mode == 5) {
	my @uinfo = getpwnam($user);
	return @uinfo && defined($acl->{'users'}) &&
	       $uinfo[3] == $acl->{'users'} ? 1 : 0;
	}
return 1;
}

=head2 systemd_acl_default_user(&acl)

Returns a safe default Unix owner for user-unit views when the ACL narrows the
user set to exactly one account, or to the current Webmin user.

=cut
sub systemd_acl_default_user
{
my ($acl) = @_;
$acl ||= \%access;
my $mode = defined($acl->{'mode'}) ? $acl->{'mode'} : 0;
$mode = 0 if ($mode !~ /^[0-5]$/);
if ($mode == 1) {
	my @users = grep { $_ ne "" } split(/\s+/, $acl->{'users'} || "");
	return $users[0]
		if (@users == 1 && systemd_acl_user_allowed($acl, $users[0]));
	return;
	}
elsif ($mode == 3) {
	return $remote_user
		if (defined($remote_user) &&
		    systemd_acl_user_allowed($acl, $remote_user));
	return;
	}
return;
}

=head2 systemd_can_view_system(&acl)

Returns 1 if the ACL allows seeing or acting on system-scope units.

=cut
sub systemd_can_view_system
{
my ($acl) = @_;
return systemd_acl_any($acl, qw(view status logs start stop restart boot mask
				create edit delete dropin manual reload));
}

=head2 systemd_can_view_user_scope(&acl, [user])

Returns 1 if the ACL allows seeing or acting on user-scope units, optionally
constrained to a specific Unix owner.

=cut
sub systemd_can_view_user_scope
{
my ($acl, $user) = @_;
return 0 if (defined($user) && $user ne "" &&
	     !systemd_acl_user_allowed($acl, $user));
return systemd_acl_bool($acl, 'view_user') ||
       systemd_acl_any($acl, qw(status_user logs_user start_user stop_user
				restart_user boot_user mask_user create_user
				edit_user delete_user dropin_user manual_user
				linger));
}

=head2 systemd_can_enter_module(&acl)

Returns 1 if the ACL allows any interactive access to this module.

=cut
sub systemd_can_enter_module
{
my ($acl) = @_;
return systemd_can_view_system($acl) || systemd_can_view_user_scope($acl);
}

=head2 systemd_can_view_scope(&acl, user-scope, [user])

Returns 1 if the ACL allows seeing or acting on the selected unit scope.

=cut
sub systemd_can_view_scope
{
my ($acl, $user_scope, $user) = @_;
return $user_scope ? systemd_can_view_user_scope($acl, $user) :
		     systemd_can_view_system($acl);
}

=head2 systemd_can_inspect(&acl, user-scope, [user])

Returns 1 if status, properties or dependency inspection is allowed.

=cut
sub systemd_can_inspect
{
my ($acl, $user_scope, $user) = @_;
my $key = $user_scope ? 'status_user' : 'status';
return systemd_acl_bool($acl, $key) &&
       systemd_can_view_scope($acl, $user_scope, $user) ? 1 : 0;
}

=head2 systemd_can_logs(&acl, user-scope, [user])

Returns 1 if journal log inspection is allowed.

=cut
sub systemd_can_logs
{
my ($acl, $user_scope, $user) = @_;
my $key = $user_scope ? 'logs_user' : 'logs';
return systemd_acl_bool($acl, $key) &&
       systemd_can_view_scope($acl, $user_scope, $user) ? 1 : 0;
}

=head2 systemd_can_runtime(&acl, action, user-scope, [user])

Returns 1 if a runtime action such as C<start>, C<stop> or C<restart> is
allowed for the selected scope.

=cut
sub systemd_can_runtime
{
my ($acl, $action, $user_scope, $user) = @_;
return 0 if ($action !~ /^(start|stop|restart)$/);
my $key = $user_scope ? $action.'_user' : $action;
return systemd_acl_bool($acl, $key) &&
       systemd_can_view_scope($acl, $user_scope, $user) ? 1 : 0;
}

=head2 systemd_can_boot(&acl, user-scope, [user])

Returns 1 if enabling, disabling, masking or unmasking units is allowed.

=cut
sub systemd_can_boot
{
my ($acl, $user_scope, $user) = @_;
my $key = $user_scope ? 'boot_user' : 'boot';
return systemd_acl_bool($acl, $key) &&
       systemd_can_view_scope($acl, $user_scope, $user) ? 1 : 0;
}

=head2 systemd_can_mask(&acl, user-scope, [user])

Returns 1 if masking or unmasking units is allowed.

=cut
sub systemd_can_mask
{
my ($acl, $user_scope, $user) = @_;
my $key = $user_scope ? 'mask_user' : 'mask';
return systemd_acl_bool($acl, $key) &&
       systemd_can_view_scope($acl, $user_scope, $user) ? 1 : 0;
}

=head2 systemd_can_create(&acl, user-scope, [user])

Returns 1 if creating units in the selected scope is allowed.

=cut
sub systemd_can_create
{
my ($acl, $user_scope, $user) = @_;
my $key = $user_scope ? 'create_user' : 'create';
return systemd_acl_bool($acl, $key) &&
       systemd_can_view_scope($acl, $user_scope, $user) ? 1 : 0;
}

=head2 systemd_can_edit(&acl, user-scope, [user])

Returns 1 if editing a full unit file in the selected scope is allowed.

=cut
sub systemd_can_edit
{
my ($acl, $user_scope, $user) = @_;
my $key = $user_scope ? 'edit_user' : 'edit';
return systemd_acl_bool($acl, $key) &&
       systemd_can_view_scope($acl, $user_scope, $user) ? 1 : 0;
}

=head2 systemd_can_delete(&acl, user-scope, [user])

Returns 1 if deleting units in the selected scope is allowed.

=cut
sub systemd_can_delete
{
my ($acl, $user_scope, $user) = @_;
my $key = $user_scope ? 'delete_user' : 'delete';
return systemd_acl_bool($acl, $key) &&
       systemd_can_view_scope($acl, $user_scope, $user) ? 1 : 0;
}

=head2 systemd_can_dropin(&acl, user-scope, [user])

Returns 1 if managing drop-in overrides in the selected scope is allowed.

=cut
sub systemd_can_dropin
{
my ($acl, $user_scope, $user) = @_;
my $key = $user_scope ? 'dropin_user' : 'dropin';
return systemd_acl_bool($acl, $key) &&
       systemd_can_view_scope($acl, $user_scope, $user) ? 1 : 0;
}

=head2 systemd_can_manual(&acl, file-info)

Returns 1 if the ACL permits manual editing for a file descriptor returned by
C<list_manual_unit_files>.

=cut
sub systemd_can_manual
{
my ($acl, $info) = @_;
return 0 if (!$info || !$info->{'scope'});
if ($info->{'scope'} eq 'user') {
	return systemd_acl_bool($acl, 'manual_user') &&
	       systemd_acl_user_allowed($acl, $info->{'user'}) ? 1 : 0;
	}
return systemd_acl_bool($acl, 'manual') ? 1 : 0;
}

=head2 systemd_can_linger(&acl, user)

Returns 1 if managing linger for a Unix user is allowed.

=cut
sub systemd_can_linger
{
my ($acl, $user) = @_;
return systemd_acl_bool($acl, 'linger') &&
       systemd_acl_user_allowed($acl, $user) ? 1 : 0;
}

=head2 systemd_can_reload(&acl)

Returns 1 if reloading the system manager is allowed.

=cut
sub systemd_can_reload
{
my ($acl) = @_;
return systemd_acl_bool($acl, 'reload');
}

=head2 systemd_can_reload_user(&acl, user)

Returns 1 if reloading a user's systemd manager is allowed.

=cut
sub systemd_can_reload_user
{
my ($acl, $user) = @_;
return 0 if (!systemd_can_view_user_scope($acl, $user));
return systemd_acl_any($acl, qw(create_user edit_user delete_user
				dropin_user manual_user boot_user
				linger)) ? 1 : 0;
}

=head2 list_units()

Returns a list of all known systemd units managed by this module, each as a
hash ref with keys such as 'name', 'desc', 'unitstate', 'runtime', 'substate',
'pid' and 'file'.

=cut
sub list_units
{
if (@list_units_cache) {
	return @list_units_cache;
	}

my $units_piped = join('|', get_unit_types());
my $creatable_piped = join('|', get_creatable_unit_types());
my $list_piped = join('|', get_list_unit_types());
my $list_types = join(" ", map { "-t ".quotemeta($_) }
			   get_list_unit_types());

# Ask the running system manager for loaded units first.
my $out = backquote_command("systemctl list-units --full --all $list_types --no-legend");
my $ex = $?;
my @units;
foreach my $l (split(/\r?\n/, $out)) {
	$l =~ s/^[^a-z0-9\-\_\.]+//i;
	my ($unit, $loaded, $active, $sub, $desc) = split(/\s+/, $l, 5);
	if ($unit ne "UNIT" && $loaded eq "loaded") {
		push(@units, $unit);
		}
	}
error("Failed to list systemd units : $out") if ($ex && @units < 10);

# Also find unit files for units that may be disabled at boot and not running,
# and so don't show up in systemctl list-units.
my $local_root = get_unit_root();
my $packaged_root = get_unit_root(undef, 1);
my @scan_roots = ( [ $local_root, $creatable_piped ] );
push(@scan_roots, [ $packaged_root, $list_piped ])
	if ($packaged_root && $packaged_root ne $local_root);
foreach my $scan (@scan_roots) {
	my ($root, $type_piped) = @$scan;
	next if (!$root || !-d $root);
	opendir(my $units_dh, $root) || next;
	push(@units, grep { !/\.wants$/ && !/^\./ && !-d "$root/$_" &&
			    /\.($type_piped)$/ } readdir($units_dh));
	closedir($units_dh);
	}

# Add unit files that may not appear in list-units.
$out = backquote_command("systemctl list-unit-files $list_types --no-legend");
foreach my $l (split(/\r?\n/, $out)) {
	if ($l =~ /^(\S+\.($units_piped))\s+\S+/ ||
	    $l =~ /^(\S+)\s+\S+/) {
		push(@units, $1);
		}
	}

# Skip generated low-level units that are not useful outside the Devices tab.
@units = grep { !/^sys-devices-/ &&
	        !/^\-\.mount/ &&
	        !/^\-\.slice/ &&
		!/^systemd-/ } @units;
@units = unique(@units);

# Template units are listed by systemd but cannot be managed directly.
@units = grep { !/\@$/ && !/\@\.($units_piped)$/ } @units;
@units = grep { valid_unit_name($_) } @units;

# Dump unit state in batches to keep command lines at a safe length.
my %info;
my $ecount = 0;
while(@units) {
	my @args;
	while(@args < 100 && @units) {
		push(@args, shift(@units));
		}
	my $qargs = join(" ", map { quotemeta($_) } @args);
	my $out = backquote_command("systemctl show --property=Id,Description,UnitFileState,ActiveState,SubState,ExecStart,ExecStop,ExecReload,ExecMainPID,FragmentPath,DropInPaths ".$qargs." 2>/dev/null");
	my @lines = split(/\r?\n/, $out);
	my $curr;
	my @units;
	if (@lines) {
		$curr = { };
		push(@units, $curr);
		}
	foreach my $l (@lines) {
		if ($l eq "") {
			# Start of a new unit section
			$curr = { };
			push(@units, $curr);
			}
		else {
			# A property in the current one
			my ($n, $v) = split(/=/, $l, 2);
			$curr->{$n} = $v;
			}
		}
	foreach my $u (@units) {
		$info{$u->{'Id'}} = $u if ($u->{'Id'});
		}
	$ecount++ if ($?);
	}
if ($ecount && keys(%info) < 2) {
	error("Failed to read systemd units : ".
	       ui_tag('pre', html_escape($out)));
	}

# Convert systemctl properties into the compact row hashes used by the UI.
my @rv;
my %done;
foreach my $name (keys %info) {
	my $root = get_unit_root($name);
	my $i = $info{$name};
	my $file = $i->{'FragmentPath'};
	$file = $root."/".$name
		if (!$file && $root && -f $root."/".$name);
	next if ($i->{'Description'} =~ /^LSB:\s/);
	push(@rv, { 'name' => $name,
		    'desc' => $i->{'Description'},
		    'unitstate' => $i->{'UnitFileState'},
		    'runtime' => $i->{'ActiveState'},
		    'substate' => $i->{'SubState'},
		    'boot' => $i->{'UnitFileState'} eq 'enabled' ? 1 :
		              $i->{'UnitFileState'} eq 'static' ? 2 :
		              $i->{'UnitFileState'} eq 'masked' ? -1 : 0,
		    'status' => $i->{'ActiveState'} eq 'active' ? 1 : 0,
		    'start' => $i->{'ExecStart'},
		    'stop' => $i->{'ExecStop'},
		    'reload' => $i->{'ExecReload'},
		    'pid' => $i->{'ExecMainPID'},
		    'file' => $file,
		  });
	$done{$name}++;
	}

# Cache and return rows sorted by unit name.
@rv = sort { $a->{'name'} cmp $b->{'name'} } @rv;
@list_units_cache = @rv;
return @rv;
}

=head2 start_unit(name)

Starts a systemd unit and returns an OK flag and command output.

=cut
sub start_unit
{
my ($name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $out = backquote_logged(
	"systemctl start ".quotemeta($name)." 2>&1 </dev/null");
if ($? && $out =~ /journalctl/) {
	$out .= backquote_command("journalctl -xe 2>/dev/null");
	}
return (!$?, $out);
}

=head2 stop_unit(name)

Stops a systemd unit and returns an OK flag and command output.

=cut
sub stop_unit
{
my ($name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $out = backquote_logged(
	"systemctl stop ".quotemeta($name)." 2>&1 </dev/null");
return (!$?, $out);
}

=head2 restart_unit(name)

Restarts a systemd unit and returns an OK flag and command output.

=cut
sub restart_unit
{
my ($name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $out = backquote_logged(
	"systemctl restart ".quotemeta($name)." 2>&1 </dev/null");
return (!$?, $out);
}

=head2 reload_unit(name)

Reloads a systemd unit and returns an OK flag and command output.

=cut
sub reload_unit
{
my ($name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $out = backquote_logged(
	"systemctl reload ".quotemeta($name)." 2>&1 </dev/null");
return (!$?, $out);
}

=head2 status_unit(name)

Gets full status output for a systemd unit.

=cut
sub status_unit
{
my ($name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $out = backquote_logged(
	"systemctl --full --no-pager status ".quotemeta($name)." 2>&1 </dev/null");
return (!$?, $out);
}

=head2 properties_unit(name)

Gets systemd property output for a system unit.

=cut
sub properties_unit
{
my ($name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $out = backquote_logged(
	"systemctl --full --no-pager show ".quotemeta($name)." 2>&1 </dev/null");
return (!$?, $out);
}

=head2 dependencies_unit(name)

Gets dependency tree output for a systemd unit.

=cut
sub dependencies_unit
{
my ($name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $out = backquote_logged(
	"systemctl --full --no-pager list-dependencies ".quotemeta($name).
	" 2>&1 </dev/null");
return (!$?, $out);
}

=head2 logs_unit(name)

Gets recent journal logs for a systemd unit.

=cut
sub logs_unit
{
my ($name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $journalctl = has_command("journalctl");
return (0, $text{'systemd_ejournal'}) if (!$journalctl);
my $boot_arg = $config{'logs_current_boot'} ? " --boot" : "";
my $out = backquote_logged(
	quotemeta($journalctl)." --no-pager --unit ".quotemeta($name).
	" --lines ".int($config{'logs_lines'}).$boot_arg.
	" 2>&1 </dev/null");
return (!$?, $out);
}

=head2 enable_unit(name)

Enables a systemd unit at boot.

=cut
sub enable_unit
{
my ($name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $out = backquote_logged(
	"systemctl enable ".quotemeta($name)." 2>&1 </dev/null");
my $rv = $?;
reload_manager();
return (!$rv && !startup_change_skipped($out), $out);
}

=head2 disable_unit(name)

Disables a systemd unit at boot.

=cut
sub disable_unit
{
my ($name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $out = backquote_logged(
	"systemctl disable ".quotemeta($name)." 2>&1 </dev/null");
my $rv = $?;
reload_manager();
return (!$rv && !startup_change_skipped($out), $out);
}

=head2 mask_unit(name)

Masks a systemd unit so it cannot be started until unmasked.

=cut
sub mask_unit
{
my ($name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $out = backquote_logged(
	"systemctl mask ".quotemeta($name)." 2>&1 </dev/null");
my $rv = $?;
reload_manager();
return (!$rv, $out);
}

=head2 unmask_unit(name)

Unmasks a systemd unit so it can be started again.

=cut
sub unmask_unit
{
my ($name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $out = backquote_logged(
	"systemctl unmask ".quotemeta($name)." 2>&1 </dev/null");
my $rv = $?;
reload_manager();
return (!$rv, $out);
}

=head2 startup_change_skipped(output)

Returns 1 when systemctl says a unit cannot be enabled or disabled by design.

=cut
sub startup_change_skipped
{
my ($out) = @_;
return 0 if (!defined($out));
return $out =~ /no installation config/i ||
       $out =~ /not meant to be enabled or disabled/i ||
       $out =~ /\bis static\b/i ? 1 : 0;
}

=head2 split_exec_commands(command)

Splits a multi-line systemd command field into individual command lines.

=cut

sub split_exec_commands
{
my ($cmd) = @_;
return ( ) if (!defined($cmd));
$cmd =~ s/\r//g;
my @rv;
foreach my $l (split(/\n/, $cmd)) {
	$l =~ s/^\s+//;
	$l =~ s/\s+$//;
	push(@rv, $l) if ($l =~ /\S/);
	}
return @rv;
}

=head2 shell_exec_command(shell, command)

Returns a systemd command line to run some command via a shell.

=cut

sub shell_exec_command
{
my ($sh, $cmd) = @_;
$cmd =~ s/'/'\\''/g;
return "$sh -c '$cmd'";
}

=head2 format_exec_command(shell, command)

Returns a systemd command line, using a shell if redirection is needed.

=cut

sub format_exec_command
{
my ($sh, $cmd) = @_;
return $cmd =~ /<|>/ ? shell_exec_command($sh, $cmd) : $cmd;
}

=head2 clean_unit_value(value)

Returns a scalar systemd unit value with line breaks removed.

=cut
sub clean_unit_value
{
my ($value) = @_;
return if (!defined($value));
$value =~ s/\r|\n/ /g;
$value =~ s/\0//g;
$value =~ s/^\s+//;
$value =~ s/\s+$//;
return $value;
}

=head2 clean_unit_body(value)

Returns multi-line systemd unit directives with nulls and carriage returns
removed.

=cut
sub clean_unit_body
{
my ($value) = @_;
return if (!defined($value));
$value =~ s/\r//g;
$value =~ s/\0//g;
$value =~ s/^\s+//;
$value =~ s/\s+$//;
return $value;
}

=head2 quote_unit_word(value)

Returns a quoted systemd unit word with quotes and backslashes escaped.

=cut
sub quote_unit_word
{
my ($value) = @_;
$value =~ s/\\/\\\\/g;
$value =~ s/"/\\"/g;
return "\"$value\"";
}

=head2 split_environment_assignments(value)

Splits Environment= input into assignments, allowing quoted values after the
NAME= prefix.

=cut
sub split_environment_assignments
{
my ($value) = @_;
my @rv;
my $current = "";
my $quote = "";
for(my $i = 0; $i < length($value); $i++) {
	my $ch = substr($value, $i, 1);
	if ($quote) {
		if ($ch eq "\\" && $quote eq '"' && $i + 1 < length($value)) {
			$current .= substr($value, ++$i, 1);
			}
		elsif ($ch eq $quote) {
			$quote = "";
			}
		else {
			$current .= $ch;
			}
		}
	elsif ($ch eq '"' || $ch eq "'") {
		$quote = $ch;
		}
	elsif ($ch =~ /\s/) {
		if (length($current)) {
			push(@rv, $current);
			$current = "";
			}
		}
	else {
		$current .= $ch;
		}
	}
push(@rv, $current) if (length($current));
return @rv;
}

=head2 format_environment_directives(value)

Returns Environment= lines for a user-entered set of environment variables.

=cut
sub format_environment_directives
{
my ($value) = @_;
$value = clean_unit_value($value);
$value = "" if (!defined($value));
return ( ) if ($value !~ /\S/);

# Preserve quoted variable values while still allowing several NAME=VALUE
# words to become separate Environment= directives.
my @vars = split_environment_assignments($value);
@vars = ( $value ) if (!@vars);
return map { "Environment=".quote_unit_word($_)."\n" } @vars;
}

=head2 format_output_value(value)

Returns a StandardOutput/StandardError value, appending to absolute files.

=cut
sub format_output_value
{
my ($value) = @_;
$value = clean_unit_value($value);
$value = "" if (!defined($value));
return if ($value !~ /\S/);
return $value =~ /^\// ? "append:$value" : $value;
}

=head2 valid_duration(value)

Returns 1 if a value matches systemd's duration syntax used by timeout fields.

=cut
sub valid_duration
{
my ($value) = @_;
my $unit = qr/usec|us|msec|ms|seconds?|sec|s|minutes?|min|m|hours?|hr|h|days?|d|weeks?|w|months?|M|years?|y/i;
$value =~ s/^\s+//;
$value =~ s/\s+$//;
return 1 if ($value =~ /^infinity$/i);
return 0 if ($value !~ /\S/);
while ($value =~ /\G\s*\d+(?:\.\d+)?\s*(?:$unit)?/gc) {
	}
return defined(pos($value)) && pos($value) == length($value);
}

=head2 valid_path(value, allow-dash, allow-tilde, allow-plus)

Returns 1 if a unit-file path option is absolute or explicitly allowed.

=cut
sub valid_path
{
my ($value, $allow_dash, $allow_tilde, $allow_plus) = @_;
return 0 if (!defined($value));
$value =~ s/^\s+//;
$value =~ s/\s+$//;
$value =~ s/^-// if ($allow_dash);
$value =~ s/^\+// if ($allow_plus);
return 0 if ($value =~ /[\r\n\0=\s]/);
return 1 if ($value =~ /^\//);
return 1 if ($allow_tilde && $value =~ /^~/);
return 0;
}

=head2 path_unit_name(path, type)

Returns the canonical systemd unit name for a mount-like path and unit type.

=cut
sub path_unit_name
{
my ($path, $type) = @_;
$type ||= "mount";
$path = clean_unit_value($path);
return if (!$path || !valid_path($path, 0, 0, 0));
return if ($type !~ /^(mount|automount)$/);

# Prefer systemd's own escaping when it is available. The fallback supports the
# common ASCII path names used by Webmin's structured mount forms.
my $escape = has_command("systemd-escape");
if ($escape) {
	my $cmd = quotemeta($escape)." --path --suffix=".quotemeta($type)." ".
		  quotemeta($path)." 2>/dev/null";
	my $out = backquote_command($cmd);
	$out =~ s/\r//g;
	$out =~ s/\s+$//;
	return $out if (valid_creatable_unit_name($out));
	}

my $name = $path;
$name =~ s{/+}{/}g;
$name =~ s{/$}{} if ($name ne "/");
$name = $name eq "/" ? "-" : substr($name, 1);
return if ($name =~ /[^A-Za-z0-9_.:@\/-]/);
$name =~ s{/}{-}g;
$name .= ".".$type;
return valid_creatable_unit_name($name) ? $name : undef;
}

=head2 mount_where_from_data(data)

Returns the Where= path from a rendered mount unit body.

=cut
sub mount_where_from_data
{
my ($data) = @_;
return if (!defined($data));
my $section = "";
foreach my $line (split(/\n/, $data)) {
	$line =~ s/\r$//;
	if ($line =~ /^\s*\[([^\]]+)\]\s*$/) {
		$section = lc($1);
		next;
		}
	next if ($section ne "mount" || $line =~ /^\s*[#;]/);
	if ($line =~ /^\s*Where\s*=\s*(.*?)\s*$/) {
		my $where = clean_unit_value($1);
		return $where if ($where && valid_path($where, 0, 0, 0));
		}
	}
return;
}

=head2 mount_unit_where(unit, [user])

Returns the Where= path for an existing mount unit file.

=cut
sub mount_unit_where
{
my ($unit, $user) = @_;
return if (!ref($unit) || $unit->{'name'} !~ /\.mount$/);
my $file = $unit->{'file'};
return if (!$file);
my $data;
if ($unit->{'user_scope'} || $user) {
	my $owner = $user || $unit->{'user'};
	$data = read_user_unit_file($owner, $file) if ($owner);
	}
elsif ($file !~ /\0/ && -r $file) {
	$data = read_file_contents($file);
	}
return mount_where_from_data($data);
}

=head2 render_directive_body(directives)

Returns directive lines from C<[ name, value ]> pairs, skipping blank values.

=cut
sub render_directive_body
{
my ($directives) = @_;
my $body = "";
foreach my $row (@$directives) {
	my $value = clean_unit_value($row->[1]);
	$body .= $row->[0]."=$value\n" if ($value && $value =~ /\S/);
	}
return $body;
}

=head2 render_timer_body(options)

Returns the [Timer] body generated from structured timer fields.

=cut
sub render_timer_body
{
my ($opts) = @_;
$opts = { } if (!ref($opts));
return render_directive_body([
	[ 'OnCalendar', $opts->{'oncalendar'} ],
	[ 'OnBootSec', $opts->{'onbootsec'} ],
	[ 'OnUnitActiveSec', $opts->{'onunitactivesec'} ],
	[ 'Persistent', $opts->{'persistent'} ? 'yes' : undef ],
	[ 'RandomizedDelaySec', $opts->{'randomizeddelaysec'} ],
	[ 'AccuracySec', $opts->{'accuracysec'} ],
	[ 'Unit', $opts->{'unit'} ],
	]);
}

=head2 render_socket_body(options)

Returns the [Socket] body generated from structured socket fields.

=cut
sub render_socket_body
{
my ($opts) = @_;
$opts = { } if (!ref($opts));
return render_directive_body([
	[ 'ListenStream', $opts->{'listenstream'} ],
	[ 'ListenDatagram', $opts->{'listendatagram'} ],
	[ 'ListenFIFO', $opts->{'listenfifo'} ],
	[ 'Accept', $opts->{'accept'} ? 'yes' : undef ],
	[ 'SocketUser', $opts->{'user'} ],
	[ 'SocketGroup', $opts->{'group'} ],
	[ 'SocketMode', $opts->{'mode'} ],
	[ 'Service', $opts->{'service'} ],
	]);
}

=head2 render_path_body(options)

Returns the [Path] body generated from structured path fields.

=cut
sub render_path_body
{
my ($opts) = @_;
$opts = { } if (!ref($opts));
return render_directive_body([
	[ 'PathExists', $opts->{'exists'} ],
	[ 'PathExistsGlob', $opts->{'existsglob'} ],
	[ 'PathChanged', $opts->{'changed'} ],
	[ 'PathModified', $opts->{'modified'} ],
	[ 'DirectoryNotEmpty', $opts->{'directorynotempty'} ],
	[ 'MakeDirectory', $opts->{'makedirectory'} ? 'yes' : undef ],
	[ 'Unit', $opts->{'unit'} ],
	]);
}

=head2 render_mount_body(what, where, type, options)

Returns the [Mount] body generated from structured mount fields.

=cut
sub render_mount_body
{
my ($what, $where, $type, $options) = @_;
return render_directive_body([
	[ 'What', $what ],
	[ 'Where', $where ],
	[ 'Type', $type ],
	[ 'Options', $options ],
	]);
}

=head2 render_automount_body(where, timeout-idle, directory-mode)

Returns the [Automount] body generated from structured automount fields.

=cut
sub render_automount_body
{
my ($where, $idle, $mode) = @_;
return render_directive_body([
	[ 'Where', $where ],
	[ 'TimeoutIdleSec', $idle ],
	[ 'DirectoryMode', $mode ],
	]);
}

=head2 render_swap_body(options)

Returns the [Swap] body generated from structured swap fields.

=cut
sub render_swap_body
{
my ($opts) = @_;
$opts = { } if (!ref($opts));
return render_directive_body([
	[ 'What', $opts->{'what'} ],
	[ 'Priority', $opts->{'priority'} ],
	[ 'Options', $opts->{'options'} ],
	[ 'TimeoutSec', $opts->{'timeoutsec'} ],
	]);
}

=head2 render_slice_body(options)

Returns the [Slice] body generated from structured resource-control fields.

=cut
sub render_slice_body
{
my ($opts) = @_;
$opts = { } if (!ref($opts));
return render_directive_body([
	[ 'CPUWeight', $opts->{'cpuweight'} ],
	[ 'MemoryMax', $opts->{'memorymax'} ],
	[ 'TasksMax', $opts->{'tasksmax'} ],
	[ 'IOWeight', $opts->{'ioweight'} ],
	]);
}

=head2 valid_output(value)

Returns 1 if a StandardOutput/StandardError value is a safe systemd target.

=cut
sub valid_output
{
my ($value) = @_;
return 0 if ($value =~ /[\r\n\0=\s]/);
return 1 if ($value =~ /^\//);
return 1 if ($value =~ /^(inherit|null|tty|journal|kmsg|journal\+console|kmsg\+console|socket|fd:[A-Za-z0-9_.:-]+|file:\/\S+|append:\/\S+|truncate:\/\S+)$/);
return 0;
}

=head2 clean_unit_options(options, [command-keys])

Returns a cleaned copy of a unit options hash. Values named in command-keys
keep line breaks because they later become one Exec*= directive per line.

=cut
sub clean_unit_options
{
my ($opts, $command_keys) = @_;
my %commands = map { $_, 1 } ref($command_keys) ? @$command_keys : ( );
my %cleanopts;
if (ref($opts)) {
	foreach my $o (keys(%$opts)) {
		$cleanopts{$o} = $commands{$o} ?
			clean_unit_body($opts->{$o}) :
			clean_unit_value($opts->{$o});
		}
	}
return \%cleanopts;
}

=head2 render_unit_directives(options)

Returns common [Unit] dependency directives from a cleaned options hash.

=cut
sub render_unit_directives
{
my ($opts) = @_;
my $data = "";
foreach my $d (
	[ 'before', 'Before' ],
	[ 'after', 'After' ],
	[ 'wants', 'Wants' ],
	[ 'requires', 'Requires' ],
	[ 'conflicts', 'Conflicts' ],
	[ 'onfailure', 'OnFailure' ],
	[ 'onsuccess', 'OnSuccess' ],
	) {
	my ($key, $directive) = @$d;
	$data .= "$directive=$opts->{$key}\n" if ($opts->{$key});
	}
return $data;
}

=head2 render_service_section(service, options)

Returns the [Service] section for a systemd service unit spec.

=cut
sub render_service_section
{
my ($service, $opts) = @_;
$service = { } if (!ref($service));
my $sh = has_command("sh") || "sh";
my $pidfile = clean_unit_value($service->{'pidfile'});
my @starts = split_exec_commands($service->{'start'});
my @stops = split_exec_commands($service->{'stop'});
my @reloads = split_exec_commands($service->{'reload'});
my $remain = $service->{'remain'};
my $service_type = ref($opts) ? $opts->{'type'} : undef;
$service_type ||= $remain ? 'oneshot' : undef;

# Multiple startup commands need oneshot semantics unless an explicit type was
# chosen.  For other types, run them through one shell command.
my $multi_start_oneshot = @starts > 1 && !$service_type;
my $start_type = $service_type || ($multi_start_oneshot ? 'oneshot' : undef);
if (@starts > 1 && $start_type && $start_type ne 'oneshot') {
	@starts = (shell_exec_command($sh, join("; ", @starts)));
	}
else {
	@starts = map { format_exec_command($sh, $_) } @starts;
	}
@stops = map { format_exec_command($sh, $_) } @stops;
@reloads = map { format_exec_command($sh, $_) } @reloads;
my (@startpres, @startposts, @stopposts);
if (ref($opts)) {
	@startpres = map { format_exec_command($sh, $_) }
		      split_exec_commands($opts->{'startpre'});
	@startposts = map { format_exec_command($sh, $_) }
		       split_exec_commands($opts->{'startpost'});
	@stopposts = map { format_exec_command($sh, $_) }
		      split_exec_commands($opts->{'stoppost'});
	}
$service_type = 'oneshot' if ($multi_start_oneshot);
my $data = "\n[Service]\n";
$data .= "Type=$service_type\n" if ($service_type);
foreach my $startpre (@startpres) {
	$data .= "ExecStartPre=$startpre\n";
	}
foreach my $start (@starts) {
	$data .= "ExecStart=$start\n";
	}
foreach my $startpost (@startposts) {
	$data .= "ExecStartPost=$startpost\n";
	}
foreach my $stop (@stops) {
	$data .= "ExecStop=$stop\n";
	}
foreach my $stoppost (@stopposts) {
	$data .= "ExecStopPost=$stoppost\n";
	}
foreach my $reload (@reloads) {
	$data .= "ExecReload=$reload\n";
	}
$data .= "RemainAfterExit=yes\n" if ($remain);
$data .= "PIDFile=$pidfile\n" if ($pidfile);

# Optional [Service] directives from the advanced creation form.
if (ref($opts)) {
	foreach my $env (format_environment_directives($opts->{'env'})) {
		$data .= $env;
		}
	$data .= "EnvironmentFile=$opts->{'envfile'}\n" if ($opts->{'envfile'});
	$data .= "User=$opts->{'user'}\n" if ($opts->{'user'});
	$data .= "Group=$opts->{'group'}\n" if ($opts->{'group'});
	$data .= "KillMode=$opts->{'killmode'}\n" if ($opts->{'killmode'});
	$data .= "WorkingDirectory=$opts->{'workdir'}\n" if ($opts->{'workdir'});
	$data .= "Restart=$opts->{'restart'}\n" if ($opts->{'restart'});
	$data .= "RestartSec=$opts->{'restartsec'}\n" if ($opts->{'restartsec'});
	$data .= "WatchdogSec=$opts->{'watchdogsec'}\n" if ($opts->{'watchdogsec'});

	# timeout remains accepted as a historical alias for TimeoutStartSec.
	my $timeoutstartsec = $opts->{'timeoutstartsec'} || $opts->{'timeout'};
	$data .= "TimeoutStartSec=$timeoutstartsec\n" if ($timeoutstartsec);
	$data .= "TimeoutStopSec=$opts->{'timeoutstopsec'}\n"
		if ($opts->{'timeoutstopsec'});
	$data .= "LimitNOFILE=$opts->{'limitnofile'}\n" if ($opts->{'limitnofile'});
	my $logout = format_output_value($opts->{'logstd'});
	my $logerr = format_output_value($opts->{'logerr'});
	$data .= "StandardOutput=$logout\n" if ($logout);
	$data .= "StandardError=$logerr\n" if ($logerr);
	$data .= "SyslogIdentifier=$opts->{'syslogid'}\n" if ($opts->{'syslogid'});
	$data .= "NoNewPrivileges=yes\n" if ($opts->{'nonewprivs'});
	$data .= "PrivateTmp=yes\n" if ($opts->{'privatetmp'});
	$data .= "ProtectSystem=$opts->{'protectsystem'}\n" if ($opts->{'protectsystem'});
	$data .= "ReadWritePaths=$opts->{'readwritepaths'}\n" if ($opts->{'readwritepaths'});
	}

return $data;
}

=head2 render_typed_section(type, body)

Returns the type-specific section for a non-service systemd unit spec.

=cut
sub render_typed_section
{
my ($type, $body) = @_;
my $section = get_unit_section($type);
$body = clean_unit_body($body);
$body = "" if (!defined($body));
my $data = "";

# The UI accepts only the body of the type-specific section; wrap it here so
# users do not need to type [Timer], [Socket], and so on.
if ($section && $body =~ /\S/) {
	$data .= "\n[$section]\n";
	$data .= $body;
	$data .= "\n" if ($body !~ /\n$/);
	}

return $data;
}

=head2 render_install_section(type, options)

Returns the [Install] section for a unit when it has a target.

=cut
sub render_install_section
{
my ($type, $opts) = @_;
my $wantedby = $opts->{'wantedby'};
$wantedby ||= "multi-user.target" if ($type eq "service");
return "" if (!$wantedby);
return "\n[Install]\nWantedBy=$wantedby\n";
}

=head2 render_unit(unit)

Returns complete unit-file contents for a systemd unit spec hash. The hash
must include type and description, plus either service details or a body.

=cut
sub render_unit
{
my ($unit) = @_;
$unit = { } if (!ref($unit));
my $type = $unit->{'type'} || "service";
my @command_opts = $type eq "service" ?
	( 'startpre', 'startpost', 'stoppost' ) : ( );
my $opts = clean_unit_options($unit->{'options'}, \@command_opts);
my $desc = clean_unit_value($unit->{'description'});
my $data = "[Unit]\n";
$data .= "Description=$desc\n" if ($desc);
$data .= render_unit_directives($opts);
if ($type eq "service") {
	$data .= render_service_section($unit->{'service'}, $opts);
	}
else {
	$data .= render_typed_section($type, $unit->{'body'});
	}
$data .= render_install_section($type, $opts);
return $data;
}

=head2 write_unit_file(file, data)

Writes rendered systemd unit-file contents to disk.

=cut
sub write_unit_file
{
my ($cfile, $data) = @_;
my $cfile_fh = gensym();
open_lock_tempfile($cfile_fh, ">$cfile");
print_tempfile($cfile_fh, $data);
close_tempfile($cfile_fh);
}

=head2 create_system_unit(name, data)

Creates a system unit from rendered unit-file contents.

=cut
sub create_system_unit
{
my ($name, $data) = @_;
return (0, $text{'systemd_ename'}) if (!valid_creatable_unit_name($name));
my $cfile = get_unit_root($name)."/".$name;
my ($vok, $vout) = verify_unit_data($cfile, $data, 0);
return (0, $vout) if (!$vok);
write_unit_file($cfile, $data);
reload_manager();
return (1, "");
}

=head2 get_user_details(user)

Returns user account details needed for per-user systemd units.

=cut
sub get_user_details
{
my ($user) = @_;
return if (!$user || $user =~ /[\0\r\n\/]/);
my @uinfo = getpwnam($user);
return if (!@uinfo || $uinfo[7] !~ /^\//);
return { 'user' => $uinfo[0],
	 'uid' => $uinfo[2],
	 'gid' => $uinfo[3],
	 'home' => $uinfo[7] };
}

=head2 get_user_root(user)

Returns the base directory for a user's systemd unit config files.

=cut
sub get_user_root
{
my ($user) = @_;
my $uinfo = get_user_details($user);
return if (!$uinfo);
return $uinfo->{'home'}."/.config/systemd/user";
}

=head2 valid_unit_name(name)

Returns 1 if a systemd unit name is safe to pass to systemctl or use for
drop-in file management.

=cut
sub valid_unit_name
{
my ($name) = @_;
my $units_piped = join('|', get_unit_types());
return 0 if ($name =~ /\@$/ || $name =~ /\@\.($units_piped)$/i);
return $name && $name =~ /^[a-z0-9\.\_\-\@:]+\.($units_piped)$/i;
}

=head2 valid_creatable_unit_name(name, [user-scope])

Returns 1 if a systemd unit name is safe for creating a persistent unit file.

=cut
sub valid_creatable_unit_name
{
my ($name, $user_scope) = @_;
my $units_piped = join('|', get_creatable_unit_types($user_scope));
return 0 if ($name =~ /\@$/ || $name =~ /\@\.($units_piped)$/i);
return $name && $name =~ /^[a-z0-9\.\_\-\@:]+\.($units_piped)$/i;
}

=head2 valid_unit_file_name(name)

Returns 1 if a filename looks like a direct systemd unit file. Unlike
C<valid_unit_name>, this accepts all known unit suffixes and template files
because it is used only by the manual file editor.

=cut
sub valid_unit_file_name
{
my ($name) = @_;
my $units_piped = join('|', get_unit_types());
return $name && $name !~ /[\0\r\n\/]/ && $name !~ /^\./ &&
       $name =~ /^[a-z0-9\.\_\-\@:]+\.($units_piped)$/i;
}

=head2 verify_unit_data(file, data, [user-scope], [user])

Runs C<systemd-analyze verify> against unit-file contents before a manual save.

=cut
sub verify_unit_data
{
my ($file, $data, $user_scope, $user) = @_;
my $analyze = has_command("systemd-analyze");
return (1, undef) if (!$analyze);
return (0, $text{'systemd_econf'}) if (!defined($data));
my $name = $file;
$name =~ s/^.*\///;
return (0, $text{'systemd_ename'}) if (!valid_unit_file_name($name));
my $uinfo = $user_scope && $user ? get_user_details($user) : undef;
my $bad_user = text('systemd_everify',
		    ui_tag('tt', html_escape($text{'systemd_euser'})));

# Verify a temporary file with the real unit basename so systemd checks the
# correct unit type without touching the currently installed file.
my $tmpdir = tempname("systemd-verify-$$-".int(rand(1000000)));
make_dir($tmpdir, oct("0700")) ||
	return (0, text('systemd_everify',
			ui_tag('tt', html_escape($!))));
my $tmpfile = $tmpdir."/".$name;
my $write_ok = eval {
	open(my $tmp_fh, ">", $tmpfile) || die "$tmpfile: $!";
	print {$tmp_fh} $data;
	close($tmp_fh) || die "$tmpfile: $!";
	if ($uinfo) {
		set_ownership_permissions(
			$uinfo->{'uid'}, $uinfo->{'gid'}, oct("0700"), $tmpdir);
		set_ownership_permissions(
			$uinfo->{'uid'}, $uinfo->{'gid'}, oct("0600"), $tmpfile);
		}
	1;
	};
if (!$write_ok) {
	my $err = $@ || $!;
	unlink($tmpfile);
	rmdir($tmpdir);
	return (0, text('systemd_everify',
			ui_tag('tt', html_escape($err))));
	}

# User units have slightly different directive rules, so verify them through
# the target user's manager environment when the owner is known.
my $cmd = $uinfo ?
	user_manager_command($user, quotemeta($analyze), "--user",
			     "verify", quotemeta($tmpfile)) :
	quotemeta($analyze)." ".($user_scope ? "--user " : "").
		"verify ".quotemeta($tmpfile);
return (0, $bad_user) if (!$cmd);
$cmd .= " 2>&1 </dev/null";
my $out = backquote_logged($cmd);
my $rv = $?;
unlink($tmpfile);
rmdir($tmpdir);
my $issue = $out;
$issue =~ s/^\s+|\s+$//g;
return (1, undef) if (!$rv && !$issue);
$out ||= $text{'manual_ewrite'};
return (0, text('systemd_everify', ui_tag('tt', html_escape($out))));
}

=head2 valid_unit_file_component(name)

Returns 1 if a value is safe as a direct systemd unit directory entry.

=cut
sub valid_unit_file_component
{
my ($name) = @_;
return 0 if (!$name || $name =~ /[\0\r\n\/]/ || $name =~ /^\./ ||
	     $name =~ /\.wants$/ || $name =~ /\@$/);
return 1 if (valid_unit_name($name));
return $name =~ /^[a-z0-9\.\_\-\@:]+$/i ? 1 : 0;
}

=head2 user_root_safe(user)

Returns 1 if the user's systemd unit config path does not contain symlinked
components controlled by the user.

=cut
sub user_root_safe
{
my ($user) = @_;
my $uinfo = get_user_details($user);
return 0 if (!$uinfo);

# Every path component below ~/.config is user-controlled.  Reject symlinks,
# non-directories and directories not owned by the target user.
foreach my $dir ($uinfo->{'home'}."/.config",
		 $uinfo->{'home'}."/.config/systemd",
		 $uinfo->{'home'}."/.config/systemd/user") {
	next if (!-e $dir && !-l $dir);
	return 0 if (!user_unit_dir_safe($uinfo, $dir));
	}
return 1;
}

=head2 user_unit_dir_safe(user-info, dir)

Returns 1 if a systemd user-unit directory is an existing directory owned by
the target Unix user, or if it does not exist yet.

=cut
sub user_unit_dir_safe
{
my ($uinfo, $dir) = @_;
return 0 if (!$uinfo);
return 1 if (!-e $dir && !-l $dir);
return 0 if (-l $dir || !-d $dir);
my @st = lstat($dir);
return 0 if (!@st);
return $st[4] == $uinfo->{'uid'} ? 1 : 0;
}

=head2 check_user_unit_dirs(user)

Returns an OK flag and error message after checking the user's systemd unit
directory tree for unsafe or wrongly-owned directories.

=cut
sub check_user_unit_dirs
{
my ($user) = @_;
my $uinfo = get_user_details($user);
return (0, $text{'systemd_euser'}) if (!$uinfo);

# Check the fixed parent directories first.
foreach my $dir ($uinfo->{'home'}."/.config",
		 $uinfo->{'home'}."/.config/systemd",
		 $uinfo->{'home'}."/.config/systemd/user") {
	if (!user_unit_dir_safe($uinfo, $dir)) {
		return (0, $text{'systemd_euserunitdir'});
		}
	}

# systemctl --user enable/disable writes below *.wants and *.requires
# directories.  Existing drop-in directories are checked too.
my $root = get_user_root($user);
if ($root && -d $root && !-l $root) {
	opendir(my $dh, $root) || return (0, $text{'systemd_euserunitdir'});
	foreach my $entry (readdir($dh)) {
		next if ($entry !~ /\.(?:wants|requires|d)$/);
		my $dir = $root."/".$entry;
		if (!user_unit_dir_safe($uinfo, $dir)) {
			closedir($dh);
			return (0, $text{'systemd_euserunitdir'});
			}
		}
	closedir($dh);
	}
return (1, undef);
}

=head2 user_unit_file_safe(user, file, [must-exist])

Returns 1 if a user unit file is a direct, non-symlinked file below the
user's systemd unit config directory.

=cut
sub user_unit_file_safe
{
my ($user, $file, $must_exist) = @_;
my $root = get_user_root($user);
return 0 if (!$root || !$file || $file =~ /[\0\r\n]/);
return 0 if (!user_root_safe($user));

# Only direct child unit files are managed.  This prevents path traversal and
# avoids following user-created subdirectories or symlinks.
return 0 if ($file !~ /^\Q$root\E\/([^\/]+)$/);
my $unit = $1;
return 0 if (!valid_unit_name($unit));
return 0 if (-l $file);
return $must_exist ? -f $file : (!-e $file || -f $file);
}

=head2 read_user_unit_file(user, file)

Reads a user unit file as the owning Unix user after path validation.

=cut
sub read_user_unit_file
{
my ($user, $file) = @_;
return if (!user_unit_file_safe($user, $file, 1));
return eval_as_unix_user($user, sub {
	return read_file_contents($file);
	});
}

=head2 write_user_unit_file(user, file, data)

Writes a user unit file as the owning Unix user after path validation.

=cut
sub write_user_unit_file
{
my ($user, $file, $data) = @_;
return (0, $text{'systemd_euserunitfile'})
	if (!user_unit_file_safe($user, $file, 0));
return (1, undef) if (is_readonly_mode());
my $ok = eval {
	# Drop privileges for the actual write so a race cannot make root write
	# through a user-controlled symlink.
	eval_as_unix_user($user, sub {
		die $text{'systemd_euserunitfile'}
			if (-l $file || (-e $file && !-f $file));
		my $userunit_fh = gensym();
		open_lock_tempfile($userunit_fh, ">$file");
		print_tempfile($userunit_fh, $data);
		close_tempfile($userunit_fh);
		set_ownership_permissions(undef, undef, oct("0644"), $file);
		});
	1;
	};
my $err = $@;
$err =~ s/\s+at\s+(\/\S+)\s+line\s+(\d+)\.?// if ($err);
return $ok ? (1, undef) : (0, $err || $text{'systemd_euserunitfile'});
}

=head2 verify_dropin_data(unit-file, unit-data, dropin-data, [user-scope], [unit-state], [user])

Runs C<systemd-analyze verify> against a unit plus an override drop-in.
Transient units are skipped because they are not normal file-backed units, and
systemd-analyze cannot reliably load their temporary copies by name.

=cut
sub verify_dropin_data
{
my ($file, $unit_data, $dropin_data, $user_scope, $unitstate, $user) = @_;
my $analyze = has_command("systemd-analyze");
return (1, undef) if (!$analyze);
return (0, $text{'systemd_econf'})
	if (!defined($unit_data) || !defined($dropin_data));
my $name = $file;
$name =~ s/^.*\///;
return (0, $text{'systemd_ename'}) if (!valid_unit_file_name($name));
return (1, undef)
	if (dropin_verify_unsupported($file, $unitstate));
my $uinfo = $user_scope && $user ? get_user_details($user) : undef;
my $bad_user = text('systemd_everify',
		    ui_tag('tt', html_escape($text{'systemd_euser'})));

# Recreate the target unit and its drop-in in a temporary tree so verify sees
# the same shape systemd will load, without touching the installed files.
my $tmpdir = tempname("systemd-dropin-verify-$$-".int(rand(1000000)));
make_dir($tmpdir, oct("0700")) ||
	return (0, text('systemd_everify',
			ui_tag('tt', html_escape($!))));
my $tmpfile = $tmpdir."/".$name;
my $dropdir = $tmpfile.".d";
my $dropfile = $dropdir."/override.conf";
my $write_ok = eval {
	open(my $unit_fh, ">", $tmpfile) || die "$tmpfile: $!";
	print {$unit_fh} $unit_data;
	close($unit_fh) || die "$tmpfile: $!";
	make_dir($dropdir, oct("0700")) || die "$dropdir: $!";
	open(my $drop_fh, ">", $dropfile) || die "$dropfile: $!";
	print {$drop_fh} $dropin_data;
	close($drop_fh) || die "$dropfile: $!";
	if ($uinfo) {
		foreach my $dir ($tmpdir, $dropdir) {
			set_ownership_permissions(
				$uinfo->{'uid'}, $uinfo->{'gid'},
				oct("0700"), $dir);
			}
		foreach my $file ($tmpfile, $dropfile) {
			set_ownership_permissions(
				$uinfo->{'uid'}, $uinfo->{'gid'},
				oct("0600"), $file);
			}
		}
	1;
	};
if (!$write_ok) {
	my $err = $@ || $!;
	unlink($dropfile);
	rmdir($dropdir);
	unlink($tmpfile);
	rmdir($tmpdir);
	return (0, text('systemd_everify',
			ui_tag('tt', html_escape($err))));
	}

my $cmd = $uinfo ?
	user_manager_command($user, quotemeta($analyze), "--user",
			     "verify", quotemeta($tmpfile)) :
	quotemeta($analyze)." ".($user_scope ? "--user " : "").
		"verify ".quotemeta($tmpfile);
return (0, $bad_user) if (!$cmd);
$cmd .= " 2>&1 </dev/null";
my $out = backquote_logged($cmd);
my $rv = $?;
unlink($dropfile);
rmdir($dropdir);
unlink($tmpfile);
rmdir($tmpdir);
my $issue = $out;
$issue =~ s/^\s+|\s+$//g;
return (1, undef) if (!$rv && !$issue);
$out ||= $text{'manual_ewrite'};
return (0, text('systemd_everify', ui_tag('tt', html_escape($out))));
}

=head2 dropin_verify_unsupported(file, [unit-state])

Returns 1 for drop-ins that cannot be checked reliably with
C<systemd-analyze verify>.

=cut
sub dropin_verify_unsupported
{
my ($file, $unitstate) = @_;
return 1 if (defined($unitstate) && $unitstate eq 'transient');
return 1 if (defined($file) && $file =~ m{/systemd/transient/});
return 0;
}

=head2 system_dropin_file(unit)

Returns the standard local drop-in override file for a system unit.

=cut
sub system_dropin_file
{
my ($unit) = @_;
return if (!valid_unit_name($unit));
return "/etc/systemd/system/$unit.d/override.conf";
}

=head2 read_system_dropin_file(unit)

Reads the standard system drop-in override file, if it exists and is safe.

=cut
sub read_system_dropin_file
{
my ($unit) = @_;
my $file = system_dropin_file($unit);
return if (!$file);
my $dir = $file;
$dir =~ s{/[^/]+$}{};
return if (-l $dir || (-e $dir && !-d $dir));
return "" if (!-e $file);
return if (-l $file || !-f $file);
lock_file($file);
my $data = read_file_contents($file);
unlock_file($file);
return $data;
}

=head2 dropin_exists(user-scope, user, unit)

Returns 1 if the standard drop-in override file exists and is safe to open.

=cut
sub dropin_exists
{
my ($user_scope, $user, $unit) = @_;
if ($user_scope) {
	my $file = user_dropin_file($user, $unit);
	return $file && user_dropin_file_safe($user, $file, 1) ? 1 : 0;
	}
my $file = system_dropin_file($unit);
return 0 if (!$file);
my $dir = $file;
$dir =~ s{/[^/]+$}{};
return 0 if (-l $dir || (-e $dir && !-d $dir));
return -f $file && !-l $file ? 1 : 0;
}

=head2 write_system_dropin_file(unit, data)

Writes the standard local drop-in override file for a system unit.

=cut
sub write_system_dropin_file
{
my ($unit, $data) = @_;
my $file = system_dropin_file($unit);
return (0, $text{'systemd_ename'}) if (!$file);
my $dir = $file;
$dir =~ s{/[^/]+$}{};
return (0, $text{'systemd_edropinfile'})
	if (-l $dir || (-e $dir && !-d $dir));
return (1, undef) if (is_readonly_mode());
if (!-d $dir) {
	make_dir($dir, oct("0755"), 0) ||
		return (0, "$dir: $!");
	}
return (0, $text{'systemd_edropinfile'})
	if (-l $dir || !-d $dir || -l $file ||
	    (-e $file && !-f $file));
lock_file($file);
my $fh = gensym();
open_tempfile($fh, ">$file");
print_tempfile($fh, defined($data) ? $data : "");
close_tempfile($fh);
unlock_file($file);
return (1, undef);
}

=head2 delete_system_dropin_file(unit)

Deletes the standard local drop-in override file for a system unit.

=cut
sub delete_system_dropin_file
{
my ($unit) = @_;
my $file = system_dropin_file($unit);
return (0, $text{'systemd_ename'}) if (!$file);
my $dir = $file;
$dir =~ s{/[^/]+$}{};
return (0, $text{'systemd_edropinfile'})
	if (-l $dir || !-d $dir || -l $file || !-f $file);
return (1, undef) if (is_readonly_mode());
lock_file($file);
my $ok = unlink_file($file) ? 1 : 0;
my $err = $!;
unlock_file($file);
rmdir($dir) if ($ok);
return $ok ? (1, undef) :
	     (0, "$file: ".($err || $text{'systemd_edropinfile'}));
}

=head2 user_dropin_file(user, unit)

Returns the standard drop-in override file for a user's unit.

=cut
sub user_dropin_file
{
my ($user, $unit) = @_;
my $root = get_user_root($user);
return if (!$root || !valid_unit_name($unit));
return "$root/$unit.d/override.conf";
}

=head2 user_dropin_file_safe(user, file, [must-exist])

Returns 1 if a user drop-in override path is safe to read or write.

=cut
sub user_dropin_file_safe
{
my ($user, $file, $must_exist) = @_;
my $root = get_user_root($user);
return 0 if (!$root || !$file || $file =~ /[\0\r\n]/);
return 0 if (!user_root_safe($user));
my $uinfo = get_user_details($user);
return 0 if (!$uinfo);
return 0 if ($file !~ /^\Q$root\E\/([^\/]+)\.d\/override\.conf$/);
return 0 if (!valid_unit_name($1));
my $dir = "$root/$1.d";
return 0 if (!user_unit_dir_safe($uinfo, $dir));
return 0 if (-l $file);
return $must_exist ? -f $file : (!-e $file || -f $file);
}

=head2 read_user_dropin_file(user, unit)

Reads the standard user drop-in override file as the owning Unix user.

=cut
sub read_user_dropin_file
{
my ($user, $unit) = @_;
my $file = user_dropin_file($user, $unit);
return if (!$file || !user_dropin_file_safe($user, $file, 1));
return eval_as_unix_user($user, sub {
	return read_file_contents($file);
	});
}

=head2 write_user_dropin_file(user, unit, data)

Writes the standard user drop-in override file as the owning Unix user.

=cut
sub write_user_dropin_file
{
my ($user, $unit, $data) = @_;
my $file = user_dropin_file($user, $unit);
return (0, $text{'systemd_euserunitfile'})
	if (!$file || !user_dropin_file_safe($user, $file, 0));
my $dir = $file;
$dir =~ s{/[^/]+$}{};
my $uinfo = get_user_details($user);
return (0, $text{'systemd_euserunitfile'})
	if (!$uinfo || !user_unit_dir_safe($uinfo, $dir));
return (1, undef) if (is_readonly_mode());
my $ok = eval {
	# Directory creation and writing both happen as the owner, avoiding root
	# writes through user-controlled home-directory paths.
	eval_as_unix_user($user, sub {
		if (!-d $dir) {
			make_dir($dir, oct("0755"), 0) || die "$dir: $!";
			}
		die $text{'systemd_euserunitfile'}
			if (-l $dir || !-d $dir || -l $file ||
			    (-e $file && !-f $file));
		my $fh = gensym();
		open_lock_tempfile($fh, ">$file");
		print_tempfile($fh, defined($data) ? $data : "");
		close_tempfile($fh);
		set_ownership_permissions(undef, undef, oct("0644"), $file);
		});
	1;
	};
my $err = $@;
$err =~ s/\s+at\s+(\/\S+)\s+line\s+(\d+)\.?// if ($err);
return $ok ? (1, undef) : (0, $err || $text{'systemd_euserunitfile'});
}

=head2 delete_user_dropin_file(user, unit)

Deletes a user unit drop-in override as the owning Unix user.

=cut
sub delete_user_dropin_file
{
my ($user, $unit) = @_;
my $file = user_dropin_file($user, $unit);
return (0, $text{'systemd_euserunitfile'})
	if (!$file || !user_dropin_file_safe($user, $file, 1));
my $dir = $file;
$dir =~ s{/[^/]+$}{};
return (1, undef) if (is_readonly_mode());
my $ok = eval {
	# Re-check immediately before deletion in the user's context.
	eval_as_unix_user($user, sub {
		die $text{'systemd_euserunitfile'}
			if (-l $dir || !-d $dir || -l $file || !-f $file);
		lock_file($file);
		my $deleted = unlink_file($file) ? 1 : 0;
		my $err = $!;
		unlock_file($file);
		die "$file: $err" if (!$deleted);
		rmdir($dir);
		});
	1;
	};
my $err = $@;
$err =~ s/\s+at\s+(\/\S+)\s+line\s+(\d+)\.?// if ($err);
return $ok ? (1, undef) : (0, $err || $text{'systemd_euserunitfile'});
}

=head2 get_system_dropin_roots()

Returns local system unit directories that can contain administrator drop-ins.

=cut
sub get_system_dropin_roots
{
my @roots;
my %seen;
foreach my $root (get_system_unit_file_root_candidates()) {
	next if (!local_unit_file_root($root));
	next if (!-d $root || -l $root);
	my $real = eval { abs_path($root) };
	next if (!$real || $real ne $root || $seen{$real}++);
	push(@roots, $root);
	}
return @roots;
}

=head2 valid_dropin_config_file_name(name)

Returns 1 if a drop-in config file basename is safe to list.

=cut
sub valid_dropin_config_file_name
{
my ($name) = @_;
return 0 if (!$name || $name =~ /[\0\r\n\/]/ || $name =~ /^\./);
return $name =~ /^[a-z0-9\.\_\-\@:]+\.conf$/i ? 1 : 0;
}

=head2 system_dropin_config_file_safe(file, [must-exist])

Returns 1 if a system drop-in config file is a regular file below a local
systemd unit drop-in directory.

=cut
sub system_dropin_config_file_safe
{
my ($file, $must_exist) = @_;
return 0 if (!$file || $file =~ /[\0\r\n]/ || -l $file);
foreach my $root (get_system_dropin_roots()) {
	if ($file =~ /^\Q$root\E\/([^\/]+)\.d\/([^\/]+)$/) {
		my ($unit, $conf) = ($1, $2);
		return 0 if (!valid_unit_file_name($unit) ||
			     !valid_dropin_config_file_name($conf));
		my $dir = "$root/$unit.d";
		return 0 if (-l $dir || !-d $dir);
		return $must_exist ? -f $file : (!-e $file || -f $file);
		}
	}
return 0;
}

=head2 system_dropin_config_file_info(file)

Returns a descriptor for a safe system drop-in config file.

=cut
sub system_dropin_config_file_info
{
my ($file) = @_;
return if (!system_dropin_config_file_safe($file, 1));
foreach my $root (get_system_dropin_roots()) {
	if ($file =~ /^\Q$root\E\/([^\/]+)\.d\/([^\/]+)$/) {
		my ($unit, $conf) = ($1, $2);
		return { 'scope' => 'system',
			 'unit' => $unit,
			 'file' => $file,
			 'name' => $conf,
			 'standard' => $conf eq 'override.conf' &&
				valid_unit_name($unit) ? 1 : 0 };
		}
	}
return;
}

=head2 read_system_dropin_config_file(file)

Reads a safe existing system drop-in config file.

=cut
sub read_system_dropin_config_file
{
my ($file) = @_;
return if (!system_dropin_config_file_safe($file, 1));
lock_file($file);
my $data = read_file_contents($file);
unlock_file($file);
return $data;
}

=head2 write_system_dropin_config_file(file, data)

Writes a safe existing system drop-in config file.

=cut
sub write_system_dropin_config_file
{
my ($file, $data) = @_;
return (0, $text{'systemd_edropinfile'})
	if (!system_dropin_config_file_safe($file, 1));
return (1, undef) if (is_readonly_mode());
lock_file($file);
my $fh = gensym();
open_tempfile($fh, ">$file");
print_tempfile($fh, defined($data) ? $data : "");
close_tempfile($fh);
unlock_file($file);
return (1, undef);
}

=head2 user_dropin_config_file_safe(user, file, [must-exist])

Returns 1 if a user drop-in config file is a regular file below the selected
user's systemd unit config directory.

=cut
sub user_dropin_config_file_safe
{
my ($user, $file, $must_exist) = @_;
my $root = get_user_root($user);
return 0 if (!$root || !$file || $file =~ /[\0\r\n]/);
return 0 if (!user_root_safe($user));
my $uinfo = get_user_details($user);
return 0 if (!$uinfo);
return 0 if ($file !~ /^\Q$root\E\/([^\/]+)\.d\/([^\/]+)$/);
my ($unit, $conf) = ($1, $2);
return 0 if (!valid_unit_file_name($unit) ||
	     !valid_dropin_config_file_name($conf));
my $dir = "$root/$unit.d";
return 0 if (!user_unit_dir_safe($uinfo, $dir) || -l $file);
return $must_exist ? -f $file : (!-e $file || -f $file);
}

=head2 user_dropin_config_file_info(user, file)

Returns a descriptor for a safe user drop-in config file.

=cut
sub user_dropin_config_file_info
{
my ($user, $file) = @_;
return if (!user_dropin_config_file_safe($user, $file, 1));
my $root = get_user_root($user);
return if (!$root || $file !~ /^\Q$root\E\/([^\/]+)\.d\/([^\/]+)$/);
my ($unit, $conf) = ($1, $2);
return { 'scope' => 'user',
	 'user' => $user,
	 'unit' => $unit,
	 'file' => $file,
	 'name' => $conf,
	 'standard' => $conf eq 'override.conf' &&
		valid_unit_name($unit) ? 1 : 0 };
}

=head2 read_user_dropin_config_file(user, file)

Reads a safe existing user drop-in config file as the owning Unix user.

=cut
sub read_user_dropin_config_file
{
my ($user, $file) = @_;
return if (!user_dropin_config_file_safe($user, $file, 1));
return eval_as_unix_user($user, sub {
	return read_file_contents($file);
	});
}

=head2 write_user_dropin_config_file(user, file, data)

Writes a safe existing user drop-in config file as the owning Unix user.

=cut
sub write_user_dropin_config_file
{
my ($user, $file, $data) = @_;
return (0, $text{'systemd_edropinfile'})
	if (!user_dropin_config_file_safe($user, $file, 1));
return (1, undef) if (is_readonly_mode());
my $ok = eval {
	eval_as_unix_user($user, sub {
		die $text{'systemd_edropinfile'}
			if (!user_dropin_config_file_safe($user, $file, 1));
		my $fh = gensym();
		open_lock_tempfile($fh, ">$file");
		print_tempfile($fh, defined($data) ? $data : "");
		close_tempfile($fh);
		set_ownership_permissions(undef, undef, oct("0644"), $file);
		});
	1;
	};
my $err = $@;
$err =~ s/\s+at\s+(\/\S+)\s+line\s+(\d+)\.?// if ($err);
return $ok ? (1, undef) : (0, $err || $text{'systemd_edropinfile'});
}

=head2 list_system_dropin_override_files()

Returns safe local system drop-in config files as descriptors.

=cut
sub list_system_dropin_override_files
{
my %seen;
foreach my $root (get_system_dropin_roots()) {
	opendir(my $root_dh, $root) || next;
	foreach my $entry (readdir($root_dh)) {
		next if ($entry !~ /^(.+)\.d$/);
		my $unit = $1;
		next if (!valid_unit_file_name($unit));
		my $dir = "$root/$entry";
		next if (-l $dir || !-d $dir);
		opendir(my $dropin_dh, $dir) || next;
		foreach my $conf (readdir($dropin_dh)) {
			next if (!valid_dropin_config_file_name($conf));
			my $file = "$dir/$conf";
			next if (!system_dropin_config_file_safe($file, 1));
			$seen{$file} = {
				'scope' => 'system',
				'unit' => $unit,
				'file' => $file,
				'name' => $conf,
				'standard' => $conf eq 'override.conf' &&
					valid_unit_name($unit) ? 1 : 0,
				};
			}
		closedir($dropin_dh);
		}
	closedir($root_dh);
	}
my @files = sort { $a->{'unit'} cmp $b->{'unit'} ||
		   $a->{'file'} cmp $b->{'file'} } values(%seen);
return @files;
}

=head2 list_user_dropin_override_files(user)

Returns safe drop-in config files for one user's systemd manager.

=cut
sub list_user_dropin_override_files
{
my ($user) = @_;
my $root = get_user_root($user);
return ( ) if (!$root || !user_root_safe($user) || !-d $root || -l $root);
my @candidates = eval_as_unix_user($user, sub {
	my @rv;
	opendir(my $root_dh, $root) || return ( );
	foreach my $entry (readdir($root_dh)) {
		next if ($entry !~ /^(.+)\.d$/);
		my $unit = $1;
		next if (!valid_unit_file_name($unit));
		my $dir = "$root/$entry";
		next if (-l $dir || !-d $dir);
		opendir(my $dropin_dh, $dir) || next;
		foreach my $conf (readdir($dropin_dh)) {
			next if (!valid_dropin_config_file_name($conf));
			push(@rv, [ $unit, $conf, "$dir/$conf" ]);
			}
		closedir($dropin_dh);
		}
	closedir($root_dh);
	return @rv;
	});
my %seen;
foreach my $candidate (@candidates) {
	next if (!$candidate || ref($candidate) ne 'ARRAY');
	my ($unit, $conf, $file) = @$candidate;
	next if (!user_dropin_config_file_safe($user, $file, 1));
	$seen{$file} = {
		'scope' => 'user',
		'user' => $user,
		'unit' => $unit,
		'file' => $file,
		'name' => $conf,
		'standard' => $conf eq 'override.conf' &&
			valid_unit_name($unit) ? 1 : 0,
		};
	}
my @files = sort { $a->{'unit'} cmp $b->{'unit'} ||
		   $a->{'file'} cmp $b->{'file'} } values(%seen);
return @files;
}

=head2 list_all_user_dropin_override_files()

Returns safe local user-unit drop-in config files from users' home
directories.

=cut
sub list_all_user_dropin_override_files
{
return ( ) if (!tab_visible('user'));
my @rv;
setpwent();
while(my @uinfo = getpwent()) {
	my ($user, $home) = ($uinfo[0], $uinfo[7]);
	next if (!$user || $home !~ /^\//);
	push(@rv, list_user_dropin_override_files($user));
	}
endpwent();
my @files = sort { ($a->{'user'} || "") cmp ($b->{'user'} || "") ||
		   $a->{'unit'} cmp $b->{'unit'} ||
		   $a->{'file'} cmp $b->{'file'} } @rv;
return @files;
}

=head2 dropin_template(override-file, base-file, base-data)

Returns the initial comment-only contents for a new drop-in override.

=cut
sub dropin_template
{
my ($override_file, $base_file, $base_data) = @_;
$override_file = "" if (!defined($override_file));
$base_file = "" if (!defined($base_file));
$base_data = "" if (!defined($base_data));
my $data = "### Editing $override_file\n";
$data .= "### Anything between here and the comment below will become ".
	 "the new contents of the file\n\n\n\n";
$data .= "### Lines below this comment will be discarded\n\n";
$data .= "### $base_file\n";
foreach my $line (split(/\n/, $base_data, -1)) {
	$data .= "# $line\n";
	}
return $data;
}

=head2 dropin_effective_data(data)

Returns only the editable portion of a C<systemctl edit>-style drop-in file.

=cut
sub dropin_effective_data
{
my ($data) = @_;
$data = "" if (!defined($data));
$data =~ s/^### Lines below this comment will be discarded\s*\n.*\z//ms;
return $data;
}

=head2 delete_user_unit_file(user, file)

Deletes a user unit file as the owning Unix user after path validation, so a
symlinked path component cannot trick root into removing files outside the
user's systemd unit config directory.

=cut
sub delete_user_unit_file
{
my ($user, $file) = @_;
return 0 if (!user_unit_file_safe($user, $file, 0));
return 1 if (is_readonly_mode());
return eval_as_unix_user($user, sub {
	# Re-check in the user's context immediately before unlinking.
	return 1 if (!-e $file && !-l $file);
	return 0 if (-l $file || !-f $file);
	return unlink_file($file) ? 1 : 0;
	});
}

=head2 make_user_root(user)

Creates the base directory for a user's systemd unit config files.

=cut
sub make_user_root
{
my ($user) = @_;
my $uinfo = get_user_details($user);
return if (!$uinfo);
my @dirs = ( $uinfo->{'home'}."/.config",
	     $uinfo->{'home'}."/.config/systemd",
	     $uinfo->{'home'}."/.config/systemd/user" );
foreach my $dir (@dirs) {
	return if (-l $dir || (-e $dir && !-d $dir));
	}
return $dirs[-1] if (is_readonly_mode() && user_root_safe($user));
my $ok = eval {
	# Create the directory tree as the owning user, then validate it again in
	# root context before returning the path.
	eval_as_unix_user($uinfo->{'user'}, sub {
		foreach my $dir (@dirs) {
			return 0 if (-l $dir || (-e $dir && !-d $dir));
			if (!-d $dir) {
				make_dir($dir, oct("0755"), 0) || return 0;
				}
			}
		return 1;
		});
	};
return if (!$ok || !user_root_safe($user));
return $dirs[-1];
}

=head2 user_manager_command(user, command, ...)

Returns a command line that runs a command inside the user's systemd context.

=cut
sub user_manager_command
{
my ($user, @cmd) = @_;
my $uinfo = get_user_details($user);
return if (!$uinfo);
my $runtime = "/run/user/".$uinfo->{'uid'};

# systemctl --user needs the user's home, runtime directory and bus address
# even though the CGI is running from Webmin's root-owned environment.
my $env = "HOME=".quotemeta($uinfo->{'home'})." ".
	  "XDG_RUNTIME_DIR=".quotemeta($runtime)." ".
	  "DBUS_SESSION_BUS_ADDRESS=".quotemeta("unix:path=".$runtime."/bus");
return command_as_user($uinfo->{'user'}, 0, $env." ".join(" ", @cmd));
}

=head2 user_systemctl_command(user, arg, ...)

Returns a quoted systemctl --user command line for some user.

=cut
sub user_systemctl_command
{
my ($user, @args) = @_;
my $systemctl = has_command("systemctl") || "systemctl";

# Quote each argument before wrapping the command with command_as_user.
return user_manager_command($user, quotemeta($systemctl), "--user",
			     map { quotemeta($_) } @args);
}

=head2 run_user_systemctl(user, arg, ...)

Runs systemctl --user for some user, returning an OK flag and output.

=cut
sub run_user_systemctl
{
my ($user, @args) = @_;
my $cmd = user_systemctl_command($user, @args);
return (0, $text{'systemd_euser'}) if (!$cmd);
my $out = backquote_logged($cmd." 2>&1 </dev/null");
return (!$?, $out);
}

=head2 reload_user_manager(user)

Tells a user's systemd manager to re-read its unit files.

=cut
sub reload_user_manager
{
my ($user) = @_;
return run_user_systemctl($user, "daemon-reload");
}

=head2 set_user_linger(user, enabled)

Enables or disables lingering for a user.

=cut
sub set_user_linger
{
my ($user, $enabled) = @_;
my $uinfo = get_user_details($user);
return (0, $text{'systemd_euser'}) if (!$uinfo);
my $loginctl = has_command("loginctl");
return (0, $text{'systemd_eloginctl'}) if (!$loginctl);
my $cmd = quotemeta($loginctl)." ".
	  ($enabled ? "enable-linger" : "disable-linger")." ".
	  quotemeta($uinfo->{'user'});
my $out = backquote_logged($cmd." 2>&1 </dev/null");
return (!$?, $out);
}

=head2 user_linger_enabled(user)

Returns 1 if lingering is enabled for some user, 0 if not.

=cut
sub user_linger_enabled
{
my ($user) = @_;
my $uinfo = get_user_details($user);
return 0 if (!$uinfo);
return 1 if (-e "/var/lib/systemd/linger/".$uinfo->{'user'});
my $loginctl = has_command("loginctl");
return 0 if (!$loginctl);
my $out = backquote_command(quotemeta($loginctl)." show-user ".
			     quotemeta($uinfo->{'user'}).
			     " -p Linger 2>/dev/null");
return $out =~ /^Linger=yes/m ? 1 : 0;
}

=head2 start_user_manager(user)

Starts a user's systemd manager through the system manager.

=cut
sub start_user_manager
{
my ($user) = @_;
my $uinfo = get_user_details($user);
return (0, $text{'systemd_euser'}) if (!$uinfo);
my $systemctl = has_command("systemctl") || "systemctl";

# User managers are addressed by UID as user@UID.service.
my $unit = "user\@".$uinfo->{'uid'}.".service";
my $out = backquote_logged(quotemeta($systemctl)." start ".
			    quotemeta($unit)." 2>&1 </dev/null");
return (!$?, $out);
}

=head2 user_file_description(user, file)

Returns the Description= line from a systemd unit file.

=cut
sub user_file_description
{
my ($user, $file, $unit) = @_;
my $data = read_user_unit_file($user, $file);
return if (!defined($data));
my $desc = unit_data_description($data);
if ($unit && dropin_exists(1, $user, $unit)) {
	my $dropin = read_user_dropin_file($user, $unit);
	my $dropin_desc = unit_data_description($dropin);
	$desc = $dropin_desc if (defined($dropin_desc));
	}
return $desc;
}

=head2 unit_data_description(data)

Returns the last Description= value from some unit-file contents.

=cut
sub unit_data_description
{
my ($data) = @_;
return if (!defined($data));
my $desc;
foreach my $line (split(/\r?\n/, $data)) {
	$desc = $1 if ($line =~ /^Description=(.*)$/);
	}
return $desc;
}

=head2 user_file_enabled(user, name)

Returns 1 if some user unit file is enabled by a *.wants symlink. The lookup
runs as the owning Unix user so that a symlinked path component cannot make
root probe files outside the user's systemd unit config directory.

=cut
sub user_file_enabled
{
my ($user, $name) = @_;
my $root = get_user_root($user);
return 0 if (!$root || !user_root_safe($user));
return eval_as_unix_user($user, sub {
	return 0 if (!-d $root);
	opendir(my $dh, $root) || return 0;
	my @dirs = grep { /\.wants$/ && -d "$root/$_" } readdir($dh);
	closedir($dh);
	foreach my $dir (@dirs) {
		return 1 if (-e "$root/$dir/$name");
		}
	return 0;
	});
}

=head2 list_user_units(user)

Returns locally editable systemd user units for some user.

=cut
sub list_user_units
{
my ($user) = @_;
my $uinfo = get_user_details($user);
return ( ) if (!$uinfo);
my $units_piped = join('|', get_unit_types());
my $list_types = join(" ", map { "-t ".quotemeta($_) }
			   get_list_unit_types());
my @units;
my $root = get_user_root($user);
my %local_files;

# Read local user unit files even if the user's manager is not running.
if ($root && user_root_safe($user)) {
	my @local_units = eval_as_unix_user($user, sub {
		return ( ) if (!-d $root);
		opendir(my $systemduserunits, $root) || return ( );
		my @rv;
		foreach my $unit (readdir($systemduserunits)) {
			next if ($unit =~ /^\./ || $unit =~ /\.wants$/ ||
				 $unit !~ /\.($units_piped)$/ || -d "$root/$unit");
			push(@rv, $unit);
			}
		closedir($systemduserunits);
		return @rv;
		});
	foreach my $unit (@local_units) {
		next if (!user_unit_file_safe($user, "$root/$unit", 1));
		push(@units, $unit);
		$local_files{$unit} = "$root/$unit";
		}
	}

# Add active or loaded units from the user's manager.
my $out = backquote_command(
	user_systemctl_command($user, "list-units", "--full",
					"--all", split(/\s+/, $list_types),
					"--no-legend")." 2>/dev/null");
foreach my $l (split(/\r?\n/, $out)) {
	$l =~ s/^[^a-z0-9\-\_\.]+//i;
	my ($unit, $loaded) = split(/\s+/, $l, 3);
	push(@units, $unit)
		if ($unit && $unit ne "UNIT" && $loaded eq "loaded");
	}

# Also add units from list-unit-files that may not be loaded.
$out = backquote_command(
	user_systemctl_command($user, "list-unit-files",
					split(/\s+/, $list_types),
					"--no-legend").
	" 2>/dev/null");
foreach my $l (split(/\r?\n/, $out)) {
	if ($l =~ /^(\S+)\s+/) {
		push(@units, $1);
		}
	}

@units = grep { !/\@$/ && !/\@\.($units_piped)$/ } unique(@units);

# Dump state in batches, keeping command lines short and parsing the property
# format into one hash per unit.
my @show_units = @units;
my %info;
while(@show_units) {
	my @args;
	while(@args < 100 && @show_units) {
		push(@args, shift(@show_units));
		}
	my $cmd = user_systemctl_command(
		$user, "show",
		"--property=Id,Description,UnitFileState,ActiveState,SubState,ExecStart,ExecStop,ExecReload,ExecMainPID,FragmentPath,DropInPaths",
		@args);
	my $show = backquote_command($cmd." 2>/dev/null");
	my @lines = split(/\r?\n/, $show);
	my $curr;
	my @shown;

	# systemctl show separates units with blank lines.
	if (@lines) {
		$curr = { };
		push(@shown, $curr);
		}
	foreach my $l (@lines) {
		if ($l eq "") {
			$curr = { };
			push(@shown, $curr);
			}
		else {
			my ($n, $v) = split(/=/, $l, 2);
			$curr->{$n} = $v;
			}
		}
	foreach my $u (@shown) {
		$info{$u->{'Id'}} = $u if ($u->{'Id'});
		}
	}

my @rv;
my %done;
foreach my $name (sort keys %info) {
	my $i = $info{$name};
	my $file = $i->{'FragmentPath'} || $local_files{$name};

	# Only expose local user-owned files.  Vendor user units are not editable
	# here because deletion/editing would not affect their source.
	next if ($root && (!$file || $file !~ /^\Q$root\E\//));
	next if (!user_unit_file_safe($user, $file, 1));
	my $desc = user_file_description($user, $file, $name);
	$desc = $i->{'Description'} if (!defined($desc));
	next if (defined($desc) && $desc =~ /^LSB:\s/);
	push(@rv, { 'name' => $name,
		    'desc' => defined($desc) ? $desc : "",
		    'unitstate' => $i->{'UnitFileState'},
		    'runtime' => $i->{'ActiveState'},
		    'substate' => $i->{'SubState'},
		    'boot' => $i->{'UnitFileState'} =~ /^enabled/ ? 1 :
			      $i->{'UnitFileState'} eq 'static' ? 2 :
			      $i->{'UnitFileState'} eq 'masked' ? -1 : 0,
		    'status' => $i->{'ActiveState'} eq 'active' ? 1 : 0,
		    'start' => $i->{'ExecStart'},
		    'stop' => $i->{'ExecStop'},
		    'reload' => $i->{'ExecReload'},
		    'pid' => $i->{'ExecMainPID'},
		    'file' => $file,
		    'user' => $uinfo->{'user'},
		  });
	$done{$name}++;
	}

foreach my $name (sort keys %local_files) {
	next if ($done{$name});

	# Include local files even when the user manager is offline and cannot
	# report them through systemctl show.
	my $enabled = user_file_enabled($user, $name);
	push(@rv, { 'name' => $name,
		    'desc' => user_file_description(
			$user, $local_files{$name}, $name) || "",
		    'unitstate' => $enabled ? 'enabled' : 'disabled',
		    'runtime' => undef,
		    'boot' => $enabled,
		    'status' => undef,
		    'file' => $local_files{$name},
		    'user' => $uinfo->{'user'},
		  });
	}

	my @sorted = sort { $a->{'name'} cmp $b->{'name'} } @rv;
	return @sorted;
	}

=head2 list_all_user_units()

Returns all locally editable systemd user units from users' home directories.

=cut
sub list_all_user_units
{
return ( ) if (!tab_visible('user'));
my @rv;
setpwent();
while(my @uinfo = getpwent()) {
	my ($user, $home) = ($uinfo[0], $uinfo[7]);

	# Only users with absolute home directories can have user unit roots.
	next if (!$user || $home !~ /^\//);
	my $root = $home."/.config/systemd/user";
	next if (!user_root_safe($user) || !-d $root);
	push(@rv, list_user_units($user));
	}
endpwent();
my @sorted = sort { $a->{'user'} cmp $b->{'user'} ||
		    $a->{'name'} cmp $b->{'name'} } @rv;
return @sorted;
}

=head2 get_system_unit_file_roots()

Returns existing system and vendor directories that can contain unit files.

=cut
sub get_system_unit_file_roots
{
my @roots;
my %seen;
foreach my $root (get_system_unit_file_root_candidates()) {
	next if (!$config{'manual_vendor_units'} && !local_unit_file_root($root));
	next if (!-d $root || -l $root);
	my $real = eval { abs_path($root) };
	next if (!$real || $real ne $root || $seen{$real}++);
	push(@roots, $root);
	}
return @roots;
}

=head2 local_unit_file_root(root)

Returns true if a system unit root is the local administrator directory.

=cut
sub local_unit_file_root
{
my ($root) = @_;
return $root eq "/etc/systemd/system";
}

=head2 get_system_unit_file_root_candidates()

Returns possible systemd unit directories before existence and symlink checks.

=cut
sub get_system_unit_file_root_candidates
{
return ("/etc/systemd/system",
	"/usr/lib/systemd/system",
	"/lib/systemd/system");
}

=head2 manual_system_unit_file_safe(file)

Returns 1 if a system unit file is a regular direct child of a known systemd
unit directory and has a recognized unit suffix.

=cut
sub manual_system_unit_file_safe
{
my ($file) = @_;
return 0 if (!$file || $file =~ /[\0\r\n]/ || -l $file || !-f $file);
foreach my $root (get_system_unit_file_roots()) {
	if ($file =~ /^\Q$root\E\/([^\/]+)$/ &&
	    valid_unit_file_name($1)) {
		return 1;
		}
	}
return 0;
}

=head2 list_manual_unit_files()

Returns system and local user unit files that the raw editor may open.

=cut
sub list_manual_unit_files
{
my %files;

# Scan local and vendor unit directories directly, including unit types hidden
# from the main management tabs.
foreach my $root (get_system_unit_file_roots()) {
	opendir(my $units_dh, $root) || next;
	foreach my $name (readdir($units_dh)) {
		my $file = "$root/$name";
		next if (!manual_system_unit_file_safe($file));
		$files{$file} = { 'file' => $file,
				  'name' => $name,
				  'scope' => 'system' };
		}
	closedir($units_dh);
	}

# Add any fragment paths reported by systemctl in case a unit lives in a
# distro-specific root not covered above.
my @system_units = list_units();
foreach my $u (@system_units) {
	my $file = $u->{'file'};
	next if (!manual_system_unit_file_safe($file));
	$files{$file} ||= { 'file' => $file,
			    'name' => $u->{'name'},
			    'scope' => 'system' };
	}

# System drop-ins are editable from the raw editor when their base unit is a
# known file-backed unit.  This includes package or module snippets such as
# 00-virtualmin.conf, not only the module's default override.conf.
my %system_units = map { $_->{'name'}, $_ } @system_units;
foreach my $dropin (list_system_dropin_override_files()) {
	my $u = $system_units{$dropin->{'unit'}};
	next if (!$u || !manual_system_unit_file_safe($u->{'file'}));
	$files{$dropin->{'file'}} = { %$dropin,
				      'kind' => 'dropin',
				      'name' => $dropin->{'unit'},
				      'dropin' => $dropin->{'name'},
				      'unitfile' => $u->{'file'},
				      'unitstate' => $u->{'unitstate'} };
	}

# User unit files remain constrained to local home-owned unit roots.
my @user_units = list_all_user_units();
foreach my $u (@user_units) {
	my $file = $u->{'file'};
	next if (!$u->{'user'} ||
		 !user_unit_file_safe($u->{'user'}, $file, 1));
	$files{$file} = { 'file' => $file,
			  'name' => $u->{'name'},
			  'scope' => 'user',
			  'user' => $u->{'user'} };
	}

# User drop-ins are constrained to discovered user units owned by the same
# Unix account and are written as that user.
my %user_units = map { $_->{'user'}."\t".$_->{'name'}, $_ } @user_units;
foreach my $dropin (list_all_user_dropin_override_files()) {
	my $u = $user_units{$dropin->{'user'}."\t".$dropin->{'unit'}};
	next if (!$u ||
		 !user_unit_file_safe($dropin->{'user'}, $u->{'file'}, 1));
	$files{$dropin->{'file'}} = { %$dropin,
				      'kind' => 'dropin',
				      'name' => $dropin->{'unit'},
				      'dropin' => $dropin->{'name'},
				      'unitfile' => $u->{'file'},
				      'unitstate' => $u->{'unitstate'} };
	}

	my @files = sort { ($a->{'scope'} || "") cmp ($b->{'scope'} || "") ||
			   ($a->{'user'} || "") cmp ($b->{'user'} || "") ||
			   $a->{'file'} cmp $b->{'file'} } values(%files);
	return @files;
	}

=head2 manual_unit_file(file)

Returns the manual-edit descriptor for an allowed systemd unit file.

=cut
sub manual_unit_file
{
my ($file) = @_;
return if (!$file);
foreach my $info (list_manual_unit_files()) {
	return $info if ($info->{'file'} eq $file);
	}
return;
}

=head2 read_manual_unit_file(info)

Reads a system or user unit file selected through C<list_manual_unit_files>.

=cut
sub read_manual_unit_file
{
my ($info) = @_;
return if (!$info || !$info->{'file'});
if ($info->{'kind'} && $info->{'kind'} eq 'dropin') {
	return $info->{'scope'} eq 'user' ?
		read_user_dropin_config_file($info->{'user'},
					     $info->{'file'}) :
		read_system_dropin_config_file($info->{'file'});
	}
if ($info->{'scope'} eq 'user') {
	return read_user_unit_file($info->{'user'}, $info->{'file'});
	}
return if (!manual_system_unit_file_safe($info->{'file'}));
lock_file($info->{'file'});
my $data = read_file_contents($info->{'file'});
unlock_file($info->{'file'});
return $data;
}

=head2 write_manual_unit_file(info, data)

Writes a system or user unit file selected through C<list_manual_unit_files>.

=cut
sub write_manual_unit_file
{
my ($info, $data) = @_;
return (0, $text{'manual_efile'})
	if (!$info || !$info->{'file'});
$data = "" if (!defined($data));
$data =~ s/\0//g;
$data =~ s/\r//g;
if ($info->{'kind'} && $info->{'kind'} eq 'dropin') {
	return (0, $text{'manual_efile'})
		if (!$info->{'unitfile'});
	my $user_scope = $info->{'scope'} eq 'user' ? 1 : 0;
	my $unit_data;
	if ($user_scope) {
		$unit_data = read_user_unit_file($info->{'user'},
						 $info->{'unitfile'});
		}
	else {
		return (0, $text{'manual_efile'})
			if (!manual_system_unit_file_safe($info->{'unitfile'}));
		$unit_data = read_file_contents($info->{'unitfile'});
		}
	my ($vok, $vout) = verify_dropin_data(
		$info->{'unitfile'}, $unit_data, $data, $user_scope,
		$info->{'unitstate'}, $info->{'user'});
	return (0, $vout) if (!$vok);
	return $user_scope ?
		write_user_dropin_config_file($info->{'user'},
					      $info->{'file'}, $data) :
		write_system_dropin_config_file($info->{'file'}, $data);
	}
my ($vok, $vout) = verify_unit_data($info->{'file'}, $data,
				    $info->{'scope'} eq 'user',
				    $info->{'user'});
return (0, $vout) if (!$vok);
if ($info->{'scope'} eq 'user') {
	return write_user_unit_file($info->{'user'}, $info->{'file'}, $data);
	}
return (0, $text{'manual_efile'})
	if (!manual_system_unit_file_safe($info->{'file'}));
return (1, undef) if (is_readonly_mode());
lock_file($info->{'file'});
my $fh = gensym();
open_tempfile($fh, ">".$info->{'file'});
print_tempfile($fh, $data);
close_tempfile($fh);
unlock_file($info->{'file'});
return (1, undef);
}

=head2 mark_units_changed()

Updates the flag file indicating that manual unit-file edits need reload.

=cut
sub mark_units_changed
{
open_lock_tempfile(my $fh, ">$unit_config_change_flag", 0, 1);
close_tempfile($fh);
}

=head2 mark_daemon_reloaded()

Updates the flag file indicating that systemd has re-read unit files.

=cut
sub mark_daemon_reloaded
{
open_lock_tempfile(my $fh, ">$daemon_reload_time_flag", 0, 1);
close_tempfile($fh);
}

=head2 user_daemon_reload_flag_file(user, type)

Returns the per-user reload flag path for C<changed> or C<reloaded>.

=cut
sub user_daemon_reload_flag_file
{
my ($user, $type) = @_;
return if (!$user || $type !~ /^(changed|reloaded)$/);
my $uinfo = get_user_details($user);
return if (!$uinfo);
return $module_var_directory."/user-daemon-reload-".
       $uinfo->{'uid'}."-".$type;
}

=head2 mark_user_units_changed(user)

Updates the flag file indicating that a user's unit files need reload.

=cut
sub mark_user_units_changed
{
my ($user) = @_;
my $flag = user_daemon_reload_flag_file($user, 'changed');
return if (!$flag);
open_lock_tempfile(my $fh, ">$flag", 0, 1);
close_tempfile($fh);
}

=head2 mark_user_daemon_reloaded(user)

Updates the flag file indicating that a user's manager has re-read unit files.

=cut
sub mark_user_daemon_reloaded
{
my ($user) = @_;
my $flag = user_daemon_reload_flag_file($user, 'reloaded');
return if (!$flag);
open_lock_tempfile(my $fh, ">$flag", 0, 1);
close_tempfile($fh);
}

=head2 needs_daemon_reload()

Returns 1 if unit files were manually edited after the last daemon reload.

=cut
sub needs_daemon_reload
{
my @changed = stat($unit_config_change_flag);
my @reloaded = stat($daemon_reload_time_flag);
return 0 if (!@changed);
return 1 if (!@reloaded);
return $changed[9] > $reloaded[9] ? 1 : 0;
}

=head2 needs_user_daemon_reload(user)

Returns 1 if a user's unit files were edited after that user's last reload.

=cut
sub needs_user_daemon_reload
{
my ($user) = @_;
my $changed_flag = user_daemon_reload_flag_file($user, 'changed');
return 0 if (!$changed_flag);
my @changed = stat($changed_flag);
return 0 if (!@changed);
my $reloaded_flag = user_daemon_reload_flag_file($user, 'reloaded');
my @reloaded = $reloaded_flag ? stat($reloaded_flag) : ( );
return 1 if (!@reloaded);
return $changed[9] > $reloaded[9] ? 1 : 0;
}

=head2 action_reload_user([user])

Returns the user whose manager reload action should be shown, if any.

=cut
sub action_reload_user
{
my ($user) = @_;
$user ||= defined($in{'unituser'}) ? clean_unit_value($in{'unituser'}) : "";
$user ||= defined($in{'user'}) ? clean_unit_value($in{'user'}) : "";
$user ||= systemd_acl_default_user(\%access) || "";
my $uinfo = $user ? get_user_details($user) : undef;
return $uinfo ? $uinfo->{'user'} : undef;
}

=head2 action_links()

Returns HTML for right-side header actions on the systemd index page.

=cut
sub action_links
{
my ($user) = @_;
my @links;
push(@links, ui_link("restart.cgi",
		     ui_tag('b', html_escape($text{'index_reload'}))))
	if (needs_daemon_reload() && systemd_can_reload(\%access));
my $reload_user = action_reload_user($user);
push(@links, ui_link("restart_user.cgi?user=".urlize($reload_user),
		     ui_tag('b', html_escape($text{'index_reload_user'}))))
	if ($reload_user &&
	    needs_user_daemon_reload($reload_user) &&
	    systemd_can_reload_user(\%access, $reload_user));
return join(" &nbsp; ", @links);
}

=head2 start_user_unit(user, name)

Starts a systemd user unit and returns an OK flag and output.

=cut
sub start_user_unit
{
my ($user, $name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my ($ok, $out) = run_user_systemctl($user, "start", $name);
if (!$ok && $out =~ /journalctl/) {
	my ($lok, $lout) = logs_user_unit($user, $name);
	$out .= $lout if ($lout);
	}
return ($ok, $out);
}

=head2 stop_user_unit(user, name)

Stops a systemd user unit.

=cut
sub stop_user_unit
{
my ($user, $name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
return run_user_systemctl($user, "stop", $name);
}

=head2 restart_user_unit(user, name)

Restarts a systemd user unit.

=cut
sub restart_user_unit
{
my ($user, $name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
return run_user_systemctl($user, "restart", $name);
}

=head2 status_user_unit(user, name)

Gets full status output for a systemd user unit.

=cut
sub status_user_unit
{
my ($user, $name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
return run_user_systemctl($user, "--full", "--no-pager",
				  "status", $name);
}

=head2 properties_user_unit(user, name)

Gets systemd property output for a user unit.

=cut
sub properties_user_unit
{
my ($user, $name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
return run_user_systemctl($user, "--full", "--no-pager",
				  "show", $name);
}

=head2 dependencies_user_unit(user, name)

Gets dependency tree output for a systemd user unit.

=cut
sub dependencies_user_unit
{
my ($user, $name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
return run_user_systemctl($user, "--full", "--no-pager",
				  "list-dependencies", $name);
}

=head2 logs_user_unit(user, name)

Gets recent journal logs for a systemd user unit.

=cut
sub logs_user_unit
{
my ($user, $name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $uinfo = get_user_details($user);
return (0, $text{'systemd_euser'}) if (!$uinfo);
my $journalctl = has_command("journalctl");
return (0, $text{'systemd_ejournal'}) if (!$journalctl);
my $boot_arg = $config{'logs_current_boot'} ? " --boot" : "";
my $out = backquote_logged(
	quotemeta($journalctl)." --no-pager ".
	"_UID=".int($uinfo->{'uid'})." ".
	"_SYSTEMD_USER_UNIT=".quotemeta($name).
	" --lines ".int($config{'logs_lines'}).$boot_arg.
	" 2>&1 </dev/null");
return (!$?, $out);
}

=head2 enable_user_unit(user, name)

Enable a systemd user unit.

=cut
sub enable_user_unit
{
my ($user, $name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my ($dok, $dout) = check_user_unit_dirs($user);
return ($dok, $dout) if (!$dok);
my ($ok, $out) = run_user_systemctl($user, "enable", $name);
return ($ok && !startup_change_skipped($out), $out);
}

=head2 disable_user_unit(user, name)

Disable a systemd user unit.

=cut
sub disable_user_unit
{
my ($user, $name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my ($dok, $dout) = check_user_unit_dirs($user);
return ($dok, $dout) if (!$dok);
my ($ok, $out) = run_user_systemctl($user, "disable", $name);
return ($ok && !startup_change_skipped($out), $out);
}

=head2 mask_user_unit(user, name)

Masks a systemd user unit so it cannot be started until unmasked.

=cut
sub mask_user_unit
{
my ($user, $name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my ($dok, $dout) = check_user_unit_dirs($user);
return ($dok, $dout) if (!$dok);
return run_user_systemctl($user, "mask", $name);
}

=head2 unmask_user_unit(user, name)

Unmasks a systemd user unit so it can be started again.

=cut
sub unmask_user_unit
{
my ($user, $name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my ($dok, $dout) = check_user_unit_dirs($user);
return ($dok, $dout) if (!$dok);
return run_user_systemctl($user, "unmask", $name);
}

=head2 create_user_unit(user, name, data)

Creates a user unit from rendered unit-file contents.

=cut
sub create_user_unit
{
my ($user, $name, $data) = @_;
my $uinfo = get_user_details($user);
return (0, $text{'systemd_euser'}) if (!$uinfo);
return (0, $text{'systemd_ename'}) if (!valid_creatable_unit_name($name, 1));
return (0, $text{'systemd_euserunitfile'}) if (!defined($data));
my $root = make_user_root($user);
return (0, $text{'systemd_euserhome'}) if (!$root);
my ($dok, $dout) = check_user_unit_dirs($user);
return ($dok, $dout, 'file') if (!$dok);
my $cfile = $root."/".$name;

# Avoid overwriting files or symlinks already present in the user's unit root.
return (0, $text{'systemd_eclash'}) if (-l $cfile || -e $cfile);

# Verify generated user-unit contents before creating the user-owned file.
my ($vok, $vout) = verify_unit_data($cfile, $data, 1, $user);
return (0, $vout, 'verify') if (!$vok);

# All home-directory writes run as the owning user, preventing symlink races
# from turning user-controlled paths into root file operations.
my ($wok, $wout) = write_user_unit_file($user, $cfile, $data);
return ($wok, $wout, 'file') if (!$wok);
my ($ok, $out) = reload_user_manager($user);
if (!$ok) {
	# Avoid leaving a half-created unit when daemon-reload cannot see it.
	delete_user_unit_file($user, $cfile);
	}
return ($ok, $out, 'command');
}

=head2 delete_user_unit(user, name)

Delete all traces of some systemd user unit.

=cut
sub delete_user_unit
{
my ($user, $name) = @_;
my $root = get_user_root($user);
return (0, $text{'systemd_euser'}) if (!$root);
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $file = $root."/".$name;
user_unit_file_safe($user, $file, 0) ||
	return (0, $text{'systemd_euserunitfile'});
return (0, $text{'systemd_egone'}) if (!-e $file && !-l $file);
delete_user_unit_file($user, $file) ||
	return (0, $text{'systemd_euserunitfile'});
return reload_user_manager($user);
}

=head2 delete_system_unit(name)

Delete all traces of some systemd unit.

=cut
sub delete_system_unit
{
my ($name) = @_;
return (0, $text{'systemd_ename'}) if (!valid_unit_name($name));
my $file = get_unit_root($name)."/".$name;
return (0, $text{'systemd_egone'}) if (!-e $file && !-l $file);
unlink_logged($file);
reload_manager();
return (1, "");
}

=head2 get_unit_types()

Returns all systemd unit types recognized when parsing existing unit names.

=cut
sub get_unit_types
{
return ('target', 'service', 'socket', 'device', 'mount', 'automount',
	'swap', 'path', 'timer', 'snapshot', 'slice', 'scope', 'busname');
}

=head2 get_creatable_unit_types([user-scope])

Returns systemd unit types that can be created as persistent unit files from
this module.  User managers do not get mount, automount or swap units here.

=cut
sub get_creatable_unit_types
{
my ($user_scope) = @_;
return ('service', 'timer', 'socket', 'path', 'target', 'slice')
	if ($user_scope);
return ('service', 'timer', 'socket', 'path', 'target', 'mount',
	'automount', 'swap', 'slice');
}

=head2 get_list_unit_types()

Returns systemd unit types that should be listed by default.

=cut
sub get_list_unit_types
{
return ('service', 'timer', 'socket', 'path', 'target', 'mount',
	'automount', 'swap', 'slice', 'scope', 'device');
}

=head2 get_index_tab_ids()

Returns all tab IDs supported by the systemd index page.

=cut
sub get_index_tab_ids
{
return ('service', 'timer', 'socket', 'path', 'target', 'storage',
	'resources', 'device', 'user');
}

=head2 default_visible_tabs()

Returns the default comma-separated list of index tabs to show.

=cut
sub default_visible_tabs
{
return join(",", get_index_tab_ids());
}

=head2 get_visible_tabs()

Returns the configured visible index tabs, falling back to all known tabs.

=cut
sub get_visible_tabs
{
my %valid = map { $_, 1 } get_index_tab_ids();
my @tabs = grep { $valid{$_} } split(/\s*,\s*/, $config{'visible_tabs'});
return @tabs ? @tabs : get_index_tab_ids();
}

=head2 boot_state_changeable(unit-file-state, [unit-name])

Returns 1 if the unit file state can be managed with systemctl enable/disable.

=cut
sub boot_state_changeable
{
my ($state, $name) = @_;
return 0 if (!defined($state) || $state eq "");
return 0 if (defined($name) && $name =~ /\.(scope|device)$/i);
$state = lc($state);
return $state =~ /^(enabled|enabled-runtime|disabled|indirect|
		    linked|linked-runtime)$/x ? 1 : 0;
}

=head2 unit_startable(name)

Returns 1 if systemctl start is a meaningful runtime action for the unit.

=cut
sub unit_startable
{
my ($name) = @_;
my $type = get_unit_type_from_name($name);
return 0 if (defined($type) && ($type eq 'scope' || $type eq 'device'));
return 1;
}

=head2 unit_restartable(name)

Returns 1 if systemctl restart is a meaningful runtime action for the unit.

=cut
sub unit_restartable
{
my ($name) = @_;
return unit_startable($name);
}

=head2 unit_file_editable(&unit)

Returns 1 if the unit record points to a persistent unit file that can be
edited directly. Runtime-generated units should be inspected or overridden,
not overwritten in place.

=cut
sub unit_file_editable
{
my ($unit) = @_;
return 0 if (!$unit || !$unit->{'file'});
return 0 if (defined($unit->{'name'}) && $unit->{'name'} =~ /\.scope$/i);
my $state = defined($unit->{'unitstate'}) ? lc($unit->{'unitstate'}) : "";
return 0 if ($state eq 'transient' || $state eq 'generated');
return 0 if ($unit->{'file'} =~ m{/systemd/(transient|generator)/});
return 1;
}

=head2 unit_visible_on_index(&unit)

Returns 1 if a unit should be included on index tabs, honoring the option to
hide generated and transient runtime units.

=cut
sub unit_visible_on_index
{
my ($unit) = @_;
return 1 if ($config{'show_runtime_units'});
return 0 if (!$unit);
my $state = defined($unit->{'unitstate'}) ? lc($unit->{'unitstate'}) : "";
return 0 if ($state eq 'transient' || $state eq 'generated');
return 0 if (defined($unit->{'file'}) &&
	     $unit->{'file'} =~ m{/systemd/(transient|generator)/});
return 1;
}

=head2 tab_visible(tab-id)

Returns true if the given index tab should be shown.

=cut
sub tab_visible
{
my ($tab) = @_;
return indexof($tab, get_visible_tabs()) >= 0;
}

=head2 get_unit_type_from_name(name)

Returns the systemd unit type suffix from a full unit name, such as service or
timer, if it is a known unit type.

=cut
sub get_unit_type_from_name
{
my ($name) = @_;
return if (!defined($name));
my $units_piped = join('|', map { quotemeta } get_unit_types());
return lc($1) if ($name =~ /\.($units_piped)$/i);
return;
}

=head2 index_url([unit-name], [user-scope], [user])

Returns the module index URL with the correct systemd tab selected when
the unit type or user scope is known.

=cut
sub index_url
{
my ($name, $user_scope, $user) = @_;
my @args;
if ($user_scope) {
	push(@args, "mode=user");
	if ($user) {
		push(@args, "scope=user");
		push(@args, "unituser=".urlize($user));
		}
	}
else {
	my $type = get_unit_type_from_name($name);
	my %group_mode = ( 'mount' => 'storage',
			   'automount' => 'storage',
			   'swap' => 'storage',
			   'slice' => 'resources',
			   'scope' => 'resources',
			   'device' => 'device' );
	my %list_types = map { $_, 1 } get_list_unit_types();
	if ($type && $list_types{$type}) {
		push(@args, "mode=".urlize($group_mode{$type} || $type));
		}
	}
return "index.cgi".(@args ? "?".join("&", @args) : "");
}

=head2 get_unit_section(type)

Returns the type-specific section name for a systemd unit type.

=cut
sub get_unit_section
{
my ($type) = @_;
my %sections = ( 'service' => 'Service',
		 'timer' => 'Timer',
		 'socket' => 'Socket',
		 'path' => 'Path',
		 'target' => 'Target',
		 'mount' => 'Mount',
		 'automount' => 'Automount',
		 'swap' => 'Swap',
		 'slice' => 'Slice' );
return $sections{$type};
}

=head2 get_default_install_target(type, [user-scope])

Returns the default WantedBy target for a new systemd unit.

=cut
sub get_default_install_target
{
my ($type, $user_scope) = @_;
my %targets = ( 'service' => $user_scope ? 'default.target' : 'multi-user.target',
		'timer' => 'timers.target',
		'socket' => 'sockets.target',
		'path' => 'paths.target',
		'target' => $user_scope ? 'default.target' : 'multi-user.target',
		'mount' => $user_scope ? 'default.target' : 'local-fs.target',
		'automount' => $user_scope ? 'default.target' : 'local-fs.target',
		'swap' => $user_scope ? 'default.target' : 'swap.target',
		'slice' => 'slices.target' );
return $targets{$type};
}

=head2 is_unit(name)

Returns 1 if some unit is managed by systemd.

=cut
sub is_unit
{
my ($name) = @_;
return 0 if (!valid_unit_name($name));
foreach my $s (list_units(1)) {
	if ($s->{'name'} eq $name) {
		return 1;
		}
	}
return 0;
}

=head2 get_unit_root([name], [packaged])

Returns the base directory for systemd unit config files.

=cut
sub get_unit_root
{
my ($name, $packaged) = @_;
# Common system and vendor unit directories.
my $systemd_local_conf = "/etc/systemd/system";
my $systemd_unit_dir1 = "/usr/lib/systemd/system";
my $systemd_unit_dir2 = "/lib/systemd/system";
if ($name) {
	foreach my $p ($systemd_local_conf, $systemd_unit_dir1,
		       $systemd_unit_dir2) {
		foreach my $t (get_unit_types()) {
			return $p if (-r "$p/$name.$t");
			}
		return $p if (-r "$p/$name");
		}
	}
# Always use /etc/systemd/system for locally created units.
return $systemd_local_conf if (!$packaged && -d $systemd_local_conf);

# Debian prefers /lib/systemd/system for packaged units.
if ($gconfig{'os_type'} eq 'debian-linux' &&
    -d $systemd_unit_dir2) {
	return $systemd_unit_dir2;
	}
# RHEL and many other systems use /usr/lib/systemd/system.
if (-d $systemd_unit_dir1) {
	return $systemd_unit_dir1;
	}
# Fallback path for other systems.
return $systemd_unit_dir2;
}


=head2 get_unit_pid([name])

Returns the PID of a running systemd unit, or 0 if stopped or missing.

=cut
sub get_unit_pid
{
my ($unit) = @_;
return 0 if (!valid_unit_name($unit));
my $pid =
  backquote_command("systemctl show --property MainPID @{[quotemeta($unit)]}");
$pid =~ s/MainPID=(\d+)/$1/;
$pid = int($pid);
return $pid;
}

=head2 reload_manager()

Tells the systemd system manager to re-read its unit files.

=cut
sub reload_manager
{
if (has_command("systemctl")) {
	system_logged("systemctl daemon-reload >/dev/null 2>&1");
	}
else {
	my @pids = find_byname("systemd");
	if (@pids) {
		kill_logged('HUP', @pids);
		}
	}
}

=head2 is_active(unit-name)

Check if a systemd unit is active.

=cut
sub is_active
{
my $unit = shift;
return wantarray ? (1, $text{'systemd_ename'}) : 0
	if (!valid_unit_name($unit));
my $out = backquote_logged(
	"systemctl is-active ".quotemeta($unit)." 2>&1 </dev/null");
$out = trim($out);
return wantarray ? ($?, $out) : $out eq "active" ? 1 : 0;
}

=head2 cat_unit(unit, [regex-filter])

Returns parsed systemctl cat output for a unit, optionally filtered by key
name regex.

=cut
sub cat_unit
{
my ($unit, $filter) = @_;
return [] if (!valid_unit_name($unit));
my @config;
my $current_section;
my $current_file;

# Execute systemctl cat and split the combined output by source file.
my $cat = gensym();
open_execute_command($cat, "systemctl cat ".quotemeta($unit), 1, 1);
while (my $line = <$cat>) {
	$line =~ s/\r|\n//g;
	next if $line =~ /^$/;
	if ($line =~ /^#\s+(\/.*)$/) {
		# File name line, e.g. "# /usr/lib/systemd/system/ssh.socket".
		$current_file = $1;
		push @config, { file => $current_file, sections => {} };
		}
	elsif ($line =~ /^\[(.+?)\]$/) {
		# Section header, e.g. "[Unit]".
		$current_section = $1;
		$config[-1]{'sections'}{$current_section} ||= {};
		}
	elsif ($line =~ /^([^=]+)=(.*)$/ && $current_section) {
		# Key-value pair, e.g. "ListenStream=0.0.0.0:22".
		my ($key, $value) = ($1, $2);
		push @{ $config[-1]{'sections'}{$current_section}{$key} }, $value;
		}
	}
close($cat);

# Keep only matching keys when a filter was requested.
if ($filter) {
	my $regex = qr/$filter/;
	if ($filter =~ m{^/(.+)/([igmsx]*)$}) {
		# Accept JavaScript-style /pattern/flags filters from callers.
		my ($pattern, $flags) = ($1, $2);
		$flags =~ s/g//g;
		my $prefix = $flags ? "(?$flags)" : "";
		$regex = qr/$prefix$pattern/;
		}
	foreach my $conf (@config) {
		my $filtered_sections = {};
		foreach my $section_name (keys %{$conf->{'sections'}}) {
			my $section = $conf->{'sections'}{$section_name};
			my %matching_params;
			foreach my $param (keys %$section) {
				$matching_params{$param} = $section->{$param}
					if ($param =~ $regex);
				}
			$filtered_sections->{$section_name} =
				\%matching_params if %matching_params;
			}
		$conf->{'sections'} = $filtered_sections;
		}
	}
return \@config;
}

=head2 edit_unit(unit-name, new-config, [override_filename], [override_dir])

Edits a systemd drop-in override while preserving unrelated settings.

Example:

	edit_unit('ssh.socket', {
		'Socket' => {
			'ListenStream' => [
				'',
				'0.0.0.0:2213',
				'[::]:2213'
			],
		},
		'Install' => {},
	});

Note that option values must always be an array reference, even if there is only
one value; if undef is passed, the key will be removed from the section; if a
section set to empty hash, the section will be removed from the unit file.

=cut
sub edit_unit
{
my ($unit, $new_config, $override_filename, $override_dir) = @_;
valid_unit_name($unit) || error($text{'systemd_ename'});
$override_dir ||= "/etc/systemd/system/$unit.d";
$override_filename ||= "override.conf";
my $override_file = "$override_dir/$override_filename";

# Create the drop-in directory before reading or writing the override.
if (!-d($override_dir)) {
	make_dir($override_dir, oct("0755"), 0) ||
		error("Failed to create directory '$override_dir': $!");
	}

# Read the existing override so unrelated keys can be preserved.
my $existing_config = {};
if (-f($override_file)) {
	my $content = read_file_contents($override_file);
	my $current_section;
	foreach my $line (split(/\r?\n/, $content)) {
		next if ($line =~ /^$/ || $line =~ /^#/);
		if ($line =~ /^\[(.+?)\]$/) {
			# Section header
			$current_section = $1;
			$existing_config->{$current_section} ||= {};
			}
		elsif ($line =~ /^([^=]+)=(.*)$/ && $current_section) {
			# Key-value pair
			my ($key, $value) = ($1, $2);
			push(@{ $existing_config->{$current_section}{$key} },
			     $value);
			}
		}
	}

# Merge the requested section changes into the existing override data.
foreach my $section (keys(%{$new_config})) {
	my $has_values = 0;
	foreach my $key (keys(%{ $new_config->{$section} })) {
		my $values = $new_config->{$section}{$key};
		if (defined($values) && @$values) {
			# Values replace the whole key, including repeated directives.
			$existing_config->{$section}{$key} = $values;
			$has_values = 1;
			}
		else {
			# Undef or an empty list means the key should be removed.
			delete($existing_config->{$section}{$key});
			}
		}

	# Drop empty sections so the override remains compact.
	delete($existing_config->{$section}) if (!$has_values);
	}

# Serialize the merged override in stable section/key order.
my $override_content = "";
foreach my $section (sort(keys(%{$existing_config}))) {
	$override_content .= "[$section]\n";
	foreach my $key (sort(keys(%{ $existing_config->{$section} }))) {
		foreach my $value (@{ $existing_config->{$section}{$key} }) {
			$override_content .= "$key=$value\n";
			}
		}
	$override_content .= "\n";
	}

# Write the merged configuration back to the drop-in file.
lock_file($override_file);
write_file_contents($override_file, $override_content);
unlock_file($override_file);

# Reload systemd to apply the changed drop-in.
system_logged("systemctl daemon-reload") == 0 ||
	error("Failed to reload systemd daemon: $!");
}

1;
