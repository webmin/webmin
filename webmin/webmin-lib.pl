=head1 webmin-lib.pl

Common functions for configuring miniserv and adjusting global Webmin settings.

=cut

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
&init_config();
our ($module_root_directory, %text, %gconfig, $root_directory, %config,
     $module_name, $remote_user, $base_remote_user, $gpgpath,
     $module_config_directory, @lang_order_list, @root_directories);
do "$module_root_directory/gnupg-lib.pl";
use Socket;

our @cs_codes = ( 'cs_page', 'cs_text', 'cs_table', 'cs_header', 'cs_link' );
our @cs_names = map { $text{$_} } @cs_codes;

our $osdn_host = "prdownloads.sourceforge.net";
our $osdn_port = 80;

our $update_host = "www.webmin.com";
our $update_port = 80;
our $update_page = "/updates/updates.txt";
our $update_url = "http://$update_host:$update_port$update_page";
our $redirect_url = "http://$update_host/cgi-bin/redirect.cgi";
our $update_cache = "$module_config_directory/update-cache";

our $webmin_key_email = "jcameron\@webmin.com";
our $webmin_key_fingerprint = "1719 003A CE3E 5A41 E2DE  70DF D97A 3AE9 11F6 3C51";

our $standard_host = $update_host;
our $standard_port = $update_port;
our $standard_page = "/download/modules/standard.txt";
our $standard_ssl = 0;

our $third_host = $update_host;
our $third_port = $update_port;
our $third_page = "/cgi-bin/third.cgi";
our $third_ssl = 0;

our $default_key_size = "2048";

our $cron_cmd = "$module_config_directory/update.pl";

our $os_info_address = "os\@webmin.com";

our $detect_operating_system_cache = "$module_config_directory/oscache";

our @webmin_date_formats = ( "dd/mon/yyyy", "dd/mm/yyyy",
			     "mm/dd/yyyy", "yyyy/mm/dd",
			     "d. mon yyyy", "dd.mm.yyyy", "yyyy-mm-dd" );

our @debug_what_events = ( 'start', 'read', 'write', 'ops', 'procs', 'diff', 'cmd', 'net', 'sql' );

our $record_login_cmd = "$config_directory/login.pl";
our $record_logout_cmd = "$config_directory/logout.pl";

our $strong_ssl_ciphers = "ALL:!aNULL:!ADH:!eNULL:!LOW:!EXP:RC4+RSA:+HIGH:+MEDIUM";

our $newmodule_users_file = "$config_directory/newmodules";

=head2 setup_ca

Internal function to create all the configuration files needed for the Webmin
client SSL certificate CA.

=cut
sub setup_ca
{
my ($miniserv) = @_;
my $adir = &module_root_directory("acl");
my $conf = &read_file_contents("$adir/openssl.cnf");
my $acl = "$config_directory/acl";
$conf =~ s/DIRECTORY/$acl/g;

&lock_file("$acl/openssl.cnf");
my $cfh;
&open_tempfile($cfh, ">$acl/openssl.cnf");
&print_tempfile($cfh, $conf);
&close_tempfile($cfh);
chmod(0600, "$acl/openssl.cnf");
&unlock_file("$acl/openssl.cnf");

&lock_file("$acl/index.txt");
my $ifh;
&open_tempfile($ifh, ">$acl/index.txt");
&close_tempfile($ifh);
chmod(0600, "$acl/index.txt");
&unlock_file("$acl/index.txt");

&lock_file("$acl/serial");
my $sfh;
&open_tempfile($sfh, ">$acl/serial");
&print_tempfile($sfh, "011E\n");
&close_tempfile($sfh);
chmod(0600, "$acl/serial");
&unlock_file("$acl/serial");

&lock_file("$acl/newcerts");
mkdir("$acl/newcerts", 0700);
chmod(0700, "$acl/newcerts");
&unlock_file("$acl/newcerts");
$miniserv->{'ca'} = "$acl/ca.pem";
}

=head2 install_webmin_module(file, unlink, nodeps, &users|groups)

Installs a webmin module or theme, and returns either an error message
or references to three arrays for descriptions, directories and sizes.
On success or failure, the file is deleted if the unlink parameter is set.
Unless the nodeps parameter is set to 1, any missing dependencies will cause
installation to fail. 

Any new modules will be granted to the users and groups named in the fourth
paramter, which must be an array reference.

