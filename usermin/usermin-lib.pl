=head1 usermin-lib.pl

Functions for configuring Usermin running on this system. Example usage :

 foreign_require("usermin", "usermin-lib.pl");
 @usermods = usermin::list_usermin_usermods();
 push(@usermods, [ 'joe', '', 'mailbox changepass' ]);
 usermin::save_usermin_usermods(\@usermods);

=cut

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
$access{'upgrade'} = 0 if (&is_readonly_mode());	# too hard to fake
&foreign_require("webmin");
&foreign_require("acl");
%text = ( %webmin::text, %text );

$usermin_miniserv_config = "$config{'usermin_dir'}/miniserv.conf";
$usermin_config = "$config{'usermin_dir'}/config";

$update_host = "www.webmin.com";
$update_port = 80;
$update_page = "/uupdates/uupdates.txt";

$standard_usermin_dir = "/etc/usermin";
$latest_rpm = "http://www.webmin.com/download/usermin-latest.noarch.rpm";
$latest_tgz = "http://www.webmin.com/download/usermin-latest.tar.gz";

$default_key_size = 2048;

$cron_cmd = "$module_config_directory/update.pl";

=head2 get_usermin_miniserv_config(&hash)

Similar to the standard get_miniserv_config function, but this one fills in
the given hash ref with the contents of the /etc/usermin/miniserv.conf file.

=cut
sub get_usermin_miniserv_config
{
&read_file($usermin_miniserv_config, \%usermin_miniserv_config_cache)
	if (!%usermin_miniserv_config_cache);
%{$_[0]} = %usermin_miniserv_config_cache;
}

=head2 put_usermin_miniserv_config(&hash)

Writes out the Usermin miniserv configuration, based on the given hash ref.

=cut
sub put_usermin_miniserv_config
{
%usermin_miniserv_config_cache = %{$_[0]};
&write_file($usermin_miniserv_config, \%usermin_miniserv_config_cache);
}

=head2 get_usermin_version

Returns the version number of Usermin on this system.

=cut
sub get_usermin_version
{
local %miniserv;
&get_usermin_miniserv_config(\%miniserv);
open(VERSION, "$miniserv{'root'}/version");
local $version = <VERSION>;
close(VERSION);
$version =~ s/\r|\n//g;
return $version;
}

=head2 restart_usermin_miniserv

Send a HUP signal to Usermin's miniserv, telling it to restart and re-read
all configuration files.

=cut
sub restart_usermin_miniserv
{
return undef if (&is_readonly_mode());
local($pid, %miniserv, $addr, $i);
&get_usermin_miniserv_config(\%miniserv) || return;
$miniserv{'inetd'} && return;
open(PID, $miniserv{'pidfile'}) || &error("Failed to open PID file");
chop($pid = <PID>);
close(PID);
if (!$pid) { &error("Invalid PID file"); }
return &kill_logged('HUP', $pid);
}

=head2 reload_usermin_miniserv

Sends a USR1 signal to the miniserv process, telling it to re-read most
configuration files.

=cut
sub reload_usermin_miniserv
{
return undef if (&is_readonly_mode());
local %miniserv;
&get_usermin_miniserv_config(\%miniserv) || return;
$miniserv{'inetd'} && return;

local($pid, $addr, $i);
open(PID, $miniserv{'pidfile'}) || &error("Failed to open PID file");
chop($pid = <PID>);
close(PID);
if (!$pid) { &error("Invalid PID file"); }
return &kill_logged('USR1', $pid);
}

=head2 get_usermin_config(&hash)

Fills in the given hash ref with the contents of the global Usermin
configuration file, typically at /etc/usermin/config.

=cut
sub get_usermin_config
{
&read_file($usermin_config, \%usermin_config_cache)
	if (!%usermin_config_cache);
%{$_[0]} = %usermin_config_cache;
}

=head2 put_usermin_config(&hash)

Writes the given hash ref to the global Usermin configuration file.

=cut
sub put_usermin_config
{
%usermin_config_cache = %{$_[0]};
&write_file($usermin_config, \%usermin_config_cache);
}

=head2 list_themes

Returns an array of all usermin themes. The format is the same as the 
webmin::list_themes function.

