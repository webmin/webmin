# webmin-lib.pl
# Common functions for configuring miniserv

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';

@cs_codes = ( 'cs_page', 'cs_text', 'cs_table', 'cs_header', 'cs_link' );
@cs_names = map { $text{$_} } @cs_codes;

$osdn_host = "prdownloads.sourceforge.net";
$osdn_port = 80;

$update_host = "www.webmin.com";
$update_port = 80;
$update_page = "/updates/updates.txt";
$update_url = "http://$update_host:$update_port$update_page";
$redirect_url = "http://$update_host/cgi-bin/redirect.cgi";

$webmin_key_email = "jcameron\@webmin.com";
$webmin_key_fingerprint = "1719 003A CE3E 5A41 E2DE  70DF D97A 3AE9 11F6 3C51";

$standard_host = $update_host;
$standard_port = $update_port;
$standard_page = "/download/modules/standard.txt";
$standard_ssl = 0;

$third_host = $update_host;
$third_port = $update_port;
$third_page = "/cgi-bin/third.cgi";
$third_ssl = 0;

$default_key_size = "512";

$cron_cmd = "$module_config_directory/update.pl";

$os_info_address = "os\@webmin.com";

$detect_operating_system_cache = "$module_config_directory/oscache";

sub setup_ca
{
local $adir = &module_root_directory("acl");
local $conf = `cat $adir/openssl.cnf`;
local $acl = "$config_directory/acl";
$conf =~ s/DIRECTORY/$acl/g;

&lock_file("$acl/openssl.cnf");
&open_tempfile(CONF, ">$acl/openssl.cnf");
&print_tempfile(CONF, $conf);
&close_tempfile(CONF);
chmod(0600, "$acl/openssl.cnf");
&unlock_file("$acl/openssl.cnf");

&lock_file("$acl/index.txt");
&open_tempfile(INDEX, ">$acl/index.txt");
&close_tempfile(INDEX);
chmod(0600, "$acl/index.txt");
&unlock_file("$acl/index.txt");

&lock_file("$acl/serial");
&open_tempfile(SERIAL, ">$acl/serial");
&print_tempfile(SERIAL, "011E\n");
&close_tempfile(SERIAL);
chmod(0600, "$acl/serial");
&unlock_file("$acl/serial");

&lock_file("$acl/newcerts");
mkdir("$acl/newcerts", 0700);
chmod(0700, "$acl/newcerts");
&unlock_file("$acl/newcerts");
$miniserv{'ca'} = "$acl/ca.pem";
}

# list_themes()
# Returns an array of all installed themes
sub list_themes
{
local (@rv, $o);
opendir(DIR, $root_directory);
foreach $m (readdir(DIR)) {
	local %tinfo;
	next if ($m =~ /^\./);
	next if (!&read_file_cached("$root_directory/$m/theme.info", \%tinfo));
	next if (!&check_os_support(\%tinfo));
	foreach $o (@lang_order_list) {
		if ($tinfo{'desc_'.$o}) {
			$tinfo{'desc'} = $tinfo{'desc_'.$o};
			}
		}
	$tinfo{'dir'} = $m;
	push(@rv, \%tinfo);
	}
closedir(DIR);
return sort { lc($a->{'desc'}) cmp lc($b->{'desc'}) } @rv;
}