=cut
sub install_webmin_module
{
my ($file, $need_unlink, $nodeps, $grant) = @_;
my (@mdescs, @mdirs, @msizes);
my (@newmods, $m);
my $install_root_directory = $gconfig{'install_root'} || $root_directory;

# Uncompress the module file if needed
my $two;
open(MFILE, $file);
read(MFILE, $two, 2);
close(MFILE);
if ($two eq "\037\235") {
	if (!&has_command("uncompress")) {
		unlink($file) if ($need_unlink);
		return &text('install_ecomp', "<tt>uncompress</tt>");
		}
	my $temp = $file =~ /\/([^\/]+)\.Z/i ? &transname("$1")
						: &transname();
	my $out = `uncompress -c "$file" 2>&1 >$temp`;
	unlink($file) if ($need_unlink);
	if ($?) {
		unlink($temp);
		return &text('install_ecomp2', $out);
		}
	$file = $temp;
	$need_unlink = 1;
	}
elsif ($two eq "\037\213") {
	if (!&has_command("gunzip") && !&has_command("gzip")) {
		unlink($file) if ($need_unlink);
		return &text('install_egzip', "<tt>gunzip</tt>");
		}
	my $temp = $file =~ /\/([^\/]+)\.gz/i ? &transname("$1")
						 : &transname();
	my $cmd = &has_command("gunzip") ? "gunzip -c" : "gzip -d -c";
	my $out = &backquote_command($cmd." ".&quote_path($file).
					"  2>&1 >$temp");
	unlink($file) if ($need_unlink);
	if ($? || !-s $temp) {
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
	my $temp = $file =~ /\/([^\/]+)\.gz/i ? &transname("$1")
						 : &transname();
	my $out = `bunzip2 -c "$file" 2>&1 >$temp`;
	unlink($file) if ($need_unlink);
	if ($?) {
		unlink($temp);
		return &text('install_ebunzip2', $out);
		}
	$file = $temp;
	$need_unlink = 1;
	}

# Check if this is an RPM webmin module or theme
my ($type, $redirect_to);
open(TYPE, "$root_directory/install-type");
chop($type = <TYPE>);
close(TYPE);
my $out;
if ($type eq 'rpm' && $file =~ /\.rpm$/i &&
    ($out = &backquote_command("rpm -qp $file 2>/dev/null"))) {
	# Looks like an RPM of some kind, hopefully an RPM webmin module
	# or theme
	my (%minfo, %tinfo, $name);
	if ($out !~ /(^|\n)(wbm|wbt)-([a-z\-]+[a-z])/) {
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
	&flush_webmin_caches();

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
	my (%mods, %hasfile);
	&has_command("tar") || return $text{'install_enotar'};
	my $tar = &backquote_command("tar tf ".&quote_path($file)." 2>&1");
	if ($?) {
		unlink($file) if ($need_unlink);
		return &text('install_etar', $tar);
		}
	foreach my $f (split(/\n/, $tar)) {
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

	# Get the module.info or theme.info files to check dependancies
	my $ver = &get_webmin_version();
	my $tmpdir = &transname();
	mkdir($tmpdir, 0700);
	my $err;
	my @realmods;
	foreach $m (keys %mods) {
		next if (!$hasfile{$m,"module.info"} &&
			 !$hasfile{$m,"theme.info"});
		push(@realmods, $m);
		my %minfo;
		system("cd $tmpdir ; tar xf \"$file\" $m/module.info ./$m/module.info $m/theme.info ./$m/theme.info >/dev/null 2>&1");
		if (!&read_file("$tmpdir/$m/module.info", \%minfo) &&
		    !&read_file("$tmpdir/$m/theme.info", \%minfo)) {
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
			my $deps = $minfo{'webmin_depends'} ||
				      $minfo{'depends'};
			foreach my $dep (split(/\s+/, $deps)) {
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
					my ($dmod, $dver) = ($1, $2);
					my %dinfo = &get_module_info($dmod);
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
			foreach my $dep (split(/\s+/, $minfo{'perldepends'})) {
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
	my $oldpwd = &get_current_dir();
	chdir($root_directory);
	my @grantmods;
	foreach $m (@realmods) {
		push(@grantmods, $m) if (!&foreign_exists($m));
		if ($m ne "webmin") {
			system("rm -rf ".quotemeta("$install_root_directory/$m")." 2>&1 >/dev/null");
			}
		}

	# Extract all the modules and update perl path and ownership
	my $out = `cd $install_root_directory ; tar xf "$file" 2>&1 >/dev/null`;
	chdir($oldpwd);
	if ($?) {
		unlink($file) if ($need_unlink);
		return &text('install_eextract', $out);
		}
	if ($need_unlink) { unlink($file); }
	my $perl = &get_perl_path();
	my @st = stat("$module_root_directory/index.cgi");
	foreach my $moddir (keys %mods) {
		my $pwd = &module_root_directory($moddir);
		if ($hasfile{$moddir,"module.info"}) {
			my %minfo = &get_module_info($moddir);
			push(@mdescs, $minfo{'desc'});
			push(@mdirs, $pwd);
			push(@msizes, &disk_usage_kb($pwd));
			&webmin_log("install", undef, $moddir,
				    { 'desc' => $minfo{'desc'} });
			push(@newmods, $moddir);
			}
		else {
			my %tinfo = &get_theme_info($moddir);
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
	my @permmods = grep { !-d "$config_directory/$_" } @newmods;
	system("cd $root_directory ; $perl $root_directory/copyconfig.pl '$gconfig{'os_type'}/$gconfig{'real_os_type'}' '$gconfig{'os_version'}/$gconfig{'real_os_version'}' '$install_root_directory' '$config_directory' ".join(' ', @realmods)." >/dev/null");

	# Set correct permissions on *new* config directory
	if (&supports_users()) {
		foreach my $m (@permmods) {
			system("chown -R root $config_directory/$m");
			system("chgrp -R bin $config_directory/$m");
			system("chmod -R og-rw $config_directory/$m");
			}
		}

	# Update ACL for this user so they can access the new modules
	&grant_user_module($grant, \@grantmods);
	}
&flush_webmin_caches();

# Run post-install scripts
foreach $m (@newmods) {
	next if (!-r &module_root_directory($m)."/postinstall.pl");
	eval {
		local $main::error_must_die = 1;
		&foreign_require($m, "postinstall.pl");
		&foreign_call($m, "module_install");
		};
	}

return [ \@mdescs, \@mdirs, \@msizes ];
}

=head2 grant_user_module(&users/groups, &modules)

Grants users or groups access to a set of modules. The users parameter must
be an array ref of usernames or group names, and modules must be an array
ref of module names.

=cut
sub grant_user_module
{
# Grant to appropriate users
my %acl;
&read_acl(undef, \%acl);
my $fh;
&open_tempfile($fh, ">".&acl_filename()); 
my $u;
foreach $u (keys %acl) {
	my @mods = @{$acl{$u}};
	if (!$_[0] || &indexof($u, @{$_[0]}) >= 0) {
		@mods = &unique(@mods, @{$_[1]});
		}
	&print_tempfile($fh, "$u: ",join(' ', @mods),"\n");
	}
&close_tempfile($fh);

# Grant to appropriate groups
if ($_[1] && &foreign_check("acl")) {
	&foreign_require("acl", "acl-lib.pl");
	my @groups = &acl::list_groups();
	my @users = &acl::list_users();
	foreach my $g (@groups) {
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

=head2 delete_webmin_module(module, [delete-acls])

Deletes some webmin module, clone or theme, and return a description of
the thing deleted. If the delete-acls flag is set, all .acl files are
removed too.

=cut
sub delete_webmin_module
{
my $m = $_[0];
return undef if (!$m);
my %minfo = &get_module_info($m);
%minfo = &get_theme_info($m) if (!%minfo);
return undef if (!%minfo);
my ($mdesc, @aclrm);
@aclrm = ( $m ) if ($_[1]);
if ($minfo{'clone'}) {
	# Deleting a clone
	my %cinfo;
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
	my @clones;
	my $mdir = &module_root_directory($m);
	my @mst = stat($mdir);
	foreach my $r (@root_directories) {
		opendir(DIR, $r);
		foreach my $l (readdir(DIR)) {
			my @lst = stat("$r/$l");
			if (-l "$r/$l" && $lst[1] == $mst[1]) {
				unlink("$r/$l");
				system("rm -rf $config_directory/$l");
				push(@clones, $l);
				}
			}
		closedir(DIR);
		}

	my $type;
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
	my $size = &disk_usage_kb($mdir);
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
	my ($u, $g, $m);
	foreach $u (&acl::list_users()) {
		my $changed;
		foreach $m (@aclrm) {
			my $mi = &indexof($m, @{$u->{'modules'}});
			my $oi = &indexof($m, @{$u->{'ownmods'}});
			splice(@{$u->{'modules'}}, $mi, 1) if ($mi >= 0);
			splice(@{$u->{'ownmods'}}, $oi, 1) if ($oi >= 0);
			$changed++ if ($mi >= 0 || $oi >= 0);
			}
		&acl::modify_user($u->{'name'}, $u) if ($changed);
		}
	foreach $g (&acl::list_groups()) {
		my $changed;
		foreach $m (@aclrm) {
			my $mi = &indexof($m, @{$g->{'modules'}});
			my $oi = &indexof($m, @{$g->{'ownmods'}});
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

=head2 file_basename(name)

Returns the part of a filename after the last /.

=cut
sub file_basename
{
my $rv = $_[0];
$rv =~ s/^.*[\/\\]//;
return $rv;
}

=head2 gnupg_setup

Setup gnupg so that rpms and .tar.gz files can be verified.
Returns 0 if ok, 1 if gnupg is not installed, or 2 if something went wrong
Assumes that gnupg-lib.pl is available

=cut
sub gnupg_setup
{
return ( 1, &text('enogpg', "<tt>gpg</tt>") ) if (!&has_command($gpgpath));

# Check if we already have the key
my @keys = &list_keys();
foreach my $k (@keys) {
	return ( 0 ) if ($k->{'email'}->[0] eq $webmin_key_email &&
		         &key_fingerprint($k) eq $webmin_key_fingerprint);
	}

# Import it if not
&list_keys();
my $out = &backquote_logged(
	"$gpgpath --import $module_root_directory/jcameron-key.asc 2>&1");
if ($?) {
	return (2, $out);
	}
return 0;
}

=head2 list_standard_modules

Returns a list containing the short names, URLs and descriptions of the
standard Webmin modules from www.webmin.com. If an error occurs, returns the
message instead.

=cut
sub list_standard_modules
{
my $temp = &transname();
my $error;
my ($host, $port, $page, $ssl);
if ($config{'standard_url'}) {
	($host, $port, $page, $ssl) = &parse_http_url($config{'standard_url'});
	return $text{'standard_eurl'} if (!$host);
	}
else {
	($host, $port, $page, $ssl) = ($standard_host, $standard_port,
				       $standard_page, $standard_ssl);
	}
&http_download($host, $port, $page, $temp, \$error, undef, $ssl);
return $error if ($error);
my @rv;
open(TEMP, $temp);
while(<TEMP>) {
	s/\r|\n//g;
	my @l = split(/\t+/, $_);
	push(@rv, \@l);
	}
close(TEMP);
unlink($temp);
return \@rv;
}

=head2 standard_chooser_button(input, [form])

Returns HTML for a popup button for choosing a standard module.

=cut
sub standard_chooser_button
{
return &popup_window_button("standard_chooser.cgi", 800, 500, 1,
	[ [ "ifield", $_[0], "mod" ] ]);
}

=head2 list_third_modules

Returns a list containing the names, versions, URLs and descriptions of the
third-party Webmin modules from thirdpartymodules.webmin.com. If an error
occurs, returns the message instead.

=cut
sub list_third_modules
{
my $temp = &transname();
my $error;
my ($host, $port, $page, $ssl);
if ($config{'third_url'}) {
	($host, $port, $page, $ssl) = &parse_http_url($config{'third_url'});
	return $text{'third_eurl'} if (!$host);
	}
else {
	($host, $port, $page, $ssl) = ($third_host, $third_port,
				       $third_page, $third_ssl);
	}
&http_download($host, $port, $page, $temp, \$error, undef, $ssl);
return $error if ($error);
my @rv;
open(TEMP, $temp);
while(<TEMP>) {
	s/\r|\n//g;
	my @l = split(/\t+/, $_);
	push(@rv, \@l);
	}
close(TEMP);
unlink($temp);
return \@rv;
}

=head2 third_chooser_button(input, [form])

Returns HTML for a popup button for choosing a third-party module.

=cut
sub third_chooser_button
{
return &popup_window_button("third_chooser.cgi", 800, 500, 1,
	[ [ "ifield", $_[0], "mod" ] ]);
}

=head2 get_webmin_base_version

Gets the webmin version, rounded to the nearest .01

=cut
sub get_webmin_base_version
{
return &base_version(&get_webmin_version());
}

=head2 base_version

Rounds a version number down to the nearest .01

=cut
sub base_version
{
return sprintf("%.2f0", $_[0] - 0.005);
}

=head2 get_newmodule_users

Returns a ref to an array of users to whom new modules are granted by default,
or undef if the admin hasn't chosen any yet.

=cut
sub get_newmodule_users
{
if (open(NEWMODS, $newmodule_users_file)) {
	my @rv;
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

=head2 save_newmodule_users(&users)

Saves the list of users to whom new modules are granted. If undef is given,
the default behaviour (of using root or admin) is used.

=cut
sub save_newmodule_users
{
&lock_file($newmodule_users_file);
if ($_[0]) {
	my $fh;
	&open_tempfile($fh, ">$newmodule_users_file");
	foreach my $u (@{$_[0]}) {
		&print_tempfile($fh, "$u\n");
		}
	&close_tempfile($fh);
	}
else {
	unlink($newmodule_users_file);
	}
&unlock_file($newmodule_users_file);
}

=head2 get_miniserv_sockets(&miniserv)

Returns an array of tuple refs, each of which contains an IP address and port
number that Webmin listens on. The IP can be * (meaning any), and the port can
be * (meaning the primary port).

=cut
sub get_miniserv_sockets
{
my @sockets;
push(@sockets, [ $_[0]->{'bind'} || "*", $_[0]->{'port'} ]);
foreach my $s (split(/\s+/, $_[0]->{'sockets'} || "")) {
	if ($s =~ /^(\d+)$/) {
		# Just listen on another port on the main IP
		push(@sockets, [ $sockets[0]->[0], $s ]);
		}
	elsif ($s =~ /^(\S+):(\d+)$/) {
		# Listen on a specific port and IP
		push(@sockets, [ $1, $2 ]);
		}
	elsif ($s =~ /^([0-9\.]+):\*$/ || $s =~ /^([0-9\.]+)$/ ||
	       $s =~ /^([a-f0-9:]+):\*$/ || $s =~ /^([a-f0-9:]+)$/) {
		# Listen on the main port on another IP
		push(@sockets, [ $1, "*" ]);
		}
	}
return @sockets;
}

=head2 fetch_updates(url, [login, pass], [sig-mode])

Returns a list of updates from some URL, or calls &error. Each element is an 
array reference containing :

=item Module directory name.

=item Version number.

=item Absolute or relative download URL.

=item Operating systems the update is relevant for, in the same format as the os_support line in a module.info file.

=item Human-readable description of the update.

The parameters are :

=item url - Full URL to download updates from.

=item login - Optional login for the URL.

=item pass - Optional password for the URL.

=item sig-mode - 0=No check, 1=Check if possible, 2=Must check

=cut
sub fetch_updates
{
my ($url, $user, $pass, $sigmode) = @_;
my ($host, $port, $page, $ssl) = &parse_http_url($url);
$host || &error($text{'update_eurl'});

# Download the file
my $temp = &transname();
&http_download($host, $port, $page, $temp, undef, undef, $ssl, $user, $pass,
	       0, 0, 1);

# Download the signature, if we can check it
my ($ec, $emsg) = &gnupg_setup();
if (!$ec && $sigmode) {
	my $err;
	my $sig;
	&http_download($host, $port, $page."-sig.asc", \$sig,
		       \$err, undef, $ssl, $user, $pass, 0, 0, 1);
	if ($err) {
		$sigmode == 2 && &error(&text('update_enosig', $err));
		}
	else {
		my $data = &read_file_contents($temp);
		my ($vc, $vmsg) = &verify_data($data, $sig);
		if ($vc > 1) {
			&error(&text('update_ebadsig',
				&text('upgrade_everify'.$vc, $vmsg)));
			}
		}
	}

my @updates;
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

=head2 check_update_signature(host, port, page, ssl, user, pass, file, sig-mode)

Given a downloaded module update file, fetch the signature from the same URL
with -sig.asc appended, and check that it is valid. Parameters are :

=item host - Module download host

=item port - Module download port

=item page - Module download URL path

=item ssl - Use SSL to download?

=item user - Login for module download

=item pass - Password for module download

=item file - File containing module to check

=item sig-mode - 0=No check, 1=Check if possible, 2=Must check

=cut
sub check_update_signature
{
my ($host, $port, $page, $ssl, $user, $pass, $file, $sigmode) = @_;

my ($ec, $emsg) = &gnupg_setup();
if (!$ec && $sigmode) {
	my $err;
	my $sig;
	&http_download($host, $port, $page."-sig.asc", \$sig,
		       \$err, undef, $ssl, $user, $pass);
	if ($err) {
                $sigmode == 2 && return &text('update_enomodsig', $err);
                }
	else {
		my $data = &read_file_contents($file);
		my ($vc, $vmsg) = &verify_data($data, $sig);
		if ($vc > 1) {
			return &text('update_ebadmodsig',
				&text('upgrade_everify'.$vc, $vmsg));
			}
		}
	}
return undef;
}

=head2 find_cron_job(\@jobs)

Finds the cron job for Webmin updates, given an array ref of cron jobs
as returned by cron::list_cron_jobs

=cut
sub find_cron_job
{
my ($job) = grep { $_->{'user'} eq 'root' &&
		   $_->{'command'} eq $cron_cmd } @{$_[0]};
return $job;
}

=head2 get_ipkeys(&miniserv)

Returns a list of IP address to key file mappings from a miniserv.conf entry.

=cut
sub get_ipkeys
{
my @rv;
foreach my $k (keys %{$_[0]}) {
	if ($k =~ /^ipkey_(\S+)/) {
		my $ipkey = { 'ips' => [ split(/,/, $1) ],
			      'key' => $_[0]->{$k},
			      'index' => scalar(@rv) };
		$ipkey->{'cert'} = $_[0]->{'ipcert_'.$1};
		$ipkey->{'extracas'} = $_[0]->{'ipextracas_'.$1};
		push(@rv, $ipkey);
		}
	}
return @rv;
}

=head2 save_ipkeys(&miniserv, &keys)

Updates miniserv.conf entries from the given list of keys.

=cut
sub save_ipkeys
{
my $k;
foreach $k (keys %{$_[0]}) {
	if ($k =~ /^(ipkey_|ipcert_)/) {
		delete($_[0]->{$k});
		}
	}
foreach $k (@{$_[1]}) {
	my $ips = join(",", @{$k->{'ips'}});
	$_[0]->{'ipkey_'.$ips} = $k->{'key'};
	if ($k->{'cert'}) {
		$_[0]->{'ipcert_'.$ips} = $k->{'cert'};
		}
	else {
		delete($_[0]->{'ipcert_'.$ips});
		}
	if ($k->{'extracas'}) {
		$_[0]->{'ipextracas_'.$ips} = $k->{'extracas'};
		}
	else {
		delete($_[0]->{'ipextracas_'.$ips});
		}
	}
}

=head2 validate_key_cert(key, [cert])

Call &error if some key and cert file don't look correct, based on the BEGIN
line.

=cut
sub validate_key_cert
{
my $key = &read_file_contents($_[0]);
$key =~ /BEGIN RSA PRIVATE KEY/i ||
    $key =~ /BEGIN PRIVATE KEY/i ||
	&error(&text('ssl_ekey', $_[0]));
if (!$_[1]) {
	$key =~ /BEGIN CERTIFICATE/ || &error(&text('ssl_ecert', $_[0]));
	}
else {
	my $cert = &read_file_contents($_[1]);
	$cert =~ /BEGIN CERTIFICATE/ || &error(&text('ssl_ecert', $_[1]));
	}
}

=head2 detect_operating_system([os-list-file], [with-cache])

Returns a hash containing os_type, os_version, real_os_type and
real_os_version, suitable for the current system.

=cut
sub detect_operating_system
{
my $file = $_[0] || "$root_directory/os_list.txt";
my $cache = $_[1];
if ($cache) {
	# Check the cache file, and only re-check the OS if older than
	# 1 day, or if we have rebooted recently
	my %cache;
	my $uptime = &get_system_uptime();
	my $lastreboot = $uptime ? time()-$uptime : undef;
	if (&read_file($detect_operating_system_cache, \%cache) &&
	    $cache{'os_type'} && $cache{'os_version'} &&
	    $cache{'real_os_type'} && $cache{'real_os_version'}) {
		if ($cache{'time'} > time()-24*60*60 &&
		    $cache{'time'} > $lastreboot) {
			return %cache;
			}
		}
	}
my $temp = &transname();
my $perl = &get_perl_path();
system("$perl $root_directory/oschooser.pl $file $temp 1");
my %rv;
&read_env_file($temp, \%rv);
$rv{'time'} = time();
&write_file($detect_operating_system_cache, \%rv);
return %rv;
}

=head2 show_webmin_notifications([no-updates])

Print various notifications for the current user, if any. These can include
password expiry, Webmin updates and more.

=cut
sub show_webmin_notifications
{
my ($noupdates) = @_;
my @notifs = &get_webmin_notifications($noupdates);
if (@notifs) {
	print "<center>\n",join("<hr>\n", @notifs),"</center>\n";
	}
}

=head2 get_webmin_notifications([no-updates])

Returns a list of Webmin notification messages, each of which is a string of
HTML. If the no-updates flag is set, Webmin version / module updates are
not included.

=cut
sub get_webmin_notifications
{
my ($noupdates) = @_;
$noupdates = 1 if (&shared_root_directory());
my @notifs;
my %miniserv;
&get_miniserv_config(\%miniserv);
&load_theme_library();	# So that UI functions work

# Need OS upgrade
my %realos = &detect_operating_system(undef, 1);
if (($realos{'os_version'} ne $gconfig{'os_version'} ||
     $realos{'os_type'} ne $gconfig{'os_type'}) &&
    &foreign_available("webmin")) {
	push(@notifs, 
		&ui_form_start("$gconfig{'webprefix'}/webmin/fix_os.cgi").
		&text('os_incorrect', $realos{'real_os_type'},
				    $realos{'real_os_version'})."<p>\n".
		&ui_form_end([ [ undef, $text{'os_fix'} ] ])
		);
	}

# Password close to expiry
my $warn_days = $config{'warn_days'};
if (&foreign_check("acl")) {
	# Get the Webmin user
	&foreign_require("acl", "acl-lib.pl");
	my @users = &acl::list_users();
	my ($uinfo) = grep { $_->{'name'} eq $base_remote_user } @users;
	if ($uinfo && $uinfo->{'pass'} eq 'x' && &foreign_check("useradmin")) {
		# Unix auth .. check password in Users and Groups
		&foreign_require("useradmin", "user-lib.pl");
		($uinfo) = grep { $_->{'user'} eq $remote_user }
				&useradmin::list_users();
		if ($uinfo && $uinfo->{'warn'} && $uinfo->{'change'} &&
		    $uinfo->{'max'}) {
			my $daysago = int(time()/(24*60*60)) -
					 $uinfo->{'change'};
			my $cdate = &make_date(
				$uinfo->{'change'}*24*60*60, 1);
			if ($daysago > $uinfo->{'max'}) {
				# Passed expiry date
				push(@notifs, &text('notif_unixexpired',
						    $cdate));
				}
			elsif ($daysago > $uinfo->{'max'}-$uinfo->{'warn'}) {
				# Passed warning date
				push(@notifs, &text('notif_unixwarn',
						    $cdate,
						    $uinfo->{'max'}-$daysago));
				}
			}
		}
	elsif ($uinfo && $uinfo->{'lastchange'}) {
		# Webmin auth .. check password in Webmin
		my $daysold = (time() - $uinfo->{'lastchange'})/(24*60*60);
		my $link = &foreign_available("change-user") ?
			&text('notif_changenow',
			     "$gconfig{'webprefix'}/change-user/")."<p>\n" : "";
		if ($miniserv{'pass_maxdays'} &&
		    $daysold > $miniserv{'pass_maxdays'}) {
			# Already expired
			push(@notifs, &text('notif_passexpired')."<p>\n".$link);
			}
		elsif ($miniserv{'pass_maxdays'} &&
		       $daysold > $miniserv{'pass_maxdays'} - $warn_days) {
			# About to expire
			push(@notifs, &text('notif_passchange',
				&make_date($uinfo->{'lastchange'}, 1),
				int($miniserv{'pass_maxdays'} - $daysold)).
				"<p>\n".$link);
			}
		elsif ($miniserv{'pass_lockdays'} &&
		       $daysold > $miniserv{'pass_lockdays'} - $warn_days) {
			# About to lock out
			push(@notifs, &text('notif_passlock',
				&make_date($uinfo->{'lastchange'}, 1),
				int($miniserv{'pass_maxdays'} - $daysold)).
				"<p>\n".$link);
			}
		}
	}

# New Webmin version is available, but only once per day
my $now = time();
if (&foreign_available($module_name) && !$noupdates &&
    !$gconfig{'nowebminup'}) {
	if (!$config{'last_version_check'} ||
            $now - $config{'last_version_check'} > 24*60*60) {
		# Cached last version has expired .. re-fetch
		my ($ok, $version) = &get_latest_webmin_version();
		if ($ok) {
			$config{'last_version_check'} = $now;
			$config{'last_version_number'} = $version;
			&save_module_config();
			}
		}
	if ($config{'last_version_number'} > &get_webmin_version()) {
		# New version is out there .. offer to upgrade
		my $mode = &get_install_type();
		my $checksig = 0;
		if ((!$mode || $mode eq "rpm") && &foreign_check("proc")) {
			my ($ec, $emsg) = &gnupg_setup();
			if (!$ec) {
				$checksig = 1;
				}
			}
		push(@notifs,
		     &ui_form_start("$gconfig{'webprefix'}/webmin/upgrade.cgi",
				    "form-data").
		     &ui_hidden("source", 2).
		     &ui_hidden("sig", $checksig).
		     &ui_hidden("mode", $mode).
		     &text('notif_upgrade', $config{'last_version_number'},
			   &get_webmin_version())."<p>\n".
		     &ui_form_end([ [ undef, $text{'notif_upgradeok'} ] ]));
		}
	}

# Webmin module updates
if (&foreign_available($module_name) && !$noupdates &&
    !$gconfig{'nomoduleup'}) {
	my @st = stat($update_cache);
	my $allupdates = [ ];
	my @urls = $config{'upsource'} ?
		split(/\t+/, $config{'upsource'}) : ( $update_url );
	if (!@st || $now - $st[9] > 24*60*60) {
		# Need to re-fetch cache
		foreach my $url (@urls) {
			my $checksig = $config{'upchecksig'} ? 2 :
				       $url eq $update_url ? 2 : 1;
			eval {
				local $main::error_must_die = 1;
				my ($updates) = &fetch_updates($url,
					$config{'upuser'}, $config{'uppass'},
					$checksig);
				push(@$allupdates, @$updates);
				};
			}
		my $fh;
		&open_tempfile($fh, ">$update_cache", 1);
		&print_tempfile($fh, &serialise_variable($allupdates));
		&close_tempfile($fh);
		}
	else {
		# Just use cache
		my $cdata = &read_file_contents($update_cache);
		$allupdates = &unserialise_variable($cdata);
		}

	# All a table of them, and a form to install
	$allupdates = &filter_updates($allupdates);
	if (@$allupdates) {
		my $msg = &ui_form_start(
			"$gconfig{'webprefix'}/webmin/update.cgi");
		$msg .= &text('notif_updatemsg', scalar(@$allupdates))."<p>\n";
		$msg .= &ui_columns_start(
			[ $text{'notify_updatemod'},
			  $text{'notify_updatever'},
			  $text{'notify_updatedesc'} ]);
		foreach my $u (@$allupdates) {
			my %minfo = &get_module_info($u->[0]);
			my %tinfo = &get_theme_info($u->[0]);
			my %info = %minfo ? %minfo : %tinfo;
			$msg .= &ui_columns_row([
				$info{'desc'},
				$u->[1],
				$u->[4] ]);
			}
		$msg .= &ui_columns_end();
		$msg .= &ui_hidden("source", 1);
		$msg .= &ui_hidden("other", join("\n", @urls));
		$msg .= &ui_hidden("upuser", $config{'upuser'});
		$msg .= &ui_hidden("uppass", $config{'uppass'});
		$msg .= &ui_hidden("third", $config{'upthird'});
		$msg .= &ui_hidden("checksig", $config{'upchecksig'});
		$msg .= &ui_form_end([ [ undef, $text{'notif_updateok'} ] ]);
		push(@notifs, $msg);
		}
	}

return @notifs;
}

=head2 get_system_uptime

Returns the number of seconds the system has been up, or undef if un-available.

=cut
sub get_system_uptime
{
# Try Linux /proc/uptime first
if (open(UPTIME, "/proc/uptime")) {
	my $line = <UPTIME>;
	close(UPTIME);
	my ($uptime, $dummy) = split(/\s+/, $line);
	if ($uptime > 0) {
		return int($uptime);
		}
	}

# Try to parse uptime command output
if ($gconfig{'os_type'} ne 'windows') {
	my $out = &backquote_command("uptime");
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

=head2 list_operating_systems([os-list-file])

Returns a list of known OSs, each of which is a hash ref with keys :

=item realtype - A human-readable OS name, like Ubuntu Linux.

=item realversion - A human-readable version, like 8.04.

=item type - Webmin's internal OS code, like debian-linux.

=item version - Webmin's internal version number, like 3.1.

=item code - A fragment of Perl that will return true if evaluated on this OS.

=cut
sub list_operating_systems
{
my $file = $_[0] || "$root_directory/os_list.txt";
my @rv;
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

=head2 shared_root_directory

Returns 1 if the Webmin root directory is shared with another system, such as
via NFS, or in a Solaris zone. If so, updates and module installs are not
allowed.

=cut
sub shared_root_directory
{
if (exists($gconfig{'shared_root'}) && $gconfig{'shared_root'} eq '1') {
	# Always shared
	return 1;
	}
elsif (exists($gconfig{'shared_root'}) && $gconfig{'shared_root'} eq '0') {
	# Definately not shared
	return 0;
	}
if (&running_in_zone()) {
	# In a Solaris zone .. is the root directory loopback mounted?
	if (&foreign_exists("mount")) {
		&foreign_require("mount", "mount-lib.pl");
		my @rst = stat($root_directory);
		my $m;
		foreach $m (&mount::list_mounted()) {
			my @mst = stat($m->[0]);
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

=head2 submit_os_info(id)

Send via email a message about this system's OS and Perl version. Returns
undef if OK, or an error message.

=cut
sub submit_os_info
{
if (!&foreign_installed("mailboxes", 1)) {
	return $text{'submit_emailboxes'};
	}
&foreign_require("mailboxes", "mailboxes-lib.pl");
my $mail = {    'headers' => [ [ 'From', &mailboxes::get_from_address() ],
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

=head2 get_webmin_id

Returns a (hopefully) unique ID for this Webmin install.

=cut
sub get_webmin_id
{
if (!$config{'webminid'}) {
	my $salt = substr(time(), -2);
	$config{'webminid'} = &unix_crypt(&get_system_hostname(), $salt);
	&save_module_config();
	}
return $config{'webminid'};
}

=head2 ip_match(ip, [match]+)

Checks an IP address against a list of IPs, networks and networks/masks, and
returns 1 if a match is found.

=cut
sub ip_match
{
my @io = &check_ip6address($_[0]) ? split(/:/, $_[0])
			          : split(/\./, $_[0]);

# Resolve to hostname and check that it forward resolves again
my $hn = &to_hostname($_[0]);
if (&check_ip6address($_[0])) {
	$hn = "" if (&to_ip6address($hn) ne $_[0]);
	}
else {
	$hn = "" if (&to_ipaddress($hn) ne $_[0]);
	}

for(my $i=1; $i<@_; $i++) {
	my $mismatch = 0;
	my $ip = $_[$i];
        if ($ip =~ /^(\S+)\/(\d+)$/) {
                # Convert CIDR to netmask format
                $ip = $1."/".&prefix_to_mask($2);
                }
	if ($ip =~ /^(\S+)\/(\S+)$/) {
		# Compare with IPv4 network/mask
		my @mo = split(/\./, $1);
		my @ms = split(/\./, $2);
		for(my $j=0; $j<4; $j++) {
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
	elsif ($_[$i] =~ /^[0-9\.]+$/) {
		# Compare with IPv4 address or network
		my @mo = split(/\./, $_[$i]);
		while(@mo && !$mo[$#mo]) { pop(@mo); }
		for(my $j=0; $j<@mo; $j++) {
			if ($mo[$j] != $io[$j]) {
				$mismatch = 1;
				}
			}
		}
	elsif ($_[$i] =~ /^[a-f0-9:]+$/) {
		# Compare with IPv6 address or network
		my @mo = split(/:/, $_[$i]);
		while(@mo && !$mo[$#mo]) { pop(@mo); }
		for(my $j=0; $j<@mo; $j++) {
			if ($mo[$j] ne $io[$j]) {
				$mismatch = 1;
				}
			}
		}
	elsif ($_[$i] !~ /^[0-9\.]+$/) {
		# Compare with hostname
		$mismatch = 1 if ($_[0] ne &to_ipaddress($_[$i]));
		}
	return 1 if (!$mismatch);
	}
return 0;
}

=head2 prefix_to_mask(prefix)

Converts a number like 24 to a mask like 255.255.255.0.

=cut
sub prefix_to_mask
{
return $_[0] >= 24 ? "255.255.255.".(256-(2 ** (32-$_[0]))) :
       $_[0] >= 16 ? "255.255.".(256-(2 ** (24-$_[0]))).".0" :
       $_[0] >= 16 ? "255.".(256-(2 ** (16-$_[0]))).".0.0" :
                     (256-(2 ** (8-$_[0]))).".0.0.0";
}

=head2 valid_allow(text)

Returns undef if some text is a valid IP, hostname or network for use in
allowed IPs, or an error message if not

=cut
sub valid_allow
{
my ($h) = @_;
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
elsif ($h =~ /^[a-f0-9:]+$/) {
	&check_ip6address($h) ||
		return &text('access_eip6', $h);
	}
elsif ($h =~ /^\*\.(\S+)$/) {
	# *.domain is OK
	}
elsif ($h eq 'LOCAL') {
	# Local means any on local nets
	}
elsif (&to_ipaddress($h) || &to_ip6address($h)) {
	# Resolvable hostname
	}
else {
	return &text('access_ehost', $h);
	}
return undef;
}

=head2 get_preloads(&miniserv)

Returns a list of module names and files to pre-load, based on a Webmin
miniserv configuration hash. Each is a two-element array ref containing
a package name and the relative path of the .pl file to pre-load.

=cut
sub get_preloads
{
my @rv = map { [ split(/=/, $_) ] } split(/\s+/, $_[0]->{'preload'});
return @rv;
}

=head2 save_preloads(&miniserv, &preloads)

Updates a Webmin miniserv configuration hash from a list of preloads, in
the format returned by get_preloads.

=cut
sub save_preloads
{
$_[0]->{'preload'} = join(" ", map { "$_->[0]=$_->[1]" } @{$_[1]});
}

=head2 get_tempdirs(&gconfig)

Returns a list of per-module temp directories, each of which is an array
ref containing a module name and directory.

=cut
sub get_tempdirs
{
my ($gconfig) = @_;
my @rv;
foreach my $k (keys %$gconfig) {
	if ($k =~ /^tempdir_(.*)$/) {
		push(@rv, [ $1, $gconfig->{$k} ]);
		}
	}
return sort { $a->[0] cmp $b->[0] } @rv;
}

=head2 save_tempdirs(&gconfig, &tempdirs)

Updates the global config with a list of per-module temp dirs

=cut
sub save_tempdirs
{
my ($gconfig, $dirs) = @_;
foreach my $k (keys %$gconfig) {
	if ($k =~ /^tempdir_(.*)$/) {
		delete($gconfig->{$k});
		}
	}
foreach my $d (@$dirs) {
	$gconfig->{'tempdir_'.$d->[0]} = $d->[1];
	}
}

=head2 get_module_install_type(dir)

Returns the installation method used for some module (such as 'rpm'), or undef
if it was installed from a .wbm.

=cut
sub get_module_install_type
{
my ($mod) = @_;
my $it = &module_root_directory($mod)."/install-type";
open(TYPE, $it) || return undef;
my $type = <TYPE>;
chop($type);
close(TYPE);
return $type;
}

=head2 get_install_type

Returns the package type Webmin was installed form (rpm, deb, solaris-pkg
or undef for tar.gz).

=cut
sub get_install_type
{
my $mode;
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

=head2 list_cached_files

Returns a list of cached filenames for downloads made by Webmin, as array refs
containing a full path and url.

=cut
sub list_cached_files
{
my @rv;
opendir(DIR, $main::http_cache_directory);
foreach my $cfile (readdir(DIR)) {
	next if ($cfile eq "." || $cfile eq "..");
	my $curl = $cfile;
	$curl =~ s/_/\//g;
	push(@rv, [ $cfile, "$main::http_cache_directory/$cfile", $curl ]);
	}
closedir(DIR);
return @rv;
}

=head2 show_restart_page([title, msg])

Output a page with header and footer about Webmin needing to restart.

=cut
sub show_restart_page
{
my ($title, $msg) = @_;
$title ||= $text{'restart_title'};
$msg ||= $text{'restart_done'};
&ui_print_header(undef, $title, "");

print "$msg<p>\n";

&ui_print_footer("", $text{'index_return'});
&restart_miniserv(1);
}

=head2 cert_info(file)

Returns a hash of details of a cert in some file.

=cut
sub cert_info
{
my %rv;
local $_;
open(OUT, "openssl x509 -in ".quotemeta($_[0])." -issuer -subject -enddate |");
while(<OUT>) {
	s/\r|\n//g;
	if (/subject=.*CN=([^\/]+)/) {
		$rv{'cn'} = $1;
		}
	if (/subject=.*O=([^\/]+)/) {
		$rv{'o'} = $1;
		}
	if (/subject=.*Email=([^\/]+)/) {
		$rv{'email'} = $1;
		}
	if (/issuer=.*CN=([^\/]+)/) {
		$rv{'issuer_cn'} = $1;
		}
	if (/issuer=.*O=([^\/]+)/) {
		$rv{'issuer_o'} = $1;
		}
	if (/issuer=.*Email=([^\/]+)/) {
		$rv{'issuer_email'} = $1;
		}
	if (/notAfter=(.*)/) {
		$rv{'notafter'} = $1;
		}
	}
close(OUT);
$rv{'type'} = $rv{'o'} eq $rv{'issuer_o'} ? $text{'ssl_typeself'}
					  : $text{'ssl_typereal'};
return \%rv;
}

=head2 cert_pem_data(file)

Returns a cert in PEM format, from a file containing the PEM and possibly
other keys.

=cut
sub cert_pem_data
{
my ($d) = @_;
my $data = &read_file_contents($_[0]);
if ($data =~ /(-----BEGIN\s+CERTIFICATE-----\n([A-Za-z0-9\+\/=\n\r]+)-----END\s+CERTIFICATE-----)/) {
	return $1;
	}
return undef;
}

=head2 cert_pkcs12_data(keyfile, [certfile])

Returns a cert in PKCS12 format.

=cut
sub cert_pkcs12_data
{
my ($keyfile, $certfile) = @_;
if ($certfile) {
	open(OUT, "openssl pkcs12 -in ".quotemeta($certfile).
		  " -inkey ".quotemeta($keyfile).
		  " -export -passout pass: -nokeys |");
	}
else {
	open(OUT, "openssl pkcs12 -in ".quotemeta($keyfile).
		  " -export -passout pass: -nokeys |");
	}
my $data;
while(<OUT>) {
	$data .= $_;
	}
close(OUT);
return $data;
}

=head2 get_blocked_users_hosts(&miniserv)

Returns a list of blocked users and hosts from the file written by Webmin
at run-time.

=cut
sub get_blocked_users_hosts
{
my ($miniserv) = @_;
my $bf = $miniserv->{'blockedfile'};
if (!$bf) {
	$miniserv->{'pidfile'} =~ /^(.*)\/[^\/]+$/;
	$bf = "$1/blocked";
	}
my @rv;
my $fh;
&open_readfile($fh, $bf) || return ();
while(<$fh>) {
	s/\r|\n//g;
	my ($type, $who, $fails, $when) = split(/\s+/, $_);
	push(@rv, { 'type' => $type,
		    $type => $who,
		    'fails' => $fails,
		    'when' => $when });
	}
close($fh);
return @rv;
}

=head2 show_ssl_key_form([defhost], [defemail], [deforg])

Returns HTML for inputs to generate a new self-signed cert.

=cut
sub show_ssl_key_form
{
my ($defhost, $defemail, $deforg) = @_;
my $rv;

$rv .= &ui_table_row($text{'ssl_cn'},
		    &ui_opt_textbox("commonName", $defhost, 30,
				    $text{'ssl_all'}));

$rv .= &ui_table_row($text{'ca_email'},
		    &ui_textbox("emailAddress", $defemail, 30));

$rv .= &ui_table_row($text{'ca_ou'},
		    &ui_textbox("organizationalUnitName", undef, 30));

$rv .= &ui_table_row($text{'ca_o'},
		    &ui_textbox("organizationName", $deforg, 30));

$rv .= &ui_table_row($text{'ca_city'},
		    &ui_textbox("cityName", undef, 30));

$rv .= &ui_table_row($text{'ca_sp'},
		    &ui_textbox("stateOrProvinceName", undef, 15));

$rv .= &ui_table_row($text{'ca_c'},
		    &ui_textbox("countryName", undef, 2));

$rv .= &ui_table_row($text{'ssl_size'},
		    &ui_opt_textbox("size", undef, 6,
				    "$text{'default'} ($default_key_size)").
			" ".$text{'ssl_bits'});

$rv .= &ui_table_row($text{'ssl_days'},
		    &ui_textbox("days", 1825, 8));

return $rv;
}

=head2 parse_ssl_key_form(&in, keyfile, [certfile])

Parses the key generation form, and creates new key and cert files.
Returns undef on success or an error message on failure.

=cut
sub parse_ssl_key_form
{
my ($in, $keyfile, $certfile) = @_;
my %in = %$in;

# Validate inputs
$in{'commonName_def'} || $in{'commonName'} =~ /^[A-Za-z0-9\.\-\*]+$/ ||
	return $text{'newkey_ecn'};
$in{'size_def'} || $in{'size'} =~ /^\d+$/ || return $text{'newkey_esize'};
$in{'days'} =~ /^\d+$/ || return $text{'newkey_edays'};
$in{'countryName'} =~ /^\S\S$/ || return $text{'newkey_ecountry'};

# Work out SSL command
my %aclconfig = &foreign_config('acl');
&foreign_require("acl", "acl-lib.pl");
my $cmd = &acl::get_ssleay();
if (!$cmd) {
	return &text('newkey_ecmd', "<tt>$aclconfig{'ssleay'}</tt>",
		     "$gconfig{'webprefix'}/config.cgi?acl");
	}

# Run openssl and feed it key data
my $ctemp = &transname();
my $ktemp = &transname();
my $outtemp = &transname();
my $size = $in{'size_def'} ? $default_key_size : quotemeta($in{'size'});
open(CA, "| $cmd req -newkey rsa:$size -x509 -nodes -out $ctemp -keyout $ktemp -days ".quotemeta($in{'days'})." >$outtemp 2>&1");
print CA ($in{'countryName'} || "."),"\n";
print CA ($in{'stateOrProvinceName'} || "."),"\n";
print CA ($in{'cityName'} || "."),"\n";
print CA ($in{'organizationName'} || "."),"\n";
print CA ($in{'organizationalUnitName'} || "."),"\n";
print CA ($in{'commonName_def'} ? "*" : $in{'commonName'}),"\n";
print CA ($in{'emailAddress'} || "."),"\n";
close(CA);
my $rv = $?;
my $out = &read_file_contents($outtemp);
unlink($outtemp);
if (!-r $ctemp || !-r $ktemp || $?) {
	return $text{'newkey_essl'}."<br>"."<pre>".&html_escape($out)."</pre>";
	}

# Write to the final files
my $certout = &read_file_contents($ctemp);
my $keyout = &read_file_contents($ktemp);
unlink($ctemp, $ktemp);

my ($kfh, $cfh);
&open_lock_tempfile($kfh, ">$keyfile");
&print_tempfile($kfh, $keyout);
if ($certfile) {
	# Separate files
	&open_lock_tempfile($cfh, ">$certfile");
	&print_tempfile($cfh, $certout);
	&close_tempfile($cfh);
	&set_ownership_permissions(undef, undef, 0600, $certfile);
	}
else {
	# Both go in the same file
	&print_tempfile($kfh, $certout);
	}
&close_tempfile($kfh);
&set_ownership_permissions(undef, undef, 0600, $keyfile);

return undef;
}

=head2 build_installed_modules(force-all, force-mod)

Calls each module's install_check function, and updates the cache of
modules whose underlying servers are installed.

=cut
sub build_installed_modules
{
my ($force, $mod) = @_;
my %installed;
my $changed;
&read_file_cached("$config_directory/installed.cache", \%installed);
my @changed;
foreach my $minfo (&get_all_module_infos()) {
	next if ($mod && $minfo->{'dir'} ne $mod);
	next if (defined($installed{$minfo->{'dir'}}) && !$force && !$mod);
	next if (!&check_os_support($minfo));
	$@ = undef;
	my $o = $installed{$minfo->{'dir'}};
	my $pid = fork();
	if (!$pid) {
		# Check in a sub-process
		my $rv;
		eval {
			local $main::error_must_die = 1;
			$rv = &foreign_installed($minfo->{'dir'}, 0) ? 1 : 0;
			};
		if ($@) {
			# Install check failed .. but assume the module is OK
			$rv = 1;
			}
		exit($rv);
		}
	waitpid($pid, 0);
	$installed{$minfo->{'dir'}} = $? / 256;
	push(@changed, $minfo->{'dir'}) if ($installed{$minfo->{'dir'}} ne $o);
	}
&write_file("$config_directory/installed.cache", \%installed);
return wantarray ? (\%installed, \@changed) : \%installed;
}

=head2 get_latest_webmin_version

Returns 1 and the latest version of Webmin available on www.webmin.com, or
0 and an error message

=cut
sub get_latest_webmin_version
{
my $file = &transname();
my ($error, $version);
&http_download($update_host, $update_port, '/', $file, \$error);
return (0, $error) if ($error);
open(FILE, $file);
while(<FILE>) {
	if (/webmin-([0-9\.]+)\.tar\.gz/) {
		$version = $1;
		last;
		}
	}
close(FILE);
unlink($file);
return $version ? (1, $version)
		: (0, "No version number found at $update_host");
}

=head2 filter_updates(&updates, [version], [include-third], [include-missing])

Given a list of updates, filters them to include only those that are
suitable for this system. The parameters are :

=item updates - Array ref of updates, as returned by fetch_updates.

=item version - Webmin version number to use in comparisons.

=item include-third - Set to 1 to include non-core modules in the results.

=item include-missing - Set to 1 to include modules not currently installed.

=cut
sub filter_updates
{
my ($allupdates, $version, $third, $missing) = @_;
$version ||= &get_webmin_version();
my $bversion = &base_version($version);
my $updatestemp = &transname();
my @updates;
foreach my $u (@$allupdates) {
	my %minfo = &get_module_info($u->[0]);
	my %tinfo = &get_theme_info($u->[0]);
	my %info = %minfo ? %minfo : %tinfo;

	# Skip if wrong version of Webmin, unless this is non-core module and
	# we are handling them too
	my $nver = $u->[1];
	$nver =~ s/^(\d+\.\d+)\..*$/$1/;
	next if (($nver >= $bversion + .01 ||
		  $nver <= $bversion ||
		  $nver <= $version) &&
		 (!%info || $info{'longdesc'} || !$third));

	# Skip if not installed, unless installing new
	next if (!%info && !$missing);

	# Skip if module has a version, and we already have it
	next if (%info && $info{'version'} && $info{'version'} >= $nver);

	# Skip if not supported on this OS
	my $osinfo = { 'os_support' => $u->[3] };
	next if (!&check_os_support($osinfo));

	# Skip if installed from RPM or Deb and update was not
	my $itype = &get_module_install_type($u->[0]);
	next if ($itype && $u->[2] !~ /\.$itype$/i);

	push(@updates, $u);
	}
return \@updates;
}

1;