=cut
sub list_themes
{
local @rv;
local %miniserv;
&get_usermin_miniserv_config(\%miniserv);
opendir(DIR, $miniserv{'root'});
foreach $m (readdir(DIR)) {
	next if ($m =~ /^\./);
	local %tinfo = &get_usermin_theme_info($m);
	next if (!%tinfo);
	next if (!&check_usermin_os_support(\%tinfo));
	push(@rv, \%tinfo);
	}
closedir(DIR);
return @rv;
}

=head2 list_modules

Returns a list of all usermin modules installed and supported on this system.
Each is a hash ref in the same format as returned by Webmin's get_module_info
function.

=cut
sub list_modules
{
local (@mlist, $m, %miniserv);
&get_usermin_miniserv_config(\%miniserv);
local %cats;
&read_file_cached("$config{'usermin_dir'}/webmin.cats", \%cats);
opendir(DIR, $miniserv{'root'});
foreach $m (readdir(DIR)) {
	local %minfo;
	if ((%minfo = &get_usermin_module_info($m)) &&
	    &check_usermin_os_support(\%minfo)) {
		$minfo{'realcategory'} = $minfo{'category'};
		$minfo{'category'} = $cats{$m} if (defined($cats{$m}));
		push(@mlist, \%minfo);
		}
	}
closedir(DIR);
@mlist = sort { $a->{'desc'} cmp $b->{'desc'} } @mlist;
return @mlist;
}

=head2 get_usermin_module_info(module, [noclone])

Returns a hash contain details of a module, in the same format as 
Webmin's get_module_info function. Useful keys include :

=item dir - The module's relative directory.

=item desc - The human-readable title.

=item category - Category the module is in, like login or apps.

=item depends - Space-separated list of dependent modules.

=item os_support - List of supported operating systems and versions.

=cut
sub get_usermin_module_info
{
return () if ($_[0] =~ /^\./);
local (%rv, $clone, %miniserv, $o);
&get_usermin_miniserv_config(\%miniserv);
&read_file("$miniserv{'root'}/$_[0]/module.info", \%rv) || return ();
$clone = -l "$miniserv{'root'}/$_[0]";
foreach $o (@lang_order_list) {
	$rv{"desc"} = $rv{"desc_$o"} if ($rv{"desc_$o"});
	}
if ($clone && !$_[1] && $config_directory) {
	$rv{'clone'} = $rv{'desc'};
	&read_file("$config{'usermin_dir'}/$_[0]/clone", \%rv);
	}
$rv{'dir'} = $_[0];
$rv{'realcategory'} = $rv{'category'};

# Apply description overrides
$rv{'realdesc'} = $rv{'desc'};
local %descs;
&read_file_cached("$config{'usermin_dir'}/webmin.descs", \%descs);
if ($descs{$_[0]." ".$current_lang}) {
	$rv{'desc'} = $descs{$_[0]." ".$current_lang};
	}
elsif ($descs{$_[0]}) {
	$rv{'desc'} = $descs{$_[0]};
	}

return %rv;
}

=head2 get_usermin_theme_info(theme)

Like get_usermin_module_info, but returns the details of a theme instead.
This is basically the contents of its theme.info file.

=cut
sub get_usermin_theme_info
{
local (%tinfo, $o);
local %miniserv;
&get_usermin_miniserv_config(\%miniserv);
&read_file("$miniserv{'root'}/$_[0]/theme.info", \%tinfo) || return ();
foreach $o (@lang_order_list) {
	$tinfo{"desc"} = $rv{"desc_$o"} if ($tinfo{"desc_$o"});
	}
$tinfo{'dir'} = $_[0];
return %tinfo;
}

=head2 check_usermin_os_support(&minfo)

Given a Usermin module information hash ref (as returned by
get_usermin_module_info), checks if it is supported on this OS. Returns 1 if
yes, 0 if no.