# install_webmin_module(file, unlink, nodeps, &users|groups)
# Installs a webmin module or theme, and returns either an error message
# or references to three arrays for descriptions, directories and sizes.
# On success or failure, the file is deleted if the unlink parameter is set.
sub install_webmin_module
{
local ($file, $need_unlink, $nodeps, $grant) = @_;
local (@mdescs, @mdirs, @msizes);
local (@newmods, $m);
local $install_root_directory = $gconfig{'install_root'} || $root_directory;

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
elsif ($two eq "BZ") {
	if (!&has_command("bunzip2")) {
		unlink($file) if ($need_unlink);
		return &text('install_ebunzip', "<tt>bunzip2</tt>");
		}
	local $temp = $file =~ /\/([^\/]+)\.gz/i ? &transname("$1")
						 : &transname();
	local $out = `bunzip2 -c "$file" 2>&1 >$temp`;
	unlink($file) if ($need_unlink);
	if ($?) {
		unlink($temp);
		return &text('install_ebunzip2', $out);
		}
	$file = $temp;
	$need_unlink = 1;
	}

# Check if this is an RPM webmin module or theme
local ($type, $redirect_to);
open(TYPE, "$root_directory/install-type");
chop($type = <TYPE>);
close(TYPE);
if ($type eq 'rpm' && $file =~ /\.rpm$/i &&
    ($out = `rpm -qp $file 2>/dev/null`)) {
	# Looks like an RPM of some kind, hopefully an RPM webmin module
	# or theme
	local (%minfo, %tinfo);
	if ($out !~ /(^|\n)(wbm|wbt)-([a-z\-]+)/) {
		unlink($file) if ($need_unlink);
		return $text{'install_erpm'};
		}
	$redirect_to = $name = $3;
	$out = &backquote_logged("rpm -U \"$file\" 2>&1");
	if ($?) {
		unlink($file) if ($need_unlink);
		return &text('install_eirpm', "<tt>$out</tt>");
		}
	unlink("$config_directory/module.infos.cache");

	$mdirs[0] = &module_root_directory($name);
	if (%minfo = &get_module_info($name)) {
		# Get the new module info
		$mdescs[0] = $minfo{'desc'};
		$msizes[0] = &disk_usage_kb($mdirs[0]);
		@newmods = ( $name );

		# Update the ACL for this user
		&grant_user_module($grant, [ $name ]);
		&webmin_log("install", undef, $name,
			    { 'desc' => $mdescs[0] });
		}
	elsif (%tinfo = &get_theme_info($name)) {
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
	&has_command("tar") || return $text{'install_enotar'};
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

	# Get the module.info files to check dependancies
	local $ver = &get_webmin_version();
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
		elsif (!&check_os_support(\%minfo)) {
			$err = &text('install_eos', "<tt>$m</tt>",
				     $gconfig{'real_os_type'},
				     $gconfig{'real_os_version'});
			}
		elsif ($minfo{'usermin'} && !$minfo{'webmin'}) {
			$err = &text('install_eusermin', "<tt>$m</tt>");
			}
		elsif (!$nodeps) {
			local $deps = $minfo{'webmin_depends'} ||
				      $minfo{'depends'};
			foreach $dep (split(/\s+/, $deps)) {
				if ($dep =~ /^[0-9\.]+$/) {
					# Depends on some version of webmin
					if ($dep > $ver) {
						$err = &text('install_ever',
							"<tt>$m</tt>",
							"<tt>$dep</tt>");
						}
					}
				elsif ($dep =~ /^(\S+)\/([0-9\.]+)$/) {
					# Depends on a specific version of
					# some other module
					local ($dmod, $dver) = ($1, $2);
					local %dinfo = &get_module_info($dmod);
					if (!$mods{$dmod} &&
					    (!%dinfo ||
					     $dinfo{'version'} < $dver)) {
						$err = &text('install_edep2',
							"<tt>$m</tt>",
							"<tt>$dmod</tt>",
							"<tt>$dver</tt>");
						}
					}
				elsif (!&foreign_exists($dep) &&
				       !$mods{$dep}) {
					# Depends on some other module
					$err = &text('install_edep',
					        "<tt>$m</tt>", "<tt>$dep</tt>");
					}
				}
			foreach $dep (split(/\s+/, $minfo{'perldepends'})) {
				eval "use $dep";
				if ($@) {
					$err = &text('install_eperldep',
					     "<tt>$m</tt>", "<tt>$dep</tt>",
					     "$gconfig{'webprefix'}/cpan/download.cgi?source=3&cpan=$dep");
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
	local $oldpwd = &get_current_dir();
	chdir($root_directory);
	local @grantmods;
	foreach $m (@realmods) {
		push(@grantmods, $m) if (!&foreign_exists($m));
		if ($m ne "webmin") {
			system("rm -rf ".quotemeta("$install_root_directory/$m")." 2>&1 >/dev/null");
			}
		}

	# Extract all the modules and update perl path and ownership
	local $out = `cd $install_root_directory ; tar xf "$file" 2>&1 >/dev/null`;
	chdir($oldpwd);
	if ($?) {
		unlink($file) if ($need_unlink);
		return &text('install_eextract', $out);
		}
	if ($need_unlink) { unlink($file); }
	local $perl = &get_perl_path();
	local @st = stat("$module_root_directory/index.cgi");
	foreach $moddir (keys %mods) {
		local $pwd = &module_root_directory($moddir);
		if ($hasfile{$moddir,"module.info"}) {
			local %minfo = &get_module_info($moddir);
			push(@mdescs, $minfo{'desc'});
			push(@mdirs, $pwd);
			push(@msizes, &disk_usage_kb($pwd));
			&webmin_log("install", undef, $moddir,
				    { 'desc' => $minfo{'desc'} });
			push(@newmods, $moddir);
			}
		else {
			local %tinfo = &get_theme_info($moddir);
			push(@mdescs, $tinfo{'desc'});
			push(@mdirs, $pwd);
			push(@msizes, &disk_usage_kb($pwd));
			&webmin_log("tinstall", undef, $moddir,
				    { 'desc' => $tinfo{'desc'} });
			}
		system("cd $install_root_directory ; (find $pwd -name '*.cgi' ; find $pwd -name '*.pl') 2>/dev/null | $perl $root_directory/perlpath.pl $perl -");
		system("cd $install_root_directory ; chown -R $st[4]:$st[5] $pwd");
		}

	# Copy appropriate config file from modules to /etc/webmin
	system("cd $root_directory ; $perl $root_directory/copyconfig.pl '$gconfig{'os_type'}/$gconfig{'real_os_type'}' '$gconfig{'os_version'}/$gconfig{'real_os_version'}' '$install_root_directory' '$config_directory' ".join(' ', @realmods));

	# Update ACL for this user so they can access the new modules
	&grant_user_module($grant, \@grantmods);
	}
&flush_webmin_caches();

# Run post-install scripts
foreach $m (@newmods) {
	next if (!-r &module_root_directory($m)."/postinstall.pl");
	eval {
		&foreign_require($m, "postinstall.pl");
		&foreign_call($m, "module_install");
		};
	}

return [ \@mdescs, \@mdirs, \@msizes ];
}

# grant_user_module(&users/groups, &modules)
sub grant_user_module
{
# Grant to appropriate users
local %acl;
&read_acl(undef, \%acl);
&open_tempfile(ACL, ">".&acl_filename()); 
local $u;
foreach $u (keys %acl) {
	local @mods = @{$acl{$u}};
	if (!$_[0] || &indexof($u, @{$_[0]}) >= 0) {
		@mods = &unique(@mods, @{$_[1]});
		}
	&print_tempfile(ACL, "$u: ",join(' ', @mods),"\n");
	}
&close_tempfile(ACL);

# Grant to appropriate groups
if ($_[1] && &foreign_check("acl")) {
	&foreign_require("acl", "acl-lib.pl");
	local @groups = &acl::list_groups();
	local @users = &acl::list_users();
	local $g;
	foreach $g (@groups) {
		if (&indexof($g->{'name'}, @{$_[0]}) >= 0) {
			$g->{'modules'} = [ &unique(@{$g->{'modules'}},
					    	    @{$_[1]}) ];
			&acl::modify_group($g->{'name'}, $g);
			&acl::update_members(\@users, \@groups, $g->{'modules'},
					     $g->{'members'});
			}
		}
	}
}

# delete_webmin_module(module, [delete-acls])
# Deletes some webmin module, clone or theme, and return a description of
# the thing deleted.
sub delete_webmin_module
{
local $m = $_[0];
return undef if (!$m);
local %minfo = &get_module_info($m);
%minfo = &get_theme_info($m) if (!%minfo);
return undef if (!%minfo);
local ($mdesc, @aclrm);
@aclrm = ( $m ) if ($_[1]);
if ($minfo{'clone'}) {
	# Deleting a clone
	local %cinfo;
	&read_file("$config_directory/$m/clone", \%cinfo);
	unlink(&module_root_directory($m));
	system("rm -rf $config_directory/$m");
	if ($gconfig{'theme'}) {
		unlink("$root_directory/$gconfig{'theme'}/$m");
		}
	$mdesc = &text('delete_desc1', $minfo{'desc'}, $minfo{'clone'});
	}
else {
	# Delete any clones of this module
	local @clones;
	local $mdir = &module_root_directory($m);
	local @mst = stat($mdir);
	local $r;
	foreach $r (@root_directories) {
		opendir(DIR, $r);
		foreach $l (readdir(DIR)) {
			@lst = stat("$r/$l");
			if (-l "$r/$l" && $lst[1] == $mst[1]) {
				unlink("$r/$l");
				system("rm -rf $config_directory/$l");
				push(@clones, $l);
				}
			}
		closedir(DIR);
		}

	open(TYPE, "$mdir/install-type");
	chop($type = <TYPE>);
	close(TYPE);

	# Run the module's uninstall script
	if (&check_os_support(\%minfo) &&
	    -r "$mdir/uninstall.pl") {
		eval {
			&foreign_require($m, "uninstall.pl");
			&foreign_call($m, "module_uninstall");
			};
		}

	# Deleting the real module
	local $size = &disk_usage_kb($mdir);
	$mdesc = &text('delete_desc2', "<b>$minfo{'desc'}</b>",
			   "<tt>$mdir</tt>", $size);
	if ($type eq 'rpm') {
		# This module was installed from an RPM .. rpm -e it
		&system_logged("rpm -e wbm-$m");
		}
	else {
		# Module was installed from a .wbm file .. just rm it
		&system_logged("rm -rf ".quotemeta($mdir));
		}

	if ($_[1]) {
		# Delete any .acl files
		&system_logged("rm -f $config_directory/$m/*.acl");
		push(@aclrm, @clones);
		}
	}

# Delete from all users and groups
if (@aclrm) {
	&foreign_require("acl", "acl-lib.pl");
	local ($u, $g, $m);
	foreach $u (&acl::list_users()) {
		local $changed;
		foreach $m (@aclrm) {
			local $mi = &indexof($m, @{$u->{'modules'}});
			local $oi = &indexof($m, @{$u->{'ownmods'}});
			splice(@{$u->{'modules'}}, $mi, 1) if ($mi >= 0);
			splice(@{$u->{'ownmods'}}, $oi, 1) if ($oi >= 0);
			$changed++ if ($mi >= 0 || $oi >= 0);
			}
		&acl::modify_user($u->{'name'}, $u) if ($changed);
		}
	foreach $g (&acl::list_groups()) {
		local $changed;
		foreach $m (@aclrm) {
			local $mi = &indexof($m, @{$g->{'modules'}});
			local $oi = &indexof($m, @{$g->{'ownmods'}});
			splice(@{$g->{'modules'}}, $mi, 1) if ($mi >= 0);
			splice(@{$g->{'ownmods'}}, $oi, 1) if ($oi >= 0);
			$changed++ if ($mi >= 0 || $oi >= 0);
			}
		&acl::modify_group($g->{'name'}, $g) if ($changed);
		}
	}

&webmin_log("delete", undef, $m, { 'desc' => $minfo{'desc'} });
return $mdesc;
}

# file_basename(name)
sub file_basename
{
local $rv = $_[0];
$rv =~ s/^.*[\/\\]//;
return $rv;
}

# gnupg_setup()
# Setup gnupg so that rpms and .tar.gz files can be verified.
# Returns 0 if ok, 1 if gnupg is not installed, or 2 if something went wrong
# Assumes that gnupg-lib.pl is available
sub gnupg_setup
{
return ( 1, &text('enogpg', "<tt>gpg</tt>") ) if (!&has_command("gpg"));

# Check if we already have the key
local @keys = &list_keys();
foreach $k (@keys) {
	return ( 0 ) if ($k->{'email'}->[0] eq $webmin_key_email &&
		         &key_fingerprint($k) eq $webmin_key_fingerprint);
	}

# Import it if not
&list_keys();
$out = `gpg --import $module_root_directory/jcameron-key.asc 2>&1`;
if ($?) {
	return (2, $out);
	}
return 0;
}

# list_standard_modules()
# Returns a list containing the short names, URLs and descriptions of the
# standard Webmin modules from www.webmin.com. If an error occurs, returns the
# message instead.
sub list_standard_modules
{
local $temp = &transname();
local $error;
local ($host, $port, $page, $ssl);
if ($config{'standard_url'}) {
	($host, $port, $page, $ssl) = &parse_http_url($config{'standard_url'});
	return $text{'standard_eurl'} if (!$host);
	}
else {
	($host, $port, $page, $ssl) = ($standard_host, $standard_port,
				       $standard_page, $standard_ssl);
	}
&http_download($host, $port, $page, $temp, \$error);
return $error if ($error);
local @rv;
open(TEMP, $temp);
while(<TEMP>) {
	s/\r|\n//g;
	local @l = split(/\t+/, $_);
	push(@rv, \@l);
	}
close(TEMP);
unlink($temp);
return \@rv;
}

# standard_chooser_button(input, [form])
sub standard_chooser_button
{
local $form = @_ > 1 ? $_[1] : 0;
return "<input type=button onClick='ifield = document.forms[$form].$_[0]; chooser = window.open(\"standard_chooser.cgi?mod=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=600,height=300\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

# list_third_modules()
# Returns a list containing the names, versions, URLs and descriptions of the
# third-party Webmin modules from thirdpartymodules.webmin.com. If an error
# occurs, returns the message instead.
sub list_third_modules
{
local $temp = &transname();
local $error;
local ($host, $port, $page, $ssl);
if ($config{'third_url'}) {
	($host, $port, $page, $ssl) = &parse_http_url($config{'third_url'});
	return $text{'third_eurl'} if (!$host);
	}
else {
	($host, $port, $page, $ssl) = ($third_host, $third_port,
				       $third_page, $third_ssl);
	}
&http_download($host, $port, $page, $temp, \$error);
return $error if ($error);
local @rv;
open(TEMP, $temp);
while(<TEMP>) {
	s/\r|\n//g;
	local @l = split(/\t+/, $_);
	push(@rv, \@l);
	}
close(TEMP);
unlink($temp);
return \@rv;
}

# third_chooser_button(input, [form])
sub third_chooser_button
{
local $form = @_ > 1 ? $_[1] : 0;
return "<input type=button onClick='ifield = document.forms[$form].$_[0]; chooser = window.open(\"third_chooser.cgi?mod=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=700,height=300\"); chooser.ifield = ifield; window.ifield = ifield' value=\"$text{'mods_thsel'}\">\n";
}

# get_webmin_base_version()
# Gets the webmin version, rounded to the nearest .01
sub get_webmin_base_version
{
return &base_version(&get_webmin_version());
}

# base_version()
# Rounds a version number down to the nearest .01
sub base_version
{
return sprintf("%.2f0", $_[0] - 0.005);
}

$newmodule_users_file = "$config_directory/newmodules";

# get_newmodule_users()
# Returns a ref to an array of users to whom new modules are granted, or undef
sub get_newmodule_users
{
if (open(NEWMODS, $newmodule_users_file)) {
	local @rv;
	while(<NEWMODS>) {
		s/\r|\n//g;
		push(@rv, $_) if (/\S/);
		}
	close(NEWMODS);
	return \@rv;
	}
else {
	return undef;
	}
}

# save_newmodule_users(&users)
# Saves the list of users to whom new modules are granted. If undef is given,
# the default behavious is used
sub save_newmodule_users
{
&lock_file($newmodule_users_file);
if ($_[0]) {
	&open_tempfile(NEWMODS, ">$newmodule_users_file");
	foreach $u (@{$_[0]}) {
		&print_tempfile(NEWMODS, "$u\n");
		}
	&close_tempfile(NEWMODS);
	}
else {
	unlink($newmodule_users_file);
	}
&unlock_file($newmodule_users_file);
}

# get_miniserv_sockets(&miniserv)
sub get_miniserv_sockets
{
local @sockets;
push(@sockets, [ $_[0]->{'bind'} || "*", $_[0]->{'port'} ]);
foreach $s (split(/\s+/, $_[0]->{'sockets'})) {
	if ($s =~ /^(\d+)$/) {
		# Just listen on another port on the main IP
		push(@sockets, [ $sockets[0]->[0], $s ]);
		}
	elsif ($s =~ /^(\S+):(\d+)$/) {
		# Listen on a specific port and IP
		push(@sockets, [ $1, $2 ]);
		}
	elsif ($s =~ /^([0-9\.]+):\*$/ || $s =~ /^([0-9\.]+)$/) {
		# Listen on the main port on another IP
		push(@sockets, [ $1, "*" ]);
		}
	}
return @sockets;
}

# fetch_updates(url, [login, pass])
# Returns a list of updates from some URL, or calls &error.
# Format is  module version url support description
sub fetch_updates
{
local ($host, $port, $page, $ssl) = &parse_http_url($_[0]);
$host || &error($text{'update_eurl'});

local $temp = &transname();
local @updates;
&http_download($host, $port, $page, $temp, undef, undef, $ssl, $_[1], $_[2]);
open(UPDATES, $temp);
while(<UPDATES>) {
	if (/^([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+(.*)/) {
		push(@updates, [ $1, $2, $3, $4, $5 ]);
		}
	}
close(UPDATES);
unlink($temp);
@updates || &error($text{'update_efile'});

return ( \@updates, $host, $port, $page, $ssl );
}

# find_cron_job(\@jobs)
sub find_cron_job
{
local ($job) = grep { $_->{'user'} eq 'root' &&
		      $_->{'command'} eq $cron_cmd } @{$_[0]};
return $job;
}

# get_ipkeys(&miniserv)
# Returns a list of IP address to key file mappings from a miniserv.conf entry
sub get_ipkeys
{
local (@rv, $k);
foreach $k (keys %{$_[0]}) {
	if ($k =~ /^ipkey_(\S+)/) {
		local $ipkey = { 'ips' => [ split(/,/, $1) ],
				 'key' => $_[0]->{$k},
				 'index' => scalar(@rv) };
		$ipkey->{'cert'} = $_[0]->{'ipcert_'.$1};
		push(@rv, $ipkey);
		}
	}
return @rv;
}

# save_ipkeys(&miniserv, &keys)
# Updates miniserv.conf entries from the given list of keys
sub save_ipkeys
{
local $k;
foreach $k (keys %{$_[0]}) {
	if ($k =~ /^(ipkey_|ipcert_)/) {
		delete($_[0]->{$k});
		}
	}
foreach $k (@{$_[1]}) {
	local $ips = join(",", @{$k->{'ips'}});
	$_[0]->{'ipkey_'.$ips} = $k->{'key'};
	if ($k->{'cert'}) {
		$_[0]->{'ipcert_'.$ips} = $k->{'cert'};
		}
	}
}

# validate_key_cert(key, [cert])
# Call &error if some key and cert file don't look correct
sub validate_key_cert
{
local $key = &read_file_contents($_[0]);
$key =~ /BEGIN RSA PRIVATE KEY/i || &error(&text('ssl_ekey', $_[0]));
if (!$_[1]) {
	$key =~ /BEGIN CERTIFICATE/ || &error(&text('ssl_ecert', $_[0]));
	}
else {
	local $cert = &read_file_contents($_[1]);
	$cert =~ /BEGIN CERTIFICATE/ || &error(&text('ssl_ecert', $_[1]));
	}
}

# detect_operating_system([os-list-file], [with-cache])
# Returns a hash containing os_type, os_version, real_os_type and
# real_os_version
sub detect_operating_system
{
local $file = $_[0] || "$root_directory/os_list.txt";
local $cache = $_[1];
if ($cache) {
	# Check the cache file, and only re-check the OS if older than
	# 1 day, or if we have rebooted recently
	local %cache;
	local $uptime = &get_system_uptime();
	local $lastreboot = $uptime ? time()-$uptime : undef;
	if (&read_file($detect_operating_system_cache, \%cache) &&
	    $cache{'os_type'} && $cache{'os_version'} &&
	    $cache{'real_os_type'} && $cache{'real_os_version'}) {
		if ($cache{'time'} > time()-24*60*60 &&
		    $cache{'time'} > $lastreboot) {
			return %cache;
			}
		}
	}
local $temp = &transname();
local $perl = &get_perl_path();
system("$perl $root_directory/oschooser.pl $file $temp 1");
local %rv;
&read_env_file($temp, \%rv);
$rv{'time'} = time();
&write_file($detect_operating_system_cache, \%rv);
return %rv;
}

# get_system_uptime()
# Returns the number of seconds the system has been up, or undef if un-available
sub get_system_uptime
{
# Try Linux /proc/uptime first
if (open(UPTIME, "/proc/uptime")) {
	local $line = <UPTIME>;
	close(UPTIME);
	local ($uptime, $dummy) = split(/\s+/, $line);
	if ($uptime > 0) {
		return int($uptime);
		}
	}

# Try to parse uptime command output
if ($gconfig{'os_type'} ne 'windows') {
	local $out = &backquote_command("uptime");
	if ($out =~ /up\s+(\d+)\s+day/) {
		return $1*24*60*60;
		}
	elsif ($out =~ /up\s+(\d+)\s+min/) {
		return $1*60;
		}
	elsif ($out =~ /up\s+(\d+)\s+hour/) {
		return $1*60*60;
		}
	elsif ($out =~ /up\s+(\d+):(\d+)/) {
		return $1*60*60 + $2*60;
		}
	}

return undef;
}

# list_operating_systems([os-list-file])
# Returns a list of know OS's
sub list_operating_systems
{
local $file = $_[0] || "$root_directory/os_list.txt";
local @rv;
open(OSLIST, $file);
while(<OSLIST>) {
	if (/^([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+(.*)/) {
		push(@rv, { 'realtype' => $1,
			    'realversion' => $2,
			    'type' => $3,
			    'version' => $4,
			    'code' => $5 });
		}
	}
close(OSLIST);
return @rv;
}

# shared_root_directory()
# Returns 1 if the Webmin root directory is shared with another system, such as
# via NFS, or in a Solaris zone. If so, updates and module installs are not
# allowed.
sub shared_root_directory
{
return 1 if ($gconfig{'shared_root'});
if (&running_in_zone()) {
	# In a Solaris zone .. is the root directory loopback mounted?
	if (&foreign_exists("mount")) {
		&foreign_require("mount", "mount-lib.pl");
		local @rst = stat($root_directory);
		local $m;
		foreach $m (&mount::list_mounted()) {
			local @mst = stat($m->[0]);
			if ($mst[0] == $rst[0] &&
			    &is_under_directory($m->[0], $root_directory)) {
				# Found the mount!
				if ($m->[2] eq "lofs" || $m->[2] eq "nfs") {
					return 1;
					}
				}
			}
		}
	}
return 0;
}

# submit_os_info(id)
# Send via email a message about this system's OS and Perl version. Returns
# undef if OK, or an error message
sub submit_os_info
{
if (!&foreign_installed("mailboxes", 1)) {
	return $text{'submit_emailboxes'};
	}
&foreign_require("mailboxes", "mailboxes-lib.pl");
local $mail = { 'headers' => [ [ 'From', &mailboxes::get_from_address() ],
			       [ 'To', $os_info_address ],
			       [ 'Subject', 'Webmin OS Information' ] ],
		'attach' => [ {
		   'headers' => [ [ 'Content-type', 'text/plain' ] ],
		   'data' => "OS: $gconfig{'real_os_type'}\n".
			     "Version: $gconfig{'real_os_version'}\n".
		 	     "OS code: $gconfig{'os_type'}\n".
		 	     "Version code: $gconfig{'os_version'}\n".
			     "Perl: $]\n".
			     "Webmin: ".&get_webmin_version()."\n".
			     "ID: ".&get_webmin_id()."\n" } ],
		};
eval { &mailboxes::send_mail($mail); };
return $@ ? $@ : undef;
}

# get_webmin_id()
# Returns a (hopefully) unique ID for this Webmin install
sub get_webmin_id
{
if (!$config{'webminid'}) {
	local $salt = substr(time(), -2);
	$config{'webminid'} = &unix_crypt(&get_system_hostname(), $salt);
	&save_module_config();
	}
return $config{'webminid'};
}

# ip_match(ip, [match]+)
# Checks an IP address against a list of IPs, networks and networks/masks
sub ip_match
{
local(@io, @mo, @ms, $i, $j);
@io = split(/\./, $_[0]);
local $hn = gethostbyaddr(inet_aton($_[0]), AF_INET);
undef($hn) if ((&to_ipaddress($hn))[0] ne $_[0]);
for($i=1; $i<@_; $i++) {
	local $mismatch = 0;
	local $ip = $_[$i];
        if ($ip =~ /^(\S+)\/(\d+)$/) {
                # Convert CIDR to netmask format
                $ip = $1."/".&prefix_to_mask($2);
                }
	if ($ip =~ /^(\S+)\/(\S+)$/) {
		# Compare with network/mask
		@mo = split(/\./, $1); @ms = split(/\./, $2);
		for($j=0; $j<4; $j++) {
			if ((int($io[$j]) & int($ms[$j])) != int($mo[$j])) {
				$mismatch = 1;
				}
			}
		}
	elsif ($ip =~ /^\*(\.\S+)$/) {
		# Compare with hostname regexp
		$mismatch = 1 if ($hn !~ /$1$/);
		}
	elsif ($ip eq 'LOCAL') {
		# Just assume OK for now
		}
	elsif ($ip !~ /^[0-9\.]+$/) {
		# Compare with hostname
		$mismatch = 1 if ($_[0] ne &to_ipaddress($ip));
		}
	else {
		# Compare with IP or network
		@mo = split(/\./, $ip);
		while(@mo && !$mo[$#mo]) { pop(@mo); }
		for($j=0; $j<@mo; $j++) {
			if ($mo[$j] != $io[$j]) {
				$mismatch = 1;
				}
			}
		}
	return 1 if (!$mismatch);
	}
return 0;
}

# prefix_to_mask(prefix)
# Converts a number like 24 to a mask like 255.255.255.0
sub prefix_to_mask
{
return $_[0] >= 24 ? "255.255.255.".(256-(2 ** (32-$_[0]))) :
       $_[0] >= 16 ? "255.255.".(256-(2 ** (24-$_[0]))).".0" :
       $_[0] >= 16 ? "255.".(256-(2 ** (16-$_[0]))).".0.0" :
                     (256-(2 ** (8-$_[0]))).".0.0.0";
}

# valid_allow(text)
# Returns undef if some text is a valid IP, hostname or network for use in
# allowed IPs, or an error message if not
sub valid_allow
{
local ($h) = @_;
local $i;
if ($h =~ /^([0-9\.]+)\/(\d+)$/) {
	&check_ipaddress($1) ||
		return &text('access_enet', "$1");
	$2 >= 0 && $2 <= 32 ||
		return &text('access_ecidr', "$2");
	}
elsif ($h =~ /^([0-9\.]+)\/([0-9\.]+)$/) {
	&check_ipaddress($1) ||
		return &text('access_enet', "$1");
	&check_ipaddress($2) ||
		return &text('access_emask', "$2");
	}
elsif ($h =~ /^[0-9\.]+$/) {
	&check_ipaddress($h) ||
		return &text('access_eip', $h);
	}
elsif ($h =~ /^\*\.(\S+)$/) {
	# *.domain is OK
	}
elsif ($h eq 'LOCAL') {
	# Local means any on local nets
	}
elsif ($i = join('.', unpack("CCCC", inet_aton($h)))) {
	# Resolve a hostname
	$h = $i;
	}
else {
	return &text('access_ehost', $h);
	}
return undef;
}

# get_preloads(&miniserv)
# Returns a list of module names and files to pre-load
sub get_preloads
{
local @rv = map { [ split(/=/, $_) ] } split(/\s+/, $_[0]->{'preload'});
return @rv;
}

# save_preloads(&miniserv, &preloads)
sub save_preloads
{
$_[0]->{'preload'} = join(" ", map { "$_->[0]=$_->[1]" } @{$_[1]});
}

# get_tempdirs(&gconfig)
# Returns a list of per-module temp directories
sub get_tempdirs
{
local ($gconfig) = @_;
local @rv;
foreach my $k (keys %$gconfig) {
	if ($k =~ /^tempdir_(.*)$/) {
		push(@rv, [ $1, $gconfig->{$k} ]);
		}
	}
return sort { $a->[0] cmp $b->[0] } @rv;
}

# save_tempdirs(&gconfig, &tempdirs)
# Updates the global config with a list of per-module temp dirs
sub save_tempdirs
{
local ($gconfig, $dirs) = @_;
foreach my $k (keys %$gconfig) {
	if ($k =~ /^tempdir_(.*)$/) {
		delete($gconfig->{$k});
		}
	}
foreach my $d (@$dirs) {
	$gconfig->{'tempdir_'.$d->[0]} = $d->[1];
	}
}

# get_module_install_type(dir)
# Returns the installation method used for some module (such as 'rpm'), or undef
# if it was installed from a .wbm
sub get_module_install_type
{
local ($mod) = @_;
local $it = &module_root_directory($mod)."/install-type";
open(TYPE, $it) || return undef;
local $type = <TYPE>;
chop($type);
close(TYPE);
return $type;
}

# get_install_type()
# Returns the package type Webmin was installed form (rpm, deb, solaris-pkg
# or undef for tar.gz)
sub get_install_type
{
local $mode;
if (open(MODE, "$root_directory/install-type")) {
	chop($mode = <MODE>);
	close(MODE);
	}
else {
	if ($root_directory eq "/usr/libexec/webmin") {
		$mode = "rpm";
		}
	elsif ($root_directory eq "/usr/shard/webmin") {
		$mode = "deb";
		}
	elsif ($root_directory eq "/opt/webmin") {
		$mode = "solaris-pkg";
		}
	else {
		$mode = undef;
		}
	}
return $mode;
}

# list_cached_files()
# Returns a list of cached filenames, full paths and urls
sub list_cached_files
{
local @rv;
opendir(DIR, $main::http_cache_directory);
foreach my $cfile (readdir(DIR)) {
	next if ($cfile eq "." || $cfile eq "..");
	$curl = $cfile;
	$curl =~ s/_/\//g;
	push(@rv, [ $cfile, "$main::http_cache_directory/$cfile", $curl ]);
	}
closedir(DIR);
return @rv;
}

sub show_restart_page
{
&ui_print_header(undef, $text{'restart_title'}, "");

print "<p>$text{'restart_done'}<p>\n";

&ui_print_footer("", $text{'index_return'});
&restart_miniserv(1);
}

1;