=cut
sub check_usermin_os_support
{
local $oss = $_[0]->{'os_support'};
return 1 if (!$oss || $oss eq '*');
local %uconfig;
&get_usermin_config(\%uconfig);
while(1) {
	local ($os, $ver, $codes);
	if ($oss =~ /^([^\/\s]+)\/([^\{\s]+)\{([^\}]*)\}\s*(.*)$/) {
		$os = $1; $ver = $2; $codes = $3; $oss = $4;
		}
	elsif ($oss =~ /^([^\/\s]+)\/([^\/\s]+)\s*(.*)$/) {
		$os = $1; $ver = $2; $oss = $3;
		}
	elsif ($oss =~ /^([^\{\s]+)\{([^\}]*)\}\s*(.*)$/) {
		$os = $1; $codes = $2; $oss = $3;
		}
	elsif ($oss =~ /^\{([^\}]*)\}\s*(.*)$/) {
		$codes = $1; $oss = $2;
		}
	elsif ($oss =~ /^(\S+)\s*(.*)$/) {
		$os = $1; $oss = $2;
		}
	else { last; }
	next if ($os && !($os eq $uconfig{'os_type'} ||
		 $uconfig{'os_type'} =~ /^(\S+)-(\S+)$/ && $os eq "*-$2"));
	next if ($ver && $ver ne $uconfig{'os_version'});
	next if ($codes && !eval $codes);
	return 1;
	}
return 0;
}

=head2 read_usermin_acl(&array, &array)

Reads the acl file into the given hashes. The first maps user,module to
1 where granted, which the second maps a user to an array ref of module dirs.

=cut
sub read_usermin_acl
{
local($user, $_, @mods);
if (!%usermin_acl_hash_cache) {
	open(ACL, &usermin_acl_filename());
	while(<ACL>) {
		if (/^(\S+):\s*(.*)/) {
			local(@mods);
			$user = $1;
			@mods = split(/\s+/, $2);
			foreach $m (@mods) {
				$usermin_acl_hash_cache{$user,$m}++;
				}
			$usermin_acl_array_cache{$user} = \@mods;
			}
		}
	close(ACL);
	}
if ($_[0]) { %{$_[0]} = %usermin_acl_hash_cache; }
if ($_[1]) { %{$_[1]} = %usermin_acl_array_cache; }
}

=head2 usermin_acl_filename

Returns the file containing the webmin ACL.

=cut
sub usermin_acl_filename
{
return "$config{'usermin_dir'}/webmin.acl";
}

=head2 save_usermin_acl(user, &modules)

Updates the list of available modules in Usermin.

=cut
sub save_usermin_acl
{
&open_tempfile(ACL, ">".&usermin_acl_filename());
&print_tempfile(ACL, $_[0],": ",join(" ", @{$_[1]}),"\n");
&close_tempfile(ACL);
}

=head2 install_usermin_module(file, unlink, nodeps)

Installs a usermin module or theme, and returns either an error message
or references to three arrays for descriptions, directories and sizes.
On success or failure, the file is deleted if the unlink parameter is set.

=cut
sub install_usermin_module
{
local ($file, $need_unlink, $nodeps) = @_;
local (@mdescs, @mdirs, @msizes);
if (&is_readonly_mode()) {
	return "Module installs are not allowed in readonly mode";
	}

# Uncompress the module file if needed
open(MFILE, $file);
read(MFILE, $two, 2);
close(MFILE);
if ($two eq "\037\235") {
	if (!&has_command("uncompress")) {
		unlink($file) if ($need_unlink);
		return &text('install_ecomp', "<tt>uncompress</tt>");
		}
	local $temp = $file =~ /\/([^\/]+)\.Z/i ? &transname("$1")
						: &transname();
	local $out = `uncompress -c "$file" 2>&1 >$temp`;
	unlink($file) if ($need_unlink);
	if ($?) {
		unlink($temp);
		return &text('install_ecomp2', $out);
		}
	$file = $temp;
	$need_unlink = 1;
	}
elsif ($two eq "\037\213") {
	if (!&has_command("gunzip")) {
		unlink($file) if ($need_unlink);
		return &text('install_egzip', "<tt>gunzip</tt>");
		}
	local $temp = $file =~ /\/([^\/]+)\.gz/i ? &transname("$1")
						 : &transname();
	local $out = `gunzip -c "$file" 2>&1 >$temp`;
	unlink($file) if ($need_unlink);
	if ($?) {
		unlink($temp);
		return &text('install_egzip2', $out);
		}
	$file = $temp;
	$need_unlink = 1;
	}

local %miniserv;
&get_usermin_miniserv_config(\%miniserv);

# Check if this is an RPM usermin module or theme
local ($type, $redirect_to);
open(TYPE, "../install-type");
chop($type = <TYPE>);
close(TYPE);
if ($type eq 'rpm' && $file =~ /\.rpm$/i &&
    ($out = `rpm -qp $file 2>/dev/null`)) {
	# Looks like an RPM of some kind, hopefully an RPM usermin module
	# or theme
	local ($out, %minfo, %tinfo);
	if ($out !~ /^(wbm|wbt)-([^\s\-]+)/) {
		unlink($file) if ($need_unlink);
		return $text{'install_erpm'};
		}
	$redirect_to = $name = $2;
	$out = &backquote_logged("rpm -U \"$file\" 2>&1");
	if ($?) {
		unlink($file) if ($need_unlink);
		return &text('install_eirpm', "<tt>$out</tt>");
		}

	$mdirs[0] = "$miniserv{'root'}/$name";
	if (%minfo = &get_usermin_module_info($name)) {
		# Get the new module info
		$mdescs[0] = $minfo{'desc'};
		$msizes[0] = &disk_usage_kb($mdirs[0]);

		# Update the ACL for the usermin user
		local %acl;
		&read_usermin_acl(undef, \%acl);
		&open_tempfile(ACL, "> ".&usermin_acl_filename());
		foreach $u (keys %acl) {
			local @mods = @{$acl{$u}};
			if ($u eq 'user') {
				push(@mods, $name);
				@mods = &unique(@mods);
				}
			&print_tempfile(ACL, "$u: ",join(' ', @mods),"\n");
			}
		&close_tempfile(ACL);
		&webmin_log("install", undef, $name,
			    { 'desc' => $mdescs[0] });
		}
	elsif (%tinfo = &get_usermin_theme_info($name)) {
		# Get the theme info
		$mdescs[0] = $tinfo{'desc'};
		$msizes[0] = &disk_usage_kb($mdirs[0]);
		&webmin_log("tinstall", undef, $name,
			    { 'desc' => $mdescs[0] });
		}
	else {
		unlink($file) if ($need_unlink);
		return $text{'install_eneither'};
		}
	}
else {
	# Check if this is a valid module (a tar file of multiple module or
	# theme directories)
	local (%mods, %hasfile);
	local $tar = `tar tf "$file" 2>&1`;
	if ($?) {
		unlink($file) if ($need_unlink);
		return &text('install_etar', $tar);
		}
	foreach $f (split(/\n/, $tar)) {
		if ($f =~ /^\.\/([^\/]+)\/(.*)$/ || $f =~ /^([^\/]+)\/(.*)$/) {
			$redirect_to = $1 if (!$redirect_to);
			$mods{$1}++;
			$hasfile{$1,$2}++;
			}
		}
	foreach $m (keys %mods) {
		if (!$hasfile{$m,"module.info"} && !$hasfile{$m,"theme.info"}) {
			unlink($file) if ($need_unlink);
			return &text('install_einfo', "<tt>$m</tt>");
			}
		}
	if (!%mods) {
		unlink($file) if ($need_unlink);
		return $text{'install_enone'};
		}

	# Get the module.info files to check dependencies
	local $ver = &get_usermin_version();
	local $tmpdir = &transname();
	mkdir($tmpdir, 0700);
	local $err;
	local @realmods;
	foreach $m (keys %mods) {
		next if (!$hasfile{$m,"module.info"});
		push(@realmods, $m);
		local %minfo;
		system("cd $tmpdir ; tar xf \"$file\" $m/module.info ./$m/module.info >/dev/null 2>&1");
		if (!&read_file("$tmpdir/$m/module.info", \%minfo)) {
			$err = &text('install_einfo', "<tt>$m</tt>");
			}
		elsif (!&check_usermin_os_support(\%minfo)) {
			$err = &text('install_eos', "<tt>$m</tt>",
				     $gconfig{'real_os_type'},
				     $gconfig{'real_os_version'});
			}
		elsif (!$minfo{'usermin'}) {
			$err = &text('install_eusermin', "<tt>$m</tt>");
			}
		elsif (!$nodeps) {
			local $deps = $minfo{'usermin_depends'} ||
				      $minfo{'depends'};
			foreach $dep (split(/\s+/, $minfo{'depends'})) {
				if ($dep =~ /^[0-9\.]+$/) {
					if ($dep > $ver) {
						$err = &text('install_ever',
							"<tt>$m</tt>",
							"<tt>$dep</tt>");
						}
					}
				elsif (!-r "$miniserv{'root'}/$dep/module.info"
				       && !$mods{$dep}) {
					$err = &text('install_edep',
					        "<tt>$m</tt>", "<tt>$dep</tt>");
					}
				}
			foreach $dep (split(/\s+/, $minfo{'perldepends'})) {
				eval "use $dep";
				if ($@) {
					$err = &text('install_eperldep',
					     "<tt>$m</tt>", "<tt>$dep</tt>",
					     "/cpan/download.cgi?source=3&cpan=$dep");
					}
				}
			}
		last if ($err);
		}
	system("rm -rf $tmpdir >/dev/null 2>&1");
	if ($err) {
		unlink($file) if ($need_unlink);
		return $err;
		}

	# Delete modules or themes being replaced
	foreach $m (@realmods) {
		system("rm -rf '$miniserv{'root'}/$m' 2>&1 >/dev/null") if ($m ne 'webmin');
		}

	# Extract all the modules and update perl path and ownership
	local $out = `cd $miniserv{'root'} ; tar xf "$file" 2>&1 >/dev/null`;
	if ($?) {
		unlink($file) if ($need_unlink);
		return &text('install_eextract', $out);
		}
	if ($need_unlink) { unlink($file); }
	local $perl;
	open(PERL, "$miniserv{'root'}/miniserv.pl");
	<PERL> =~ /^#!(\S+)/; $perl = $1;
	close(PERL);
	local @st = stat($0);
	foreach $moddir (keys %mods) {
		local $pwd = "$miniserv{'root'}/$moddir";
		if ($hasfile{$moddir,"module.info"}) {
			local %minfo = &get_usermin_module_info($moddir);
			push(@mdescs, $minfo{'desc'});
			push(@mdirs, $pwd);
			push(@msizes, &disk_usage_kb($pwd));
			&webmin_log("install", undef, $moddir,
				    { 'desc' => $minfo{'desc'} });
			}
		else {
			local %tinfo = &get_usermin_theme_info($moddir);
			&read_file("theme.info", \%tinfo);
			push(@mdescs, $tinfo{'desc'});
			push(@mdirs, $pwd);
			push(@msizes, &disk_usage_kb($pwd));
			&webmin_log("tinstall", undef, $moddir,
				    { 'desc' => $tinfo{'desc'} });
			}
		system("(find $pwd -name '*.cgi' ; find $pwd -name '*.pl') 2>/dev/null | $perl $miniserv{'root'}/perlpath.pl $perl -");
		system("chown -R $st[4]:$st[5] $pwd");
		}

	# Copy appropriate config file from modules to /etc/webmin
	local %ugconfig;
	&get_usermin_config(\%ugconfig);
	system("$perl $miniserv{'root'}/copyconfig.pl '$ugconfig{'os_type'}/$ugconfig{'real_os_type'}' '$ugconfig{'os_version'}/$ugconfig{'real_os_version'}' $miniserv{'root'} $config{'usermin_dir'} ".join(' ', @realmods));

	# Update ACL for this user so they can access the new modules
	local %acl;
	&read_usermin_acl(undef, \%acl);
	&open_tempfile(ACL, "> ".&usermin_acl_filename());
	foreach $u (keys %acl) {
		local @mods = @{$acl{$u}};
		if ($u eq 'user') {
			push(@mods, @realmods);
			@mods = &unique(@mods);
			}
		&print_tempfile(ACL, "$u: ",join(' ', @mods),"\n");
		}
	&close_tempfile(ACL);
	}
&flush_modules_cache();

return [ \@mdescs, \@mdirs, \@msizes ];
}

=head2 list_usermin_usermods

Returns the list of additional module restrictions for usermin.
This is a list of array refs, each element of which contains a username,
a flag and an array ref of module names. The flag can be one of :

=item + - Add the modules to the list available to this user.

=item - - Take the modules away from this user.

=item blank - Assign the modules to the list for this user.

=cut
sub list_usermin_usermods
{
local @rv;
open(USERMODS, "$config{'usermin_dir'}/usermin.mods");
while(<USERMODS>) {
	if (/^([^:]+):(\+|-|):(.*)/) {
		push(@rv, [ $1, $2, [ split(/\s+/, $3) ] ]);
		}
	}
close(USERMODS);
return @rv;
}

=head2 save_usermin_usermods(&usermods)

Saves the list of additional module restrictions. This must be an array ref
in the same format as returned by list_usermin_usermods.

=cut
sub save_usermin_usermods
{
&open_tempfile(USERMODS, ">$config{'usermin_dir'}/usermin.mods");
foreach $u (@{$_[0]}) {
	&print_tempfile(USERMODS,
		join(":", $u->[0], $u->[1], join(" ", @{$u->[2]})),"\n");
	}
&close_tempfile(USERMODS);
}

=head2 get_usermin_miniserv_users

Returns a list of Usermin users from miniserv.users. In normal use, there
is only one, as all authentication is done using Unix users.

=cut
sub get_usermin_miniserv_users
{
local %miniserv;
&get_usermin_miniserv_config(\%miniserv);
local @rv;
open(USERS, $miniserv{'userfile'});
while(<USERS>) {
	s/\r|\n//g;
	local @u = split(/:/, $_);
	push(@rv, { 'name' => $u[0],
		    'pass' => $u[1],
		    'sync' => $u[2],
		    'cert' => $u[3],
		    'allow' => $u[4] });
	}
close(USERS);
return @rv;
}

=head2 save_usermin_miniserv_users(&user, ...)

Updats the list of Usermin miniserv users, each of which is a hash ref
in the format returned by get_usermin_miniserv_users.

=cut
sub save_usermin_miniserv_users
{
local %miniserv;
&get_usermin_miniserv_config(\%miniserv);
&open_tempfile(USERS, ">$miniserv{'userfile'}");
local $u;
foreach $u (@_) {
	&print_tempfile(USERS,
		join(":", $u->{'name'}, $u->{'pass'}, $u->{'sync'},
			  $u->{'cert'}, $u->{'allow'}),"\n");
	}
&close_tempfile(USERS);
}

=head2 can_use_module(module)

Returns 1 if the current Webmin user can use some function of this module.

=cut
sub can_use_module
{
return 1 if ($access{'mods'} eq '*');
local @mods = split(/\s+/, $access{'mods'});
return &indexof($_[0], @mods) >= 0;
}

=head2 get_usermin_base_version

Gets the usermin version, rounded to the nearest .01

=cut
sub get_usermin_base_version
{
return &base_version(&get_usermin_version());
}

=head2 base_version

Rounds a version number to the nearest .01

=cut
sub base_version
{
return sprintf("%.2f0", $_[0]);
}

=head2 find_cron_job(\@jobs)

Finds the cron job for Usermin updates, given an array ref of cron jobs
as returned by cron::list_cron_jobs.

=cut
sub find_cron_job
{
local ($job) = grep { $_->{'user'} eq 'root' &&
		      $_->{'command'} eq $cron_cmd } @{$_[0]};
return $job;
}

=head2 delete_usermin_module(module, [delete-acls])

Deletes some usermin module, clone or theme, and return a description of
the thing deleted.

=cut
sub delete_usermin_module
{
local $m = $_[0];
return undef if (!$m);
local %minfo = &get_usermin_module_info($m);
%minfo = &get_usermin_theme_info($m) if (!%minfo);
return undef if (!%minfo);
local ($mdesc, @aclrm);
@aclrm = ( $m ) if ($_[1]);
local %miniserv;
&get_usermin_miniserv_config(\%miniserv);
local %ugconfig;
&get_usermin_config(\%uconfig);
local $mdir = "$miniserv{'root'}/$m";
local $cdir = "$config{'usermin_dir'}/$m";
if ($minfo{'clone'}) {
	# Deleting a clone
	local %cinfo;
	&read_file("$config{'usermin_dir'}/$m/clone", \%cinfo);
	&unlink_logged($mdir);
	&system_logged("rm -rf ".quotemeta($cdir));
	if ($ugconfig{'theme'}) {
		&unlink_logged("$miniserv{'root'}/$ugconfig{'theme'}/$m");
		}
	$mdesc = &text('delete_desc1', $minfo{'desc'}, $minfo{'clone'});
	}
else {
	# Delete any clones of this module
	local @clones;
	local @mst = stat($mdir);
	opendir(DIR, $miniserv{'root'});
	local $l;
	foreach $l (readdir(DIR)) {
		@lst = stat("$miniserv{'root'}/$l");
		if (-l "$miniserv{'root'}/$l" && $lst[1] == $mst[1]) {
			&unlink_logged("$miniserv{'root'}/$l");
			&system_logged("rm -rf $config{'usermin_dir'}/$l");
			push(@clones, $l);
			}
		}
	closedir(DIR);

	open(TYPE, "$mdir/install-type");
	chop($type = <TYPE>);
	close(TYPE);

	# Deleting the real module
	local $size = &disk_usage_kb($mdir);
	$mdesc = &text('delete_desc2', "<b>$minfo{'desc'}</b>",
			   "<tt>$mdir</tt>", $size);
	if ($type eq 'rpm') {
		# This module was installed from an RPM .. rpm -e it
		&system_logged("rpm -e ubm-$m");
		}
	else {
		# Module was installed from a .wbm file .. just rm it
		&system_logged("rm -rf ".quotemeta($mdir));
		}
	}

&webmin_log("delete", undef, $m, { 'desc' => $minfo{'desc'} });
return $mdesc;
}

=head2 flush_modules_cache

Forces a rebuild of the Usermin module cache.

=cut
sub flush_modules_cache
{
&unlink_file("$config{'usermin_dir'}/module.infos.cache");
}

=head2 stop_usermin

Kills the running Usermin server process, returning undef on success or an
error message on failure.

=cut
sub stop_usermin
{
local %miniserv;
&get_usermin_miniserv_config(\%miniserv);
local $pid;
if (open(PID, $miniserv{'pidfile'}) && ($pid = int(<PID>))) {
	&kill_logged('TERM', $pid) || return &text('stop_ekill', $!);
	close(PID);
	}
else {
	return $text{'stop_efile'};
	}
return undef;
}

=head2 start_usermin

Starts the Usermin server process. Return value is always undef.

=cut
sub start_usermin
{
&system_logged("$config{'usermin_dir'}/start >/dev/null 2>&1 </dev/null");
return undef;
}

=head2 get_install_type

Returns the package type Usermin was installed form (rpm, deb, solaris-pkg
or undef for tar.gz).

=cut
sub get_install_type
{
local (%miniserv, $mode);
&get_usermin_miniserv_config(\%miniserv);
if (open(MODE, "$miniserv{'root'}/install-type")) {
	chop($mode = <MODE>);
	close(MODE);
	}
else {
	if ($miniserv{'root'} eq "/usr/libexec/usermin") {
		$mode = "rpm";
		}
	elsif ($miniserv{'root'} eq "/usr/share/usermin") {
		$mode = "deb";
		}
	else {
		$mode = undef;
		}
	}
return $mode;
}

=head2 switch_to_usermin_user(username)

Returns a set-cookie header and redirect URL for auto-logging into Usermin
as some user.

=cut
sub switch_to_usermin_user
{
my ($user) = @_;

# Stop Usermin first, so that the DBM can be safely written
my %miniserv;
&get_usermin_miniserv_config(\%miniserv);
my $stopped;
if (&check_pid_file($miniserv{'pidfile'})) {
	&stop_usermin();
	$stopped = 1;
	}

# Generate a session ID and set it in the DB
&acl::open_session_db(\%miniserv);
&seed_random();
my $now = time();
my $sid = int(rand()*$now);
$acl::sessiondb{$sid} = "$user $now $ENV{'REMOTE_ADDR'}";
dbmclose(%acl::sessiondb);
if ($stopped) {
	&start_usermin();
	}
&reload_usermin_miniserv();
eval "use Net::SSLeay";
if ($@) {
	$miniserv{'ssl'} = 0;
	}
my $ssl = $miniserv{'ssl'} || $miniserv{'inetd_ssl'};
my $sec = $ssl ? "; secure" : "";
my $sidname = $miniserv{'sidname'} || 'sid';
my $cookie = "$sidname=$sid; path=/$sec";

# Work out redirect host
my @sockets = &webmin::get_miniserv_sockets(\%miniserv);
my ($host, $port);
if ($config{'host'}) {
	# Specific hostname set
	$host = $config{'host'};
	}
else {
	if ($sockets[0]->[0] ne "*") {
		# Listening on special IP
		$host = $sockets[0]->[0];
		$port = $sockets[0]->[1] if ($sockets[0]->[1] ne '*');
		}
	else {
		# Use same hostname as this server
		$host = $ENV{'HTTP_HOST'};
		$host =~ s/:.*//;
		}
	}
$port ||= $config{'port'} || $miniserv{'port'};

return ($cookie, ($ssl ? "https://" : "http://").$host.":".$port."/");
}

1;

