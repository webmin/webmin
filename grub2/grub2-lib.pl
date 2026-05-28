# grub2-lib.pl
# Helpers for the GRUB 2 Webmin module.

BEGIN { push(@INC, ".."); };    ## no critic
use strict;
use warnings;
use WebminCore;
use Cwd qw(abs_path);
use File::Basename qw(basename dirname);
use File::Find;
use File::Path qw(make_path remove_tree);
use Fcntl qw(O_CREAT O_EXCL O_WRONLY);
use Errno qw(EEXIST);

our (%config, %text);
our ($module_root_directory, $module_var_directory);
our ($grub2_config_change_flag, $grub2_generate_time_flag);

&init_config();
$grub2_config_change_flag = $module_var_directory."/config-flag";
$grub2_generate_time_flag = $module_var_directory."/generate-flag";
&load_grub2_defaults();

# grub2_acl_keys()
# Returns the supported GRUB 2 ACL capabilities.
sub grub2_acl_keys
{
return qw(view edit security apply runtime manual install backup);
}

# grub2_effective_acl([&raw-acl])
# Returns normalized ACL settings for a supplied ACL hash or current user.
sub grub2_effective_acl
{
my ($rawacl) = @_;
my %raw = $rawacl ? %$rawacl : &get_module_acl();
return map { $_ => $raw{$_} ? 1 : 0 } &grub2_acl_keys();
}

# grub2_check_acl(action, [&raw-acl])
# Returns true when an effective ACL permits the requested action.
sub grub2_check_acl
{
my ($action, $rawacl) = @_;
my %acl = &grub2_effective_acl($rawacl);
return $acl{$action} ? 1 : 0;
}

# grub2_assert_acl(action)
# Fails if the current Webmin user cannot perform an action.
sub grub2_assert_acl
{
my ($action) = @_;
&grub2_check_acl($action) ||
	&error("$text{'eacl_np'} $text{'eacl_p'.$action}");
}

# grub2_can_enter_module(&acl)
# Returns true if a user has at least one useful module capability.
sub grub2_can_enter_module
{
my ($acl) = @_;
foreach my $a (&grub2_acl_keys()) {
	return 1 if ($acl->{$a});
	}
return 0;
}

# grub2_mark_regenerate_needed()
# Updates the flag indicating that grub.cfg needs to be regenerated.
sub grub2_mark_regenerate_needed
{
&open_lock_tempfile(my $fh, ">$grub2_config_change_flag", 0, 1);
&close_tempfile($fh);
return;
}

# grub2_mark_generated()
# Updates the flag indicating that grub.cfg has been regenerated.
sub grub2_mark_generated
{
&open_lock_tempfile(my $fh, ">$grub2_generate_time_flag", 0, 1);
&close_tempfile($fh);
return;
}

# grub2_needs_regenerate()
# Returns true when a saved source change has not been regenerated yet.
sub grub2_needs_regenerate
{
my @cst = stat($grub2_config_change_flag);
my @gst = stat($grub2_generate_time_flag);
return 0 if (!@cst);
return 1 if (!@gst);
return $cst[9] > $gst[9] ? 1 : 0;
}

# grub2_action_links(&acl, [return-url])
# Returns header action links for applying pending GRUB source changes.
sub grub2_action_links
{
my ($acl, $return_url) = @_;
return '' if (!$acl->{'apply'} || !&grub2_command('mkconfig_cmd'));
$return_url ||= &grub2_this_url();
my $label = $text{'index_generate'};
$label = &ui_tag('b', $label) if (&grub2_needs_regenerate());
return &ui_link("generate.cgi?redir=".&urlize($return_url), $label);
}

# grub2_this_url()
# Returns the current module URL for apply-action redirects.
sub grub2_this_url
{
my $url = $ENV{'SCRIPT_NAME'} || '';
$url .= "?$ENV{'QUERY_STRING'}"
	if (defined($ENV{'QUERY_STRING'}) && $ENV{'QUERY_STRING'} ne '');
return $url;
}

# load_grub2_defaults()
# Fills missing runtime config values from the bundled module defaults.
sub load_grub2_defaults
{
my %defaults;
if ($module_root_directory && -r "$module_root_directory/config") {
	# Start with bundled defaults so unconfigured installs have sane paths.
	&read_file("$module_root_directory/config", \%defaults);
	}
foreach my $k (keys %defaults) {
	if (!defined($config{$k}) || $config{$k} eq '') {
		$config{$k} = $defaults{$k};
		}
	}
&discover_grub2_runtime_defaults();
}

# discover_grub2_runtime_defaults()
# Corrects missing generic defaults to the GRUB 2 layout installed locally.
sub discover_grub2_runtime_defaults
{
# Prefer common distro paths before falling back to the packaged config.
&prefer_existing_file('grub_cfg',
	'/boot/grub2/grub.cfg',
	'/boot/grub/grub.cfg',
	'/boot/efi/EFI/redhat/grub.cfg',
	'/boot/efi/EFI/rocky/grub.cfg',
	'/boot/efi/EFI/almalinux/grub.cfg',
	'/boot/efi/EFI/centos/grub.cfg',
	'/boot/efi/EFI/debian/grub.cfg',
);
&prefer_existing_file('grubenv_file',
	'/boot/grub2/grubenv',
	'/boot/grub/grubenv',
	'/boot/efi/EFI/redhat/grubenv',
	'/boot/efi/EFI/rocky/grubenv',
	'/boot/efi/EFI/almalinux/grubenv',
	'/boot/efi/EFI/centos/grubenv',
	'/boot/efi/EFI/debian/grubenv',
);
&prefer_existing_dir('bls_dir', '/boot/loader/entries');
&prefer_existing_dir('theme_dir',
	'/boot/grub2/themes',
	'/boot/grub/themes',
);
&prefer_existing_dir('background_dir',
	'/boot/grub2/backgrounds',
	'/boot/grub/backgrounds',
);
&prefer_existing_command('mkconfig_cmd',
	qw(grub2-mkconfig grub-mkconfig));
&prefer_existing_command('install_cmd',
	qw(grub2-install grub-install));
&prefer_existing_command('set_default_cmd',
	qw(grub2-set-default grub-set-default));
&prefer_existing_command('reboot_once_cmd',
	qw(grub2-reboot grub-reboot));
&prefer_existing_command('editenv_cmd',
	qw(grub2-editenv grub-editenv));
# Optional helpers unlock safer validation and BLS updates when installed.
&prefer_existing_command('script_check_cmd',
	qw(grub2-script-check grub-script-check));
&prefer_existing_command('mkpasswd_cmd',
	qw(grub2-mkpasswd-pbkdf2 grub-mkpasswd-pbkdf2));
&prefer_existing_command('grubby_cmd', qw(grubby));
}

# prefer_existing_file(key, paths...)
# Uses the first existing path when the configured file is missing.
sub prefer_existing_file
{
my ($key, @paths) = @_;
my $current = $config{$key};
return if (defined($current) && $current ne '' && -e $current);
foreach my $path (@paths) {
	if (-e $path) {
		$config{$key} = $path;
		return;
		}
	}
}

# prefer_existing_dir(key, paths...)
# Uses the first existing directory when the configured directory is missing.
sub prefer_existing_dir
{
my ($key, @paths) = @_;
my $current = $config{$key};
return if (defined($current) && $current ne '' && -d $current);
foreach my $path (@paths) {
	if (-d $path) {
		$config{$key} = $path;
		return;
		}
	}
}

# prefer_existing_command(key, commands...)
# Uses the first available GRUB command when the configured command is missing.
sub prefer_existing_command
{
my ($key, @commands) = @_;
my $current = $config{$key};
return if (defined($current) && $current ne '' && &has_command($current));
foreach my $cmd (@commands) {
	my $found = &has_command($cmd);
	if ($found) {
		$config{$key} = $found;
		return;
		}
	}
}

# grub2_config_value(key)
# Returns a module configuration value after defaults have been loaded.
sub grub2_config_value
{
my ($key) = @_;
return $config{$key};
}

# grub2_command(key)
# Returns a usable configured command path, if available.
sub grub2_command
{
my ($key) = @_;
my $cmd = &grub2_config_value($key);
return if (!defined($cmd) || $cmd eq '');
return &has_command($cmd);
}

# grub2_version_text()
# Returns a friendly GRUB version string for page subtitles.
sub grub2_version_text
{
foreach my $key (qw(install_cmd mkconfig_cmd editenv_cmd set_default_cmd)) {
	my $cmd = &grub2_command($key);
	next if (!$cmd);
	# Any installed GRUB helper can report the package version.
	my $out = &backquote_command(
		quotemeta($cmd).' --version 2>&1 </dev/null', 1);
	next if ($? || !$out);
	$out =~ s/\r?\n.*\z//s;
	$out =~ s/^\s+|\s+\z//g;
	if ($out =~ /\((?:GRUB|GRUB2)\)\s+(\S+)/i ||
	    $out =~ /\bGRUB\s+(\S+)/i) {
		my $version = $1;
		return &text('index_version', $version);
		}
	return $out;
	}
return;
}

# grub2_any_installed()
# Returns true if GRUB 2 files or commands are present on this system.
sub grub2_any_installed
{
return 1 if (&grub2_command('mkconfig_cmd'));
return 1 if (&grub2_command('install_cmd'));
return 1 if (&grub2_command('set_default_cmd'));
return 1 if (&grub2_command('editenv_cmd'));
return 1 if (-r (&grub2_config_value('default_file') || ''));
return 1 if (-r (&grub2_config_value('grub_cfg') || ''));
return 0;
}

# grub2_configured()
# Returns true if the module has enough files to inspect a GRUB 2 setup.
sub grub2_configured
{
return 1 if (-r (&grub2_config_value('default_file') || ''));
return 1 if (-r (&grub2_config_value('grub_cfg') || ''));
return 0;
}

# grub2_install_issues()
# Returns human-readable missing items for the module index.
sub grub2_install_issues
{
my @issues;
my $default_file = &grub2_config_value('default_file') || '';
my $grub_cfg = &grub2_config_value('grub_cfg') || '';
push(@issues, $default_file) if ($default_file ne '' && !-r $default_file);
push(@issues, $grub_cfg) if ($grub_cfg ne '' && !-r $grub_cfg);
push(@issues, &grub2_config_value('mkconfig_cmd') || 'grub-mkconfig')
	if (!&grub2_command('mkconfig_cmd'));
return @issues;
}

# grub2_default_keys()
# Returns settings edited by the structured defaults page.
sub grub2_default_keys
{
return qw(
	GRUB_DEFAULT
	GRUB_TIMEOUT_STYLE
	GRUB_TIMEOUT
	GRUB_TERMINAL_OUTPUT
	GRUB_GFXMODE
	GRUB_CMDLINE_LINUX_DEFAULT
	GRUB_CMDLINE_LINUX
	GRUB_DISABLE_RECOVERY
	GRUB_DISABLE_OS_PROBER
	GRUB_THEME
	GRUB_BACKGROUND
	GRUB_COLOR_NORMAL
	GRUB_COLOR_HIGHLIGHT
);
}

# grub2_bls_update_available([&entries])
# Returns true when existing BLS entries can be updated with grubby.
sub grub2_bls_update_available
{
my ($entries) = @_;
$entries ||= [ &grub2_boot_entries() ];
return 0 if (!&grub2_command('grubby_cmd'));
return (grep { ($_->{'source'} || '') eq 'bls' } @$entries) ? 1 : 0;
}

# grub2_defaults_updates_need_generate(&old-values, &updates, bls-args-updated?)
# Returns true when saved defaults still need grub-mkconfig regeneration.
sub grub2_defaults_updates_need_generate
{
my ($old_values, $updates, $bls_args_updated) = @_;
my %bls_updated = ref($bls_args_updated) eq 'HASH' ? %$bls_args_updated :
	$bls_args_updated ? (
		'GRUB_CMDLINE_LINUX' => 1,
		'GRUB_CMDLINE_LINUX_DEFAULT' => 1,
		) : ();
foreach my $key (keys %$updates) {
	my $old = defined($old_values->{$key}) ? $old_values->{$key} : '';
	my $new = defined($updates->{$key}) ? $updates->{$key} : '';
	next if ($old eq $new);
	# grubby already applied these BLS-facing changes to live entries.
	next if ($bls_updated{$key} &&
		 ($key eq 'GRUB_CMDLINE_LINUX' ||
		  $key eq 'GRUB_CMDLINE_LINUX_DEFAULT' ||
		  $key eq 'GRUB_DISABLE_RECOVERY'));
	return 1;
	}
return 0;
}

# grub2_password_file()
# Returns the managed GRUB password script path.
sub grub2_password_file
{
my $file = &grub2_config_value('password_file');
return $file if (defined($file) && $file ne '');
my $dir = &grub2_config_value('grub_dir') || '/etc/grub.d';
return "$dir/01_webmin_password";
}

# grub2_default_efi_directory()
# Returns a likely EFI system partition mount point, if one exists.
sub grub2_default_efi_directory
{
foreach my $dir ('/boot/efi', '/efi') {
	return $dir if (-d $dir);
	}
return '';
}

# grub2_default_bootloader_id([efi-dir])
# Returns a likely EFI boot loader ID from existing GRUB files.
sub grub2_default_bootloader_id
{
my ($efi_dir) = @_;
foreach my $file (&grub2_config_value('grub_cfg'),
		  &grub2_config_value('grubenv_file')) {
	next if (!defined($file));
	if ($file =~ m{\A/(?:boot/efi|efi)/EFI/([^/]+)/}) {
		return $1 if (&valid_bootloader_id_candidate($1));
		}
	}
$efi_dir ||= &grub2_default_efi_directory();
return '' if ($efi_dir eq '' || !-d "$efi_dir/EFI");
opendir(my $dh, "$efi_dir/EFI") || return '';
my @dirs = grep { -d "$efi_dir/EFI/$_" && &valid_bootloader_id_candidate($_) }
	   readdir($dh);
closedir($dh);
my @matches;
foreach my $dir (sort @dirs) {
	my $path = "$efi_dir/EFI/$dir";
	if (-e "$path/grub.cfg" || -e "$path/grubenv" ||
	    &efi_vendor_dir_has_loader($path)) {
		push(@matches, $dir);
		}
	}
return @matches == 1 ? $matches[0] : '';
}

# efi_vendor_dir_has_loader(dir)
# Returns true if an EFI vendor directory contains a likely GRUB/shim loader.
sub efi_vendor_dir_has_loader
{
my ($dir) = @_;
opendir(my $dh, $dir) || return 0;
my $found = grep { /^(?:grub.*|shim.*)\.efi\z/i && -f "$dir/$_" }
	    readdir($dh);
closedir($dh);
return $found ? 1 : 0;
}

# valid_bootloader_id_candidate(value)
# Returns true if a value is suitable for --bootloader-id.
sub valid_bootloader_id_candidate
{
my ($value) = @_;
return 0 if (!defined($value) || $value eq '');
return 0 if ($value =~ /[\r\n\0]/ || $value =~ /^-/ ||
	     $value !~ /\A[A-Za-z0-9_.+-]+\z/);
return 0 if ($value =~ /^(?:boot|microsoft)\z/i);
return 1;
}

# grub2_boot_mode([efi-firmware-dir])
# Returns uefi when the system booted via EFI firmware, or bios otherwise.
sub grub2_boot_mode
{
my ($efi_dir) = @_;
$efi_dir ||= '/sys/firmware/efi';
return -d $efi_dir ? 'uefi' : 'bios';
}

# grub2_secure_boot_status([efi-firmware-dir], [efivars-dir], [mokutil-cmd])
# Returns enabled, disabled, unknown, or not_applicable for Secure Boot.
sub grub2_secure_boot_status
{
my ($efi_dir, $efivars_dir, $mokutil_cmd) = @_;
$efi_dir ||= '/sys/firmware/efi';
return 'not_applicable' if (&grub2_boot_mode($efi_dir) ne 'uefi');
if (!defined($mokutil_cmd)) {
	$mokutil_cmd = &has_command('mokutil') || '';
	}
if ($mokutil_cmd ne '') {
	my $out = &backquote_command(
		quotemeta($mokutil_cmd).' --sb-state 2>&1 </dev/null', 1);
	if (!$?) {
		return 'enabled' if ($out =~ /SecureBoot\s+enabled/i);
		return 'disabled'
			if ($out =~ /SecureBoot\s+disabled/i ||
			    $out =~ /validation\s+is\s+disabled/i);
		}
	}
$efivars_dir ||= "$efi_dir/efivars";
my $efivar_status = &grub2_secure_boot_efivar_status($efivars_dir);
return $efivar_status if ($efivar_status);
return 'unknown';
}

# grub2_secure_boot_efivar_status(efivars-dir)
# Reads the SecureBoot EFI variable from efivarfs when mokutil is absent.
sub grub2_secure_boot_efivar_status
{
my ($efivars_dir) = @_;
return if (!defined($efivars_dir) || $efivars_dir eq '' ||
	   !-d $efivars_dir);
opendir(my $dh, $efivars_dir) || return;
my @vars = grep { /^SecureBoot-/ && -r "$efivars_dir/$_" } readdir($dh);
closedir($dh);
foreach my $var (@vars) {
	my $data = &read_file_contents("$efivars_dir/$var");
	next if (!defined($data) || length($data) < 5);
	return ord(substr($data, 4, 1)) ? 'enabled' : 'disabled';
	}
return;
}

# grub2_default_platform_target()
# Returns the likely grub-install platform target for this boot mode.
sub grub2_default_platform_target
{
my $machine = &backquote_command('uname -m 2>/dev/null </dev/null');
$machine =~ s/^\s+|\s+\z//g if (defined($machine));
if (&grub2_boot_mode() eq 'uefi') {
	return 'x86_64-efi' if ($machine =~ /^(?:x86_64|amd64)\z/i);
	return 'i386-efi' if ($machine =~ /^i[3-6]86\z/i);
	return 'arm64-efi' if ($machine =~ /^(?:aarch64|arm64)\z/i);
	return 'arm-efi' if ($machine =~ /^arm/i);
	return 'riscv64-efi' if ($machine =~ /^riscv64\z/i);
	}
return 'i386-pc' if ($machine =~ /^(?:x86_64|amd64|i[3-6]86)\z/i);
return '';
}

# grub2_platform_module_dirs(platform)
# Returns possible GRUB module directories for a platform target.
sub grub2_platform_module_dirs
{
my ($platform) = @_;
return () if (!defined($platform) || $platform eq '');
return (
	"/usr/lib/grub/$platform",
	"/usr/lib/grub2/$platform",
	"/usr/share/grub/$platform",
	"/usr/share/grub2/$platform",
);
}

# grub2_platform_module_dir(platform)
# Returns the first module directory containing modinfo.sh.
sub grub2_platform_module_dir
{
my ($platform) = @_;
foreach my $dir (&grub2_platform_module_dirs($platform)) {
	return $dir if (-r "$dir/modinfo.sh");
	}
return '';
}

# grub2_color_file()
# Returns the managed GRUB menu color generator script path.
sub grub2_color_file
{
my $file = &grub2_config_value('color_file');
return $file if (defined($file) && $file ne '');
my $dir = &grub2_config_value('grub_dir') || '/etc/grub.d';
return "$dir/06_webmin_colors";
}

# grub2_theme_dir()
# Returns the directory where Webmin installs GRUB themes.
sub grub2_theme_dir
{
my $dir = &grub2_config_value('theme_dir');
return $dir if (defined($dir) && $dir ne '');
my $cfg = &grub2_config_value('grub_cfg') || '';
return "$1/themes" if ($cfg =~ m{\A(/boot/grub2|/boot/grub)/});
return '/boot/grub2/themes' if (-d '/boot/grub2');
return '/boot/grub/themes';
}

# grub2_background_dir()
# Returns the directory where Webmin installs GRUB background images.
sub grub2_background_dir
{
my $dir = &grub2_config_value('background_dir');
return $dir if (defined($dir) && $dir ne '');
my $theme_dir = &grub2_theme_dir();
return "$1/backgrounds" if ($theme_dir =~ m{\A(.+)/themes/?\z});
my $cfg = &grub2_config_value('grub_cfg') || '';
return "$1/backgrounds" if ($cfg =~ m{\A(/boot/grub2|/boot/grub)/});
return '/boot/grub2/backgrounds' if (-d '/boot/grub2');
return '/boot/grub/backgrounds';
}

# grub2_color_names()
# Returns color names accepted by GRUB menu color settings.
sub grub2_color_names
{
return qw(
	black blue green cyan red magenta brown light-gray dark-gray
	light-blue light-green light-cyan light-red light-magenta yellow white
);
}

# grub2_validate_setting_path(value, label)
# Returns an error if a GRUB defaults path is not safe to save.
sub grub2_validate_setting_path
{
my ($value, $label) = @_;
return if (!defined($value) || $value eq '');
return &text('defaults_epath', $label) if ($value =~ /[\r\n\0]/);
return &text('defaults_eabspath', $label) if ($value !~ m{^/});
return &text('defaults_epathchars', $label)
	if ($value !~ m{\A/[A-Za-z0-9._/+ -]+\z});
return;
}

# grub2_validate_theme_path(value, label)
# Returns an error if a GRUB theme setting cannot affect generated menus.
sub grub2_validate_theme_path
{
my ($value, $label) = @_;
my $err = &grub2_validate_setting_path($value, $label);
return $err if ($err);
return if (!defined($value) || $value eq '');
return &text('defaults_etheme_archive', $value)
	if ($value =~ /\.(?:tar|tar\.(?:gz|bz2|xz|zst)|tgz|tbz2|txz|zip)\z/i);
return &text('defaults_etheme_file', $value) if (!-r $value || -d $value);
return;
}

# grub2_validate_background_path(value, label)
# Returns an error if a GRUB background image path is unusable.
sub grub2_validate_background_path
{
my ($value, $label) = @_;
my $err = &grub2_validate_setting_path($value, $label);
return $err if ($err);
return if (!defined($value) || $value eq '');
return &text('defaults_ebackground_file', $value) if (!-r $value || -d $value);
return &text('defaults_ebackground_type', $value)
	if ($value !~ /\.(?:png|jpe?g|tga)\z/i);
return;
}

# grub2_validate_gfxmode(value)
# Returns an error if a GRUB graphics mode setting is unsafe or malformed.
sub grub2_validate_gfxmode
{
my ($value) = @_;
$value = '' if (!defined($value));
return if ($value eq '');
return $text{'defaults_egfxmode'}
	if ($value !~
	    /\A(?:auto|keep|\d{3,5}x\d{3,5}(?:x\d{1,2})?)(?:,(?:auto|keep|\d{3,5}x\d{3,5}(?:x\d{1,2})?))*\z/);
return;
}

# grub2_install_theme_source(source)
# Installs a theme file, directory, archive, or URL under the GRUB boot tree.
sub grub2_install_theme_source
{
my ($source) = @_;
$source = '' if (!defined($source));
$source =~ s/^\s+|\s+\z//g;
return ('', $text{'defaults_etheme_source'}) if ($source eq '');

my ($file, $label, $cleanup, $err) = &grub2_prepare_theme_source($source);
return ('', $err) if ($err);
my ($theme_file, $tmpdir, $installed);
eval {
	my $type = &grub2_theme_archive_type($label || $file);
	if ($type) {
		# Archives are extracted only after their member list is validated.
		($tmpdir, $err) = &grub2_extract_theme_archive($file,
							       $type);
		die "$err\n" if ($err);
		$theme_file = &grub2_find_theme_file($tmpdir);
		die $text{'defaults_etheme_notfound'}."\n"
			if (!$theme_file);
		}
	else {
		# Direct sources may be a theme.txt file or a directory containing one.
		($theme_file, $err) = &grub2_theme_file_from_source($file);
		die "$err\n" if ($err);
		}
	($installed, $err) =
		&grub2_install_theme_directory(&grub2_dirname($theme_file),
					       $label || $file);
	die "$err\n" if ($err);
	1;
	} || do {
		$err = $@ || $!;
		$err =~ s/\s+\z// if (defined($err));
	};
if ($cleanup) {
	# Remove downloaded sources even when validation or install failed.
	if (-d $cleanup) {
		remove_tree($cleanup);
		}
	else {
		&grub2_unlink_temp($cleanup);
		}
	}
remove_tree($tmpdir) if ($tmpdir && -d $tmpdir);
return ('', $err) if ($err);
return ($installed);
}

# grub2_install_background_source(source)
# Copies a background image into the configured GRUB boot tree.
sub grub2_install_background_source
{
my ($source) = @_;
$source = '' if (!defined($source));
$source =~ s/^\s+|\s+\z//g;
return ('') if ($source eq '');
my $err = &grub2_validate_background_path($source,
					  $text{'defaults_background'});
return ('', $err) if ($err);
my $dir = &grub2_background_dir();
return ('', &text('defaults_econfigpath', $dir)) if ($dir !~ m{^/});
make_path($dir, { mode => 0755 }) if (!-d $dir);
return ('', &text('defaults_edir', $dir)) if (!-d $dir);
# Already-installed backgrounds can be reused without copying.
return ($source) if (&grub2_path_is_under($source, $dir));

my $base = basename($source);
# Sanitize the filename because the destination lives under /boot.
$base =~ s/[^A-Za-z0-9._+-]/_/g;
$base =~ s/\A[._-]+//;
$base = 'webmin-background.png' if ($base eq '');
my $dest = "$dir/$base";
$err = &grub2_copy_background_file($source, $dest);
return ('', $err) if ($err);
return ($dest);
}

# grub2_copy_background_file(source, destination)
# Copies one regular image file into a GRUB-readable location.
sub grub2_copy_background_file
{
my ($source, $dest) = @_;
my $real = eval { abs_path($source) };
return &text('defaults_ebackground_file', $source)
	if (!$real || !-f $real || !-r $real);
my $in;
return "$source : $!" if (!CORE::open($in, '<', $real));
CORE::binmode($in);
my $dir = &grub2_dirname($dest);
make_path($dir, { mode => 0755 }) if ($dir ne '' && !-d $dir);
open_tempfile(my $out, ">$dest");
my $buf;
my $err = '';
local $! = 0;
while (read($in, $buf, 32768)) {
	# Stream the copy so large images do not need to be loaded at once.
	print_tempfile($out, $buf);
	}
$err = "$!" if ($!);
my $cerr = close($in) ? '' : "$source : $!";
close_tempfile($out);
chmod(0644, $dest);
return $err if ($err);
return $cerr if ($cerr);
return;
}

# grub2_prepare_theme_source(source)
# Returns a local source file path for a local path or downloaded URL.
sub grub2_prepare_theme_source
{
my ($source) = @_;
if (&grub2_theme_source_is_url($source)) {
	# Remote sources are downloaded to a private temp directory first.
	return &grub2_download_theme_source($source);
	}
return ('', '', '', &text('defaults_eabspath', $text{'defaults_theme_source'}))
	if ($source !~ m{^/});
return ('', '', '', &text('defaults_etheme_file', $source))
	if (!-e $source || !-r $source);
return ($source, $source, '');
}

# grub2_theme_source_is_url(source)
# Returns true when a theme source is an HTTP, HTTPS, or FTP URL.
sub grub2_theme_source_is_url
{
my ($source) = @_;
return defined($source) && $source =~ m{\A(?:https?|ftp)://}i ? 1 : 0;
}

# grub2_download_theme_source(url)
# Downloads a remote theme source using Webmin's HTTP or FTP helpers.
sub grub2_download_theme_source
{
my ($url) = @_;
my ($host, $port, $page, $ssl, $user, $pass) = &parse_http_url($url);
return ('', '', 0, $text{'defaults_etheme_url'})
	if (!$host || !$page || ($ssl != 0 && $ssl != 1 && $ssl != 2));
my $base = $page;
$base =~ s/\?.*\z//;
$base = basename($base);
$base = 'theme-source' if ($base eq '' || $base =~ /\.\./);
# The downloaded filename is only a label; keep it filesystem-safe anyway.
$base =~ s/[^A-Za-z0-9._+-]/_/g;
my $tmpdir = &tempname("grub2-theme-download-$$-".int(rand(1000000)));
make_path($tmpdir, { mode => 0700 });
return ('', '', '', &text('defaults_edir', $tmpdir)) if (!-d $tmpdir);
my $temp = "$tmpdir/$base";
my $err = '';
if ($ssl == 2) {
	# parse_http_url uses ssl==2 for FTP URLs in Webmin helpers.
	my $ffile = $page;
	$ffile =~ s{\A/}{};
	&ftp_download($host, $ffile, $temp, \$err, undef, $user, $pass,
		      $port, 1);
	}
else {
	&http_download($host, $port, $page, $temp, \$err, undef, $ssl,
		       $user, $pass, 60, undef, 1);
	}
if ($err) {
	remove_tree($tmpdir);
	return ('', '', '', &text('defaults_etheme_download', $err));
	}
return ($temp, $url, $tmpdir);
}

# grub2_theme_archive_type(path-or-url)
# Returns the supported archive type for a source label.
sub grub2_theme_archive_type
{
my ($label) = @_;
$label = '' if (!defined($label));
$label =~ s/[?#].*\z//;
return 'targz' if ($label =~ /\.(?:tar\.gz|tgz)\z/i);
return 'tarbz2' if ($label =~ /\.(?:tar\.bz2|tbz2)\z/i);
return 'tarxz' if ($label =~ /\.(?:tar\.xz|txz)\z/i);
return 'tar' if ($label =~ /\.tar\z/i);
return 'zip' if ($label =~ /\.zip\z/i);
return '';
}

# grub2_theme_file_from_source(source)
# Returns a theme.txt file from a local source file or directory.
sub grub2_theme_file_from_source
{
my ($source) = @_;
if (-d $source) {
	my $theme = &grub2_find_theme_file($source);
	return ($theme) if ($theme);
	return ('', $text{'defaults_etheme_notfound'});
	}
return ('', &text('defaults_etheme_file', $source)) if (!-f $source);
return ($source) if (basename($source) eq 'theme.txt');
return ('', &text('defaults_etheme_nottheme', $source));
}

# grub2_extract_theme_archive(file, type)
# Extracts a validated theme archive into a private temporary directory.
sub grub2_extract_theme_archive
{
my ($file, $type) = @_;
my ($list_cmd, $err) = &grub2_archive_command($type, $file, 'list');
return ('', $err) if ($err);
# Validate the listing before extracting anything to disk.
my $out = &backquote_command($list_cmd.' 2>&1 </dev/null');
return ('', $out || $text{'defaults_etheme_archive_list'}) if ($?);
$err = &grub2_validate_archive_members(split(/\r?\n/, $out || ''));
return ('', $err) if ($err);

my $tmpdir = &tempname("grub2-theme-extract-$$-".int(rand(1000000)));
make_path($tmpdir, { mode => 0700 });
return ('', &text('defaults_edir', $tmpdir)) if (!-d $tmpdir);
my ($extract_cmd, $xerr) = &grub2_archive_command($type, $file, 'extract',
						 $tmpdir);
if ($xerr) {
	remove_tree($tmpdir);
	return ('', $xerr);
	}
# Validate again after extraction to catch symlinks or unusual archive output.
$out = &backquote_command($extract_cmd.' 2>&1 </dev/null');
if ($?) {
	remove_tree($tmpdir);
	return ('', $out || $text{'defaults_etheme_extract'});
	}
$err = &grub2_validate_extracted_theme_tree($tmpdir);
if ($err) {
	remove_tree($tmpdir);
	return ('', $err);
	}
return ($tmpdir);
}

# grub2_archive_command(type, file, mode, [directory])
# Returns a tar or unzip command for listing or extracting an archive.
sub grub2_archive_command
{
my ($type, $file, $mode, $dir) = @_;
if ($type eq 'zip') {
	my $unzip = &has_command('unzip');
	return ('', &text('defaults_etheme_cmd', 'unzip')) if (!$unzip);
	return ($mode eq 'list' ?
		quotemeta($unzip).' -Z -l '.quotemeta($file) :
		quotemeta($unzip).' -q -o '.quotemeta($file).
		' -d '.quotemeta($dir));
	}
my $tar = &has_command('tar');
return ('', &text('defaults_etheme_cmd', 'tar')) if (!$tar);
my %flags = (
	'tar' => [ 'tvf', 'xf' ],
	'targz' => [ 'tzvf', 'xzf' ],
	'tarbz2' => [ 'tjvf', 'xjf' ],
	'tarxz' => [ 'tJvf', 'xJf' ],
);
return ('', $text{'defaults_etheme_type'}) if (!$flags{$type});
my $flag = $mode eq 'list' ? $flags{$type}->[0] : $flags{$type}->[1];
my $cmd = quotemeta($tar).' '.$flag.' '.quotemeta($file);
$cmd .= ' -C '.quotemeta($dir) if ($mode ne 'list');
return ($cmd);
}

# grub2_validate_archive_members(member, ...)
# Rejects archive paths that could write outside the extraction directory.
sub grub2_validate_archive_members
{
foreach my $raw (@_) {
	my ($member, $type) = &grub2_archive_member_from_list_line($raw);
	next if (!defined($member));
	$member =~ s/^\s+|\s+\z//g;
	next if ($member eq '');
	# Permit regular files and directories only; reject links and devices.
	return &text('defaults_etheme_member', $member)
		if (defined($type) && $type !~ /^[-d]\z/);
	# Prevent archive traversal, absolute paths, and Windows separators.
	return &text('defaults_etheme_member', $member)
		if ($member =~ m{\A/} ||
		    $member =~ m{(?:\A|/)\.\.(?:/|\z)} ||
		    $member =~ /[\0\\]/);
	}
return;
}

# grub2_archive_member_from_list_line(line)
# Returns an archive member path and type from tar or zip verbose output.
sub grub2_archive_member_from_list_line
{
my ($line) = @_;
return if (!defined($line));
$line =~ s/^\s+|\s+\z//g;
return if ($line eq '' || $line =~ /^Archive:/ ||
	   $line =~ /^Zip file size:/ || $line =~ /^\d+\s+files?,/);
if ($line =~ /^([A-Za-z-])[-A-Za-z]+\s+\S+\s+\S+\s+\d+\s+\S+\s+\d+\s+\S+\s+\S+\s+\S+\s+(.+)\z/) {
	return ($2, $1);
	}
if ($line =~ /^([A-Za-z-])[-A-Za-z]+\s+\S+\s+\d+\s+\S+\s+\S+\s+(.+)\z/) {
	return ($2, $1);
	}
if ($line =~ /^([A-Za-z-])[-A-Za-z]+\s+\S+\s+\S+\s+\d+\s+\S+\s+\S+\s+(.+)\z/) {
	return ($2, $1);
	}
return ($line, '-');
}

# grub2_validate_extracted_theme_tree(dir)
# Rejects unsafe extracted files before copying to /boot.
sub grub2_validate_extracted_theme_tree
{
my ($dir) = @_;
my $root = eval { abs_path($dir) };
return &text('defaults_edir', $dir) if (!$root);
my $err;
find({
	no_chdir => 1,
	wanted => sub {
		return if ($err);
		my $path = $File::Find::name;
		return if ($path eq $dir);
		my @st = lstat($path);
		if (!@st || (!-d _ && !&grub2_theme_regular_source($path,
								   $root))) {
			$err = &text('defaults_etheme_member', $path);
			}
		},
	}, $dir);
return $err;
}

# grub2_find_theme_file(dir)
# Finds the most likely theme.txt under a source directory.
sub grub2_find_theme_file
{
my ($dir) = @_;
my @themes;
find({
	no_chdir => 1,
	wanted => sub {
		push(@themes, $File::Find::name)
			if (-f $File::Find::name &&
			    basename($File::Find::name) eq 'theme.txt');
		},
	}, $dir);
@themes = sort {
	my $ad = () = $a =~ /\//g;
	my $bd = () = $b =~ /\//g;
	$ad <=> $bd || length($a) <=> length($b) || $a cmp $b;
	} @themes;
return $themes[0] || '';
}

# grub2_install_theme_directory(source-dir, source-label)
# Copies one theme directory into the configured GRUB theme directory.
sub grub2_install_theme_directory
{
my ($srcdir, $label) = @_;
my $theme_dir = &grub2_theme_dir();
return ('', &text('defaults_econfigpath', $theme_dir))
	if ($theme_dir !~ m{^/});
make_path($theme_dir, { mode => 0755 }) if (!-d $theme_dir);
return ('', &text('defaults_edir', $theme_dir)) if (!-d $theme_dir);
my $theme_file = "$srcdir/theme.txt";
return ('', $text{'defaults_etheme_notfound'}) if (!-r $theme_file);
return ($theme_file) if (&grub2_path_is_under($theme_file, $theme_dir));

my $name = &grub2_safe_theme_name(basename($srcdir));
if ($name eq '' || $name =~ /^grub2-theme-(?:download|extract)/) {
	$name = &grub2_safe_theme_name(&grub2_theme_source_name($label));
	}
$name = 'webmin-theme' if ($name eq '');
my $dest = &grub2_unique_theme_destination($theme_dir, $name);
my $err = &grub2_copy_theme_tree($srcdir, $dest);
if ($err) {
	remove_tree($dest) if (-d $dest);
	return ('', $err);
	}
return ("$dest/theme.txt");
}

# grub2_theme_source_name(source-label)
# Returns a useful theme name from a source path or URL.
sub grub2_theme_source_name
{
my ($label) = @_;
$label = '' if (!defined($label));
$label =~ s/[?#].*\z//;
if ($label =~ m{/theme\.txt\z}i) {
	$label =~ s{/theme\.txt\z}{};
	}
my $name = basename($label);
$name =~ s/\.(?:tar\.gz|tar\.bz2|tar\.xz|tgz|tbz2|txz|tar|zip)\z//i;
$name =~ s/\.theme\z//i;
return $name;
}

# grub2_safe_theme_name(name)
# Normalizes a directory name for installing under the GRUB theme directory.
sub grub2_safe_theme_name
{
my ($name) = @_;
$name = '' if (!defined($name));
$name =~ s/^\s+|\s+\z//g;
$name =~ s/[^A-Za-z0-9._+-]+/_/g;
$name =~ s/\A[._-]+//;
$name =~ s/[._-]+\z//;
return $name;
}

# grub2_unique_theme_destination(parent, name)
# Returns a non-existing destination directory for a copied theme.
sub grub2_unique_theme_destination
{
my ($parent, $name) = @_;
my $dest = "$parent/$name";
return $dest if (!-e $dest);
for (my $i = 1; $i < 1000; $i++) {
	my $try = "$parent/$name-$i";
	return $try if (!-e $try);
	}
return "$parent/$name-".time();
}

# grub2_path_is_under(path, parent)
# Returns true if a path is already below a parent directory.
sub grub2_path_is_under
{
my ($path, $parent) = @_;
my $p = eval { abs_path($path) };
my $d = eval { abs_path($parent) };
return 0 if (!$p || !$d);
return $p eq $d || index($p, $d.'/') == 0 ? 1 : 0;
}

# grub2_copy_theme_tree(source, destination)
# Copies regular theme files into a new GRUB-readable directory.
sub grub2_copy_theme_tree
{
my ($src, $dest) = @_;
my $src_abs = eval { abs_path($src) };
return &text('defaults_etheme_file', $src) if (!$src_abs);
my $err;
find({
	no_chdir => 1,
	wanted => sub {
		return if ($err);
		my $path = $File::Find::name;
		my $rel = substr($path, length($src_abs));
		$rel =~ s{\A/}{};
		return if ($rel eq '');
		if ($rel =~ m{(?:\A|/)\.\.(?:/|\z)}) {
			$err = &text('defaults_etheme_member', $rel);
			return;
			}
		my $target = "$dest/$rel";
		my @st = lstat($path);
		if (!@st) {
			$err = &text('defaults_etheme_member', $rel);
			return;
			}
		if (-d _) {
			make_path($target, { mode => 0755 });
			return;
			}
		my $source = &grub2_theme_regular_source($path, $src_abs);
		if (!$source) {
			$err = &text('defaults_etheme_member', $rel);
			return;
			}
		my $tdir = &grub2_dirname($target);
		make_path($tdir, { mode => 0755 }) if (!-d $tdir);
		my $in;
		if (!CORE::open($in, '<', $source)) {
			$err = "$source : $!";
			return;
		}
		CORE::binmode($in);
		open_tempfile(my $out, ">$target");
		my $buf;
		while (read($in, $buf, 32768)) {
			print_tempfile($out, $buf);
			}
		if (!close($in)) {
			$err = "$path : $!";
			}
		close_tempfile($out);
		chmod(0644, $target);
		},
	}, $src_abs);
return $err;
}

# grub2_theme_regular_source(path, source-root)
# Returns a safe regular source file, dereferencing in-tree symlinks only.
sub grub2_theme_regular_source
{
my ($path, $root) = @_;
my @st = lstat($path);
return if (!@st);
if (-l _) {
	my $real = eval { abs_path($path) };
	return if (!$real || !&grub2_resolved_path_is_under($real, $root));
	return $real if (-f $real);
	return;
	}
return $path if (-f _);
return;
}

# grub2_resolved_path_is_under(path, resolved-parent)
# Returns true if a resolved path is below a resolved parent directory.
sub grub2_resolved_path_is_under
{
my ($path, $parent) = @_;
return 0 if (!defined($path) || !defined($parent) ||
	     $path eq '' || $parent eq '');
return $path eq $parent || index($path, $parent.'/') == 0 ? 1 : 0;
}

# read_grub_defaults([file])
# Reads and parses a GRUB default settings file.
sub read_grub_defaults
{
my ($file) = @_;
$file ||= &grub2_config_value('default_file');
my $data = '';
if ($file && -r $file) {
	$data = &read_file_contents($file);
	}
return &parse_grub_defaults_text($data, $file);
}

# parse_grub_defaults_text(text, [file])
# Parses shell-style GRUB default assignments while preserving all lines.
sub parse_grub_defaults_text
{
my ($data, $file) = @_;
$data = '' if (!defined($data));
$data =~ s/\r\n/\n/g;
$data =~ s/\r/\n/g;
my @lines = split(/\n/, $data);
my @parsed;
my %values;
my %assignments;
for (my $i = 0; $i < @lines; $i++) {
	my $line = $lines[$i];
	my $entry = { 'raw' => $line, 'line' => $i };
	if ($line =~ /^(\s*)(export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)\z/) {
		# Preserve formatting metadata so saving can make minimal diffs.
		my ($indent, $export, $key, $rest) = ($1, $2 || '', $3, $4);
		my ($raw_value, $comment) = &split_shell_comment($rest);
		$entry->{'type'} = 'assignment';
		$entry->{'indent'} = $indent;
		$entry->{'export'} = $export ? 1 : 0;
		$entry->{'key'} = $key;
		$entry->{'raw_value'} = $raw_value;
		$entry->{'comment'} = $comment;
		$entry->{'value'} = &decode_shell_value($raw_value);
		$values{$key} = $entry->{'value'};
		push(@{$assignments{$key}}, $entry);
	}
else {
	# Comments and unknown shell code are carried through unchanged.
	$entry->{'type'} = 'raw';
	}
	push(@parsed, $entry);
	}
return {
	'file' => $file,
	'lines' => \@parsed,
	'values' => \%values,
	'assignments' => \%assignments,
};
}

# split_shell_comment(text)
# Splits a shell assignment value from a trailing unquoted comment.
sub split_shell_comment
{
my ($text) = @_;
my $quote = '';
my $escape = 0;
for (my $i = 0; $i < length($text); $i++) {
	my $ch = substr($text, $i, 1);
	if ($escape) {
		# Inside double quotes, escaped characters cannot start comments.
		$escape = 0;
		next;
		}
	if ($quote eq '"') {
		if ($ch eq '\\') {
			$escape = 1;
			}
		elsif ($ch eq '"') {
			$quote = '';
			}
		next;
		}
	if ($quote eq "'") {
		$quote = '' if ($ch eq "'");
		next;
		}
	if ($ch eq '"' || $ch eq "'") {
		$quote = $ch;
		next;
		}
	if ($ch eq '#') {
		my $before = $i == 0 ? '' : substr($text, $i - 1, 1);
		if ($i == 0 || $before =~ /\s/) {
			# Shell comments start at # only when it begins a word.
			my $value = substr($text, 0, $i);
			my $comment = substr($text, $i);
			$value =~ s/\s+\z//;
			return ($value, $comment);
			}
		}
	}
$text =~ s/\s+\z//;
return ($text, '');
}

# decode_shell_value(value)
# Returns a display value for a simple shell assignment value.
sub decode_shell_value
{
my ($value) = @_;
$value = '' if (!defined($value));
$value =~ s/^\s+|\s+\z//g;
if ($value =~ /^'(.*)'\z/s) {
	return $1;
	}
if ($value =~ /^"(.*)"\z/s) {
	my $inner = $1;
	$inner =~ s/\\(["\\\$`])/$1/g;
	return $inner;
	}
return $value;
}

# format_shell_value(key, value)
# Formats a Perl string as a conservative shell assignment value.
sub format_shell_value
{
my ($key, $value) = @_;
$value = '' if (!defined($value));
if ($key eq 'GRUB_TIMEOUT' && $value =~ /^-?\d+\z/) {
	# Numeric timeout values should remain bare for readability.
	return $value;
	}
if ($key =~ /^GRUB_DISABLE_/ && $value =~ /^(true|false)\z/) {
	# GRUB boolean defaults are conventionally unquoted.
	return $value;
	}
if ($value =~ /^[A-Za-z0-9_.,:\/+=-]+\z/) {
	return $value;
	}
$value =~ s/(["\\\$`])/\\$1/g;
return '"'.$value.'"';
}

# format_grub_assignment(&line, key, value)
# Returns one shell assignment line, preserving indentation and export.
sub format_grub_assignment
{
my ($line, $key, $value) = @_;
my $prefix = $line && defined($line->{'indent'}) ? $line->{'indent'} : '';
$prefix .= 'export ' if ($line && $line->{'export'});
my $comment = $line && defined($line->{'comment'}) && $line->{'comment'} ne ''
	? ' '.$line->{'comment'} : '';
return $prefix.$key.'='.&format_shell_value($key, $value).$comment;
}

# set_grub_default_values(&parsed, &updates)
# Returns full default-file text with selected assignments updated.
sub set_grub_default_values
{
my ($parsed, $updates) = @_;
my %seen;
my @out;
foreach my $line (@{$parsed->{'lines'}}) {
	my $key = $line->{'key'};
	# Older Webmin blocks are removed instead of perpetuated.
	next if (($line->{'raw'} || '') =~ /^\s*#\s*Added by Webmin\s*\z/);
	if ($line->{'type'} eq 'assignment' && exists($updates->{$key})) {
		$seen{$key} = 1;
		if (defined($updates->{$key})) {
			# Update the first matching assignment in place.
			push(@out, &format_grub_assignment($line, $key,
							   $updates->{$key}));
			}
		next;
		}
	push(@out, $line->{'raw'});
	}
my @missing = grep { exists($updates->{$_}) && !$seen{$_} &&
		     defined($updates->{$_}) } &grub2_default_keys();
if (@missing) {
	push(@out, '') if (@out && $out[-1] ne '');
	foreach my $key (@missing) {
		# Append settings not already present, in the module's stable order.
		push(@out, &format_grub_assignment(undef, $key,
						   $updates->{$key}));
		}
	}
pop(@out) while (@out && $out[-1] eq '');
return join("\n", @out)."\n";
}

# validate_grub_defaults_text(text, [file])
# Validates the shell syntax of a GRUB default settings file.
sub validate_grub_defaults_text
{
my ($data, $file) = @_;
$file ||= &grub2_config_value('default_file') || '/etc/default/grub';
return &text('defaults_econfigpath', $file) if ($file !~ m{^/});
my $dir = &grub2_dirname($file);
return &text('defaults_edir', $dir) if ($dir eq '' || !-d $dir);
my ($temp, $terr) = &grub2_make_temp_file($dir, 'defaults', $data);
return $terr if ($terr);
my ($out, $failed);
my $die;
eval {
	my $shell = &grub2_command('shell_cmd') ||
		    &grub2_config_value('shell_cmd') || '/bin/sh';
	$out = &backquote_command(
		quotemeta($shell).' -n '.quotemeta($temp).
		' 2>&1 </dev/null');
	$failed = $?;
	1;
	} || do { $die = $@ || $!; };
&grub2_unlink_temp($temp);
return $die if ($die);
if ($failed) {
	$out =~ s/^\s+|\s+\z//g if (defined($out));
	return $out || 'shell syntax check failed';
	}
return;
}

# save_grub_defaults_values(&updates)
# Validates and writes selected GRUB default settings.
sub save_grub_defaults_values
{
my ($updates) = @_;
my $file = &grub2_config_value('default_file');
my $parsed = &read_grub_defaults($file);
my $data = &set_grub_default_values($parsed, $updates);
my $err = &validate_grub_defaults_text($data, $file);
return $err if ($err);
open_lock_tempfile(my $fh, ">$file");
print_tempfile($fh, $data);
close_tempfile($fh);
return;
}

# grub2_manual_files()
# Returns descriptors for files allowed in the manual editor.
sub grub2_manual_files
{
my @files;
my %seen;
my $default_file = &grub2_config_value('default_file');
my $custom_file = &grub2_config_value('custom_file');
# Always include the primary structured files first for predictable menus.
&add_grub2_manual_file(\@files, \%seen, 'default_file', $default_file,
		       'default');
&add_grub2_manual_file(\@files, \%seen, 'custom_file', $custom_file,
		       'custom');

my $grub_dir = &grub2_config_value('grub_dir') || '';
if ($grub_dir ne '' && -d $grub_dir && opendir(my $dh, $grub_dir)) {
	foreach my $base (sort readdir($dh)) {
		# Hide dotfiles and only expose regular generator/text files.
		next if ($base =~ /^\./);
		my $file = "$grub_dir/$base";
		next if (!-f $file);
		my $type = defined($custom_file) && $file eq $custom_file ? 'custom' :
			   (-x $file || $base =~ /^\d+_/) ? 'grub_script' :
			   'text';
		&add_grub2_manual_file(\@files, \%seen, 'grub_dir', $file,
				       $type);
		}
	closedir($dh);
	}

my $bls_dir = &grub2_config_value('bls_dir') || '';
if ($bls_dir ne '' && -d $bls_dir && opendir(my $dh, $bls_dir)) {
	foreach my $base (sort readdir($dh)) {
		# Disabled rescue files deliberately do not appear in the editor.
		next if ($base =~ /^\./ || $base !~ /\.conf\z/);
		my $file = "$bls_dir/$base";
		next if (!-f $file);
		&add_grub2_manual_file(\@files, \%seen, 'bls_dir', $file,
				       'bls');
		}
	closedir($dh);
	}

return @files;
}

# add_grub2_manual_file(&files, &seen, key, file, type)
# Adds one allowlisted file descriptor, preserving first-seen ordering.
sub add_grub2_manual_file
{
my ($files, $seen, $key, $file, $type) = @_;
return if (!defined($file) || $file eq '' || $seen->{$file}++);
push(@$files, { 'key' => $key, 'file' => $file, 'type' => $type });
}

# grub2_manual_file(file)
# Returns the manual-edit descriptor for an allowed file path.
sub grub2_manual_file
{
my ($file) = @_;
foreach my $f (&grub2_manual_files()) {
	return $f if ($f->{'file'} eq $file);
	}
return;
}

# validate_manual_grub_file(file, data)
# Validates a manually edited GRUB file where a safe validator exists.
sub validate_manual_grub_file
{
my ($file, $data) = @_;
my $info = &grub2_manual_file($file);
return $text{'manual_efile'} if (!$info);
if ($info->{'type'} eq 'default') {
	# /etc/default/grub is shell syntax, so validate with sh.
	return &validate_grub_defaults_text($data, $file);
	}
if ($info->{'type'} eq 'grub_script') {
	# /etc/grub.d scripts are shell fragments executed by grub-mkconfig.
	return &validate_grub_defaults_text($data, $file);
	}
if ($info->{'type'} eq 'custom') {
	# Wrap custom menuentry bodies before running grub-script-check.
	return &grub2_validate_grub_script_text(
		&grub2_custom_script_text($data), $file);
	}
if ($info->{'type'} eq 'bls') {
	return &validate_bls_entry_text($data);
	}
return;
}

# validate_bls_entry_text(text)
# Validates the key/value syntax used by Boot Loader Specification entries.
sub validate_bls_entry_text
{
my ($data) = @_;
$data = '' if (!defined($data));
return $text{'manual_ebls'} if ($data =~ /\0/);
my $seen;
my $line_no = 0;
foreach my $line (split(/\n/, $data, -1)) {
	$line_no++;
	next if ($line =~ /^\s*(?:#|\z)/);
	# BLS lines are simple keys followed by a non-empty value.
	if ($line !~ /^\s*[A-Za-z0-9_.-]+\s+\S/) {
		return &text('manual_eblsline', $line_no);
		}
	$seen = 1;
	}
return $text{'manual_ebls'} if (!$seen);
return;
}

# save_manual_grub_file(file, data)
# Writes one allowlisted GRUB file from the manual editor.
sub save_manual_grub_file
{
my ($file, $data) = @_;
my $info = &grub2_manual_file($file);
return $text{'manual_efile'} if (!$info);
my $err = &validate_manual_grub_file($file, $data);
return $err if ($err);
if ($info->{'type'} eq 'custom') {
	# Custom saves preserve executable mode and use the custom writer path.
	return &grub2_with_file_lock($file, sub {
		&grub2_write_custom_file($file, $data);
		return;
		});
	}
open_lock_tempfile(my $fh, ">$file");
print_tempfile($fh, $data);
close_tempfile($fh);
return;
}

# grub2_read_security_config([file])
# Returns the current Webmin-managed GRUB password state.
sub grub2_read_security_config
{
my ($file) = @_;
$file ||= &grub2_password_file();
my %rv = (
	'file' => $file,
	'exists' => -e $file ? 1 : 0,
	'managed' => 1,
	'enabled' => 0,
	'user' => 'root',
	'hash' => '',
	);
return \%rv if (!-e $file);
if (!-r $file) {
	# Existing but unreadable files are treated as unmanaged for safety.
	$rv{'managed'} = 0;
	$rv{'unreadable'} = 1;
	return \%rv;
	}
my $data = &read_file_contents($file);
if ($data !~ /Webmin managed GRUB password protection/) {
	# Do not parse or overwrite administrator-owned password scripts.
	$rv{'managed'} = 0;
	return \%rv;
	}
if ($data =~ /^\s*password_pbkdf2\s+((?:"(?:\\.|[^"])*")|(?:'[^']*')|\S+)\s+(grub\.pbkdf2\.[A-Za-z0-9.]+)\s*$/m) {
	# Enabled state requires both a superuser token and a PBKDF2 hash.
	my ($user) = &parse_grub_word($1);
	$rv{'enabled'} = 1;
	$rv{'user'} = $user if (defined($user) && $user ne '');
	$rv{'hash'} = $2;
	}
elsif ($data =~ /^\s*set\s+superusers=((?:"(?:\\.|[^"])*")|(?:'[^']*')|\S+)/m) {
	my ($user) = &parse_grub_word($1);
	$rv{'user'} = $user if (defined($user) && $user ne '');
	}
return \%rv;
}

# grub2_save_security_config(&settings)
# Saves the Webmin-managed GRUB password protection script.
sub grub2_save_security_config
{
my ($settings) = @_;
my $file = &grub2_password_file();
return &text('defaults_econfigpath', $file) if ($file !~ m{^/});
my $dir = &grub2_dirname($file);
return &text('defaults_edir', $dir) if ($dir eq '' || !-d $dir);
my $current = &grub2_read_security_config($file);
return $text{'security_eunmanaged'}
	if ($current->{'exists'} && !$current->{'managed'});

my $enabled = $settings->{'enabled'} ? 1 : 0;
my $user = defined($settings->{'user'}) && $settings->{'user'} ne '' ?
	$settings->{'user'} : ($current->{'user'} || 'root');
my $hash = $current->{'hash'} || '';

if ($enabled) {
	my $err = &grub2_validate_security_user($user);
	return $err if ($err);
	my $newhash = $settings->{'hash'} || '';
	my $pass = $settings->{'password'} || '';
	my $pass2 = $settings->{'password2'} || '';
	$newhash = '' if ($newhash ne '' && $newhash eq $hash);
	if ($newhash ne '' && ($pass ne '' || $pass2 ne '')) {
		# Avoid ambiguity between pasted hashes and newly entered passwords.
		return $text{'security_epassmode'};
		}
	if ($newhash ne '') {
		# A pasted PBKDF2 hash replaces the stored hash without clear text.
		$err = &grub2_validate_password_hash($newhash);
		return $err if ($err);
		$hash = $newhash;
		}
	elsif ($pass ne '' || $pass2 ne '') {
		# Generate a fresh PBKDF2 hash only when password fields are used.
		($hash, $err) = &grub2_make_password_hash($pass, $pass2);
		return $err if ($err);
		}
	return $text{'security_epass'} if ($hash eq '');
	}
return if (!$enabled && !$current->{'exists'});

my $data = &grub2_format_password_script($enabled, $user, $hash);
my $err = &validate_grub_defaults_text($data, $file);
return $err if ($err);
if ($enabled) {
	# Validate the emitted GRUB commands separately from the shell wrapper.
	$err = &grub2_validate_grub_script_text(
		&grub2_format_password_grub_script($user, $hash), $file);
	return $err if ($err);
	}
return &grub2_with_file_lock($file, sub {
	&grub2_write_password_file($file, $data);
	return;
	});
}

# grub2_validate_security_user(user)
# Returns an error if a GRUB superuser name is unsafe.
sub grub2_validate_security_user
{
my ($user) = @_;
$user = '' if (!defined($user));
return $text{'security_euser'}
	if ($user eq '' || $user =~ /[\r\n\0]/ ||
	    $user !~ /\A[A-Za-z0-9_.@+-]+\z/ || $user =~ /^-/);
return;
}

# grub2_validate_password_hash(hash)
# Returns an error if a pasted GRUB PBKDF2 hash is unsafe.
sub grub2_validate_password_hash
{
my ($hash) = @_;
$hash = '' if (!defined($hash));
return $text{'security_ehash'}
	if ($hash !~ /\Agrub\.pbkdf2\.[A-Za-z0-9.]+\z/);
return;
}

# grub2_make_password_hash(password, confirmation)
# Runs grub-mkpasswd-pbkdf2 and returns (hash, error).
sub grub2_make_password_hash
{
my ($pass, $pass2) = @_;
$pass = '' if (!defined($pass));
$pass2 = '' if (!defined($pass2));
return ('', $text{'security_epass'}) if ($pass eq '');
return ('', $text{'security_epassmatch'}) if ($pass ne $pass2);
return ('', $text{'security_epasschars'}) if ($pass =~ /[\r\n\0]/);
my $cmd = &grub2_command('mkpasswd_cmd');
return ('', $text{'security_emkpasswd'}) if (!$cmd);
my $input = $pass."\n".$pass."\n";
# Feed the password twice on stdin, matching grub-mkpasswd-pbkdf2 prompts.
my $out = '';
my $outref = \$out;
my $rv = &execute_command(quotemeta($cmd), \$input, $outref, $outref, 0, 1);
if ($rv) {
	$out =~ s/^\s+|\s+\z//g;
	return ('', $out || $text{'security_ehashgen'});
	}
if ($out =~ /(grub\.pbkdf2\.[A-Za-z0-9.]+)/) {
	return ($1);
	}
return ('', $text{'security_ehashgen'});
}

# grub2_format_password_script(enabled?, user, hash)
# Returns a shell generator script managed by Webmin.
sub grub2_format_password_script
{
my ($enabled, $user, $hash) = @_;
my $header = "#!/bin/sh\n".
	"# Webmin managed GRUB password protection\n".
	"# Edit this file from Webmin's GRUB 2 module.\n";
return $header."exit 0\n" if (!$enabled);
return $header."cat <<'EOF'\n".
	&grub2_format_password_grub_script($user, $hash).
	"EOF\n";
}

# grub2_format_password_grub_script(user, hash)
# Returns GRUB commands that configure one password-protected superuser.
sub grub2_format_password_grub_script
{
my ($user, $hash) = @_;
return 'set superusers='.&grub2_quote_word($user)."\n".
       "export superusers\n".
       "password_pbkdf2 $user $hash\n";
}

# grub2_write_password_file(file, data)
# Writes the managed password script with root-only execute permissions.
sub grub2_write_password_file
{
my ($file, $data) = @_;
open_tempfile(my $fh, ">$file");
print_tempfile($fh, $data);
close_tempfile($fh);
chmod(0700, $file);
return;
}

# grub2_save_color_script()
# Saves the Webmin-managed generator script for GRUB menu colors.
sub grub2_save_color_script
{
my $file = &grub2_color_file();
return &text('defaults_econfigpath', $file) if ($file !~ m{^/});
my $dir = &grub2_dirname($file);
return &text('defaults_edir', $dir) if ($dir eq '' || !-d $dir);
if (-e $file) {
	return $text{'defaults_ecolorfile'} if (!-r $file);
	my $current = &read_file_contents($file);
	# Never overwrite administrator-owned GRUB generator scripts.
	return $text{'defaults_ecolorfile'}
		if ($current !~ /Webmin managed GRUB menu colors/);
	}
my $data = &grub2_format_color_script();
my $err = &validate_grub_defaults_text($data, $file);
return $err if ($err);
return &grub2_with_file_lock($file, sub {
	&grub2_write_color_file($file, $data);
	return;
	});
}

# grub2_format_color_script()
# Returns a shell generator script that emits GRUB menu color commands.
sub grub2_format_color_script
{
my $default_file = &grub2_config_value('default_file') || '/etc/default/grub';
my $source = '';
if ($default_file =~ m{^/} && $default_file !~ /[\r\n\0]/) {
	# Source defaults at generation time so color changes need one script only.
	$source = 'webmin_grub2_defaults_file='.
		  &format_shell_value('WEBMIN_GRUB2_DEFAULTS_FILE',
				      $default_file)."\n".
		  "if [ -r \"\$webmin_grub2_defaults_file\" ]; then\n".
		  "\t. \"\$webmin_grub2_defaults_file\"\n".
		  "fi\n\n";
	}
my $script = <<'EOF';
#!/bin/sh
# Webmin managed GRUB menu colors
# Reads GRUB_COLOR_NORMAL and GRUB_COLOR_HIGHLIGHT from the GRUB defaults file.

EOF
$script .= $source;
$script .= <<'EOF';

webmin_grub2_emit_color()
{
	name=$1
	value=$2
	case "$value" in
		''|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_/-]*|*/*/*)
			return
			;;
	esac
	case "$value" in
		*/*)
			printf 'set %s=%s\n' "$name" "$value"
			;;
	esac
}

webmin_grub2_emit_color color_normal "$GRUB_COLOR_NORMAL"
webmin_grub2_emit_color color_highlight "$GRUB_COLOR_HIGHLIGHT"
webmin_grub2_emit_color menu_color_normal "$GRUB_COLOR_NORMAL"
webmin_grub2_emit_color menu_color_highlight "$GRUB_COLOR_HIGHLIGHT"
EOF
return $script;
}

# grub2_write_color_file(file, data)
# Writes the managed color generator script with executable permissions.
sub grub2_write_color_file
{
my ($file, $data) = @_;
open_tempfile(my $fh, ">$file");
print_tempfile($fh, $data);
close_tempfile($fh);
chmod(0755, $file);
return;
}

# grub2_boot_entries([file])
# Parses generated grub.cfg menuentry and submenu lines.
sub grub2_boot_entries
{
my ($file) = @_;
$file ||= &grub2_config_value('grub_cfg');
return () if (!$file || !-r $file);
my $data = &read_file_contents($file);
$data =~ s/\r\n/\n/g;
$data =~ s/\r/\n/g;
my @lines = split(/\n/, $data);
my @entries;
my @submenus;
my $section_file = $file;
my $depth = 0;
for (my $i = 0; $i < @lines; $i++) {
	my $line = $lines[$i];
	if ($line =~ /^### BEGIN (.+) ###\s*\z/) {
		# grub-mkconfig annotates which generator script emitted following lines.
		$section_file = $1;
		}
	elsif ($line =~ /^### END /) {
		$section_file = $file;
		}
	elsif ($line =~ /^\s*blscfg\s*$/) {
		# blscfg imports BLS files at this position in the generated menu.
		my @path = map { $_->{'title'} } @submenus;
		push(@entries, &grub2_bls_entries(scalar(@entries),
						   undef, \@path));
		}
	elsif ($line =~ /^\s*submenu\s+/) {
		my ($title, $id) = &parse_grub_statement($line, 'submenu');
		my ($opens, $closes) = &count_grub_braces($line);
		# Track submenu stack depth so child entries get a stable path.
		push(@submenus, {
			'title' => $title,
			'id' => $id,
			'depth' => $depth + $opens - $closes,
		}) if (defined($title) && $opens > $closes);
		}
	elsif ($line =~ /^\s*menuentry\s+/) {
		my ($title, $id) = &parse_grub_statement($line, 'menuentry');
		if (defined($title)) {
			# Details are read from the menuentry body, not just the title line.
			my @path = map { $_->{'title'} } @submenus;
			my $end = &grub2_statement_block_end(\@lines, $i);
			my %details = &grub2_menuentry_details(\@lines, $i,
							       $end);
			push(@entries, {
				'index' => scalar(@entries),
				'title' => $title,
				'id' => $id,
				'line' => $i + 1,
				'path' => \@path,
				'source_file' => $section_file,
				%details,
			});
			}
		}
	my ($opens, $closes) = &count_grub_braces($line);
	$depth += $opens - $closes;
	while (@submenus && $depth < $submenus[-1]->{'depth'}) {
		# Drop submenu context once its closing brace has been passed.
		pop(@submenus);
		}
	$depth = 0 if ($depth < 0);
	}
return @entries;
}

# grub2_menuentry_details(&lines, start-index, end-index)
# Extracts kernel and initrd details from one generated menuentry block.
sub grub2_menuentry_details
{
my ($lines, $start, $end) = @_;
my %details;
for (my $i = $start + 1; $i < $end; $i++) {
	my $line = $lines->[$i];
	if ($line =~ /^\s*linux(?:efi|16)?\s+(.+?)\s*\z/) {
		# The first linux line gives the kernel path and remaining arguments.
		my ($kernel, $opts) = &parse_grub_word($1);
		$details{'linux'} = $kernel
			if (defined($kernel) && $kernel ne '' &&
			    !defined($details{'linux'}));
		$opts =~ s/^\s+|\s+\z//g if (defined($opts));
		$details{'options'} = $opts
			if (defined($opts) && $opts ne '' &&
			    !defined($details{'options'}));
		}
	elsif ($line =~ /^\s*initrd(?:efi|16)?\s+(.+?)\s*\z/) {
		# Preserve multiple initrd words as a single displayed value.
		my $rest = $1;
		my ($initrd, $extra) = &parse_grub_word($rest);
		$extra =~ s/^\s+|\s+\z//g if (defined($extra));
		$details{'initrd'} = defined($extra) && $extra ne '' ?
			$rest : $initrd
			if (defined($initrd) && $initrd ne '' &&
			    !defined($details{'initrd'}));
		}
	}
if (!defined($details{'version'}) && defined($details{'linux'})) {
	my $version = &grub2_kernel_version_from_path($details{'linux'});
	$details{'version'} = $version if ($version);
	}
return %details;
}

# grub2_kernel_version_from_path(path)
# Returns the kernel version embedded in common Linux image filenames.
sub grub2_kernel_version_from_path
{
my ($kernel) = @_;
return if (!defined($kernel) || $kernel eq '');
return $1 if ($kernel =~ m{(?:\A|/)(?:vmlinuz|vmlinux|kernel|bzImage)-(.+)\z});
return;
}

# grub2_bls_entries([start-index], [dir], [&submenu-path])
# Parses Boot Loader Specification entries used by RHEL-style GRUB configs.
sub grub2_bls_entries
{
my ($start_index, $dir, $path) = @_;
$start_index ||= 0;
$dir ||= &grub2_config_value('bls_dir');
return () if (!$dir || !-d $dir);
opendir(my $dh, $dir) || return ();
my @files = sort grep { /\.conf\z/ && -r "$dir/$_" } readdir($dh);
closedir($dh);
my @entries;
foreach my $file (@files) {
	my $entry = &parse_bls_entry("$dir/$file", $file, $path);
	next if (!$entry);
	push(@entries, $entry);
	}
# GRUB shows BLS kernels newest-first, unlike lexical filename order.
@entries = &grub2_sort_bls_entries(@entries);
for (my $i = 0; $i < @entries; $i++) {
	$entries[$i]->{'index'} = $start_index + $i;
	}
return @entries;
}

# grub2_has_bls_rescue_entries([&entries])
# Returns true if the generated menu contains BLS rescue entries.
sub grub2_has_bls_rescue_entries
{
my ($entries) = @_;
$entries ||= [ &grub2_boot_entries() ];
foreach my $entry (@$entries) {
	return 1 if (&grub2_entry_is_bls_rescue($entry));
	}
return 0;
}

# grub2_entry_is_bls_rescue(&entry)
# Returns true if a parsed BLS entry is a rescue entry.
sub grub2_entry_is_bls_rescue
{
my ($entry) = @_;
return 0 if (($entry->{'source'} || '') ne 'bls');
return 1 if (($entry->{'version'} || '') =~ /^0-rescue(?:-|\z)/);
return 1 if (($entry->{'filename'} || '') =~ /(?:^|-)0-rescue(?:-|\.conf\z)/);
return 1 if (($entry->{'title'} || '') =~ /\b0-rescue-/);
return 0;
}

# grub2_has_non_bls_recovery_entries([&entries])
# Returns true if generated/custom entries look like recovery or rescue entries.
sub grub2_has_non_bls_recovery_entries
{
my ($entries) = @_;
$entries ||= [ &grub2_boot_entries() ];
foreach my $entry (@$entries) {
	next if (($entry->{'source'} || '') eq 'bls');
	my $title = $entry->{'title'} || '';
	my $path = join(' ', @{$entry->{'path'} || []});
	return 1 if ($title =~ /\b(?:recovery|rescue)\b/i ||
		     $path =~ /\b(?:recovery|rescue)\b/i);
	}
return 0;
}

# grub2_disabled_bls_rescue_files([dir])
# Returns BLS rescue entries hidden by Webmin.
sub grub2_disabled_bls_rescue_files
{
my ($dir) = @_;
$dir ||= &grub2_config_value('bls_dir');
return () if (!$dir || !-d $dir);
opendir(my $dh, $dir) || return ();
my $suffix = &grub2_disabled_bls_rescue_suffix();
my @bases = sort grep { /\Q$suffix\E\z/ && -r "$dir/$_" } readdir($dh);
closedir($dh);
my @files;
foreach my $base (@bases) {
	my $file = "$dir/$base";
	my $entry = &parse_bls_entry($file, $base, []);
	push(@files, $file)
		if ($entry && &grub2_entry_is_bls_rescue($entry));
	}
return @files;
}

# grub2_set_bls_rescue_disabled(disabled?, [&entries])
# Hides or restores BLS rescue entries without deleting their files.
sub grub2_set_bls_rescue_disabled
{
my ($disabled, $entries) = @_;
my $suffix = &grub2_disabled_bls_rescue_suffix();
my @moves;
if ($disabled) {
	# Hiding renames BLS rescue files so GRUB's blscfg no longer sees them.
	$entries ||= [ &grub2_boot_entries() ];
	my %seen;
	foreach my $entry (@$entries) {
		next if (!&grub2_entry_is_bls_rescue($entry));
		my $from = $entry->{'file'} || '';
		next if ($from eq '' || !-e $from || $seen{$from}++);
		my $to = $from.$suffix;
		return &text('defaults_ebls_rescue_exists', $from, $to)
			if (-e $to);
		push(@moves, [ $from, $to ]);
		}
	}
else {
	# Restoring reverses our suffix only when the original target is free.
	foreach my $from (&grub2_disabled_bls_rescue_files()) {
		my $to = $from;
		$to =~ s/\Q$suffix\E\z//;
		next if ($to eq $from || -e $to);
		push(@moves, [ $from, $to ]);
		}
	}
foreach my $move (@moves) {
	my ($from, $to) = @$move;
	# Lock both names so Webmin logging can capture the rename safely.
	&lock_file($from);
	&lock_file($to);
	my $ok = &rename_file($from, $to);
	my $err = "$!";
	&unlock_file($to);
	&unlock_file($from);
	return &text('defaults_ebls_rescue_move', $from, $to, $err)
		if (!$ok);
	}
return;
}

# grub2_disabled_bls_rescue_suffix()
# Returns suffix used for BLS rescue entries hidden by Webmin.
sub grub2_disabled_bls_rescue_suffix
{
return ".disabled";
}

# grub2_kernel_options_source_keys([&entries])
# Returns detected sources for Linux kernel command line options.
sub grub2_kernel_options_source_keys
{
my ($entries) = @_;
$entries ||= [ &grub2_boot_entries() ];
my %sources;
foreach my $entry (@$entries) {
	my $opts = $entry->{'options'} || '';
	if (($entry->{'source'} || '') eq 'bls') {
		# BLS entries can contain direct options or defer to grubenv kernelopts.
		if (&grub2_entry_uses_kernelopts($entry)) {
			$sources{'kernelopts'} = 1;
			}
		else {
			$sources{'bls'} = 1;
			}
		}
	elsif (($entry->{'linux'} || '') ne '' || $opts ne '') {
		$sources{'defaults'} = 1;
		}
	}
return grep { $sources{$_} } qw(kernelopts bls defaults);
}

# grub2_entry_uses_kernelopts(&entry)
# Returns true when a BLS entry defers kernel options to grubenv.
sub grub2_entry_uses_kernelopts
{
my ($entry) = @_;
my $opts = $entry->{'options'} || '';
return $opts =~ /(?:^|\s)(?:\$kernelopts|\$\{kernelopts\})(?:\s|\z)/ ?
	1 : 0;
}

# grub2_kernel_options_source_text([&entries])
# Returns localized text for detected Linux kernel option sources.
sub grub2_kernel_options_source_text
{
my ($entries) = @_;
my @keys = &grub2_kernel_options_source_keys($entries);
return $text{'index_not_set'} if (!@keys);
return join(', ',
	    map { $text{'index_kernel_options_source_'.$_} || $_ } @keys);
}

# grub2_bls_kernel_option_warnings([&entries], [&env])
# Returns warnings for BLS entries whose kernel options live outside defaults.
sub grub2_bls_kernel_option_warnings
{
my ($entries, $env) = @_;
$entries ||= [ &grub2_boot_entries() ];
if (!$env) {
	my %read_env = &grub2_read_env();
	$env = \%read_env;
	}
my @sources = &grub2_kernel_options_source_keys($entries);
return () if (!grep { $_ eq 'kernelopts' || $_ eq 'bls' } @sources);
my @warnings;
# Direct BLS options need grubby to keep existing entries in sync.
push(@warnings, $text{'index_warn_bls_options'})
	if ((grep { $_ eq 'bls' } @sources) &&
	    !&grub2_bls_update_available($entries));
if (grep { $_ eq 'kernelopts' } @sources) {
	# kernelopts is stored in grubenv, so report when it is missing or unmanaged.
	push(@warnings, $text{'index_warn_kernelopts_source'})
		if (!&grub2_bls_update_available($entries));
	push(@warnings, $text{'index_warn_kernelopts_missing'})
		if (!defined($env->{'kernelopts'}) ||
		    $env->{'kernelopts'} eq '');
	}
return @warnings;
}

# grub2_update_bls_kernel_args(old-args, new-args, [&kernel-targets])
# Applies changed kernel options to existing BLS entries with grubby.
sub grub2_update_bls_kernel_args
{
my ($old_args, $new_args, $targets) = @_;
my $cmd = &grub2_command('grubby_cmd');
return $text{'defaults_egrubby'} if (!$cmd);
my ($remove, $add) = &grub2_kernel_args_delta($old_args, $new_args);
return if (!@$remove && !@$add);
my @targets = $targets && @$targets ? @$targets : ('ALL');
foreach my $target (@targets) {
	# Pass only the delta so grubby preserves unrelated boot-critical args.
	my @run = (quotemeta($cmd), quotemeta('--update-kernel='.$target));
	push(@run, quotemeta('--remove-args='.join(' ', @$remove))) if (@$remove);
	push(@run, quotemeta('--args='.join(' ', @$add))) if (@$add);
	my $out = &backquote_logged(join(' ', @run).' 2>&1 </dev/null');
	if ($?) {
		$out =~ s/^\s+|\s+\z//g if (defined($out));
		return $out || $text{'defaults_egrubby_failed'};
		}
	}
return;
}

# grub2_bls_kernel_arg_targets([&entries], [include-rescue?])
# Returns grubby kernel targets for BLS entries.
sub grub2_bls_kernel_arg_targets
{
my ($entries, $include_rescue) = @_;
$entries ||= [ &grub2_boot_entries() ];
my (@targets, %seen);
foreach my $entry (@$entries) {
	next if (($entry->{'source'} || '') ne 'bls');
	# Default-only args should not be applied to rescue entries.
	next if (!$include_rescue && &grub2_entry_is_bls_rescue($entry));
	my $target = &grub2_bls_kernel_target($entry->{'linux'});
	next if ($target eq '' || $seen{$target}++);
	push(@targets, $target);
	}
return @targets;
}

# grub2_bls_kernel_target(linux-path)
# Converts a BLS linux path to the kernel path expected by grubby.
sub grub2_bls_kernel_target
{
my ($linux) = @_;
return '' if (!defined($linux) || $linux eq '');
return $linux if ($linux =~ m{^/boot/});
my $boot = &grub2_bls_boot_dir();
return $boot.$linux if ($linux =~ m{^/});
return $boot.'/'.$linux;
}

# grub2_bls_boot_dir()
# Returns the boot directory that contains configured BLS entries.
sub grub2_bls_boot_dir
{
my $bls_dir = &grub2_config_value('bls_dir') || '';
return $1 if ($bls_dir =~ m{\A(.+)/loader/entries/?\z});
my $parent = &grub2_dirname($bls_dir);
return $parent if ($parent ne '');
return '/boot';
}

# grub2_kernel_args_delta(old-args, new-args)
# Returns argument tokens to remove and add while preserving unrelated tokens.
sub grub2_kernel_args_delta
{
my ($old_args, $new_args) = @_;
my @old = &grub2_split_kernel_args($old_args);
my @new = &grub2_split_kernel_args($new_args);
my (%old, %new);
# Track full tokens so replacing foo=old with foo=new removes and adds cleanly.
$old{$_}++ foreach (@old);
$new{$_}++ foreach (@new);
my (@remove, @add);
foreach my $arg (@old) {
	next if ($new{$arg});
	push(@remove, $arg);
	}
foreach my $arg (@new) {
	next if ($old{$arg});
	push(@add, $arg);
	}
return (\@remove, \@add);
}

# grub2_split_kernel_args(args)
# Splits a Linux kernel command line using GRUB/shell-style words.
sub grub2_split_kernel_args
{
my ($args) = @_;
$args = '' if (!defined($args));
my @rv;
while (defined($args) && $args =~ /\S/) {
	my ($word, $rest) = &parse_grub_word($args);
	last if (!defined($word));
	# Empty quoted strings are ignored because kernel args are token-based.
	push(@rv, $word) if ($word ne '');
	$args = $rest;
	}
return @rv;
}

# grub2_sort_bls_entries(@entries)
# Returns BLS entries in the same newest-first order that GRUB displays.
sub grub2_sort_bls_entries
{
my @entries = @_;
my $use_version = @entries &&
	!grep { !defined($_->{'version'}) || $_->{'version'} eq '' } @entries;
my @sorted = sort {
	my $akey = $use_version ? $a->{'version'} : $a->{'filename'};
	my $bkey = $use_version ? $b->{'version'} : $b->{'filename'};
	# rpmvercmp handles kernel release components better than string compare.
	my $cmp = &grub2_rpmvercmp($akey, $bkey);
	$cmp ||= &grub2_rpmvercmp($a->{'filename'}, $b->{'filename'});
	$cmp ||= ($a->{'filename'} || '') cmp ($b->{'filename'} || '');
	$cmp;
	} @entries;
return reverse(@sorted);
}

# parse_bls_entry(file, basename, [&submenu-path])
# Parses one Boot Loader Specification entry file.
sub parse_bls_entry
{
my ($file, $base, $path) = @_;
my $data = &read_file_contents($file);
my %entry = (
	'line' => 1,
	'path' => [ @{$path || []} ],
	'source' => 'bls',
	'file' => $file,
	'filename' => $base,
	'source_file' => $file,
);
foreach my $line (split(/\r?\n/, $data || '')) {
	next if ($line =~ /^\s*(?:#|\z)/);
	if ($line =~ /^\s*([A-Za-z0-9_.-]+)\s+(.+?)\s*\z/) {
		# BLS permits repeated keys; the last one wins like most parsers.
		my ($key, $value) = ($1, $2);
		$entry{$key} = $value;
		}
	}
return if (!$entry{'title'});
$base =~ s/\.conf\z//;
$entry{'id'} ||= $base;
$entry{'title'} ||= $entry{'version'} || $entry{'id'};
return \%entry;
}

# grub2_rpmvercmp(left, right)
# Compares version-like strings with the rpmvercmp rules used by GRUB BLS.
sub grub2_rpmvercmp
{
my ($left, $right) = @_;
$left = '' if (!defined($left));
$right = '' if (!defined($right));
return 0 if ($left eq $right);
my ($la, $ra) = ($left, $right);
while ($la ne '' || $ra ne '') {
	# Skip separators; rpmvercmp compares only alphanumeric and tilde runs.
	$la =~ s/\A[^A-Za-z0-9~]+//;
	$ra =~ s/\A[^A-Za-z0-9~]+//;
	if ($la =~ /\A~/ || $ra =~ /\A~/) {
		# Tilde sorts before the empty string and before regular segments.
		return -1 if ($la =~ /\A~/ && $ra !~ /\A~/);
		return 1 if ($la !~ /\A~/ && $ra =~ /\A~/);
		$la =~ s/\A~//;
		$ra =~ s/\A~//;
		next;
		}
	last if ($la eq '' || $ra eq '');
	my $left_num = $la =~ /\A[0-9]/;
	my ($ls, $rs);
	if ($left_num) {
		# Numeric segments compare by length after trimming leading zeros.
		($ls) = $la =~ /\A([0-9]+)/;
		($rs) = $ra =~ /\A([0-9]+)/;
		return 1 if (!defined($rs));
		$la = substr($la, length($ls));
		$ra = substr($ra, length($rs));
		$ls =~ s/\A0+//;
		$rs =~ s/\A0+//;
		$ls = '0' if ($ls eq '');
		$rs = '0' if ($rs eq '');
		return length($ls) <=> length($rs)
			if (length($ls) != length($rs));
		my $cmp = $ls cmp $rs;
		return $cmp if ($cmp);
		}
	else {
		# Alphabetic segments compare lexically and sort below numeric runs.
		($ls) = $la =~ /\A([A-Za-z]+)/;
		($rs) = $ra =~ /\A([A-Za-z]+)/;
		return -1 if (!defined($rs));
		$la = substr($la, length($ls));
		$ra = substr($ra, length($rs));
		my $cmp = $ls cmp $rs;
		return $cmp if ($cmp);
		}
	}
return 0 if ($la eq '' && $ra eq '');
return $la eq '' ? -1 : 1;
}

# grub2_custom_entries([file])
# Parses editable custom GRUB menu entries with source line ranges.
sub grub2_custom_entries
{
my ($file) = @_;
$file ||= &grub2_config_value('custom_file');
return () if (!$file || !-r $file);
my $data = &read_file_contents($file);
$data =~ s/\r\n/\n/g;
$data =~ s/\r/\n/g;
my @lines = split(/\n/, $data);
return &grub2_custom_entries_from_lines(\@lines, $file);
}

# grub2_custom_entries_from_lines(&lines, file)
# Parses editable custom GRUB entries from already-read file lines.
sub grub2_custom_entries_from_lines
{
my ($lines, $file) = @_;
my (@entries, @submenus);
my $depth = 0;
for (my $i = 0; $i < @$lines; $i++) {
	my $line = $lines->[$i];
	if ($line =~ /^\s*submenu\s+/) {
		# Custom entries may be nested; keep a submenu path like grub.cfg.
		my ($title, $id) = &parse_grub_statement($line, 'submenu');
		my ($opens, $closes) = &count_grub_braces($line);
		push(@submenus, {
			'title' => $title,
			'id' => $id,
			'depth' => $depth + $opens - $closes,
		}) if (defined($title) && $opens > $closes);
		}
	elsif ($line =~ /^\s*menuentry\s+/) {
		my ($title, $id) = &parse_grub_statement($line, 'menuentry');
		if (defined($title)) {
			# Store source ranges so edits can replace exact blocks.
			my @path = map { $_->{'title'} } @submenus;
			push(@entries, {
				'custom_index' => scalar(@entries),
				'title' => $title,
				'id' => $id,
				'path' => \@path,
				'source_file' => $file,
				'start' => $i,
				'end' => &grub2_statement_block_end($lines, $i),
			});
			}
		}
	my ($opens, $closes) = &count_grub_braces($line);
	$depth += $opens - $closes;
	while (@submenus && $depth < $submenus[-1]->{'depth'}) {
		# Closing braces pop submenu context before subsequent entries.
		pop(@submenus);
		}
	$depth = 0 if ($depth < 0);
	}
return @entries;
}

# grub2_custom_entry_by_index(index)
# Returns one custom entry descriptor by non-negative custom index.
sub grub2_custom_entry_by_index
{
my ($index) = @_;
return if (!defined($index) || $index !~ /^\d+\z/);
my @entries = &grub2_custom_entries();
return if ($index >= @entries);
return $entries[$index];
}

# grub2_custom_entry_body(&entry, [file])
# Returns the editable body inside a custom menuentry block.
sub grub2_custom_entry_body
{
my ($entry, $file) = @_;
return '' if (!$entry);
$file ||= $entry->{'source_file'} || &grub2_config_value('custom_file');
return '' if (!$file || !-r $file);
my $data = &read_file_contents($file);
$data =~ s/\r\n/\n/g;
$data =~ s/\r/\n/g;
my @lines = split(/\n/, $data);
return '' if ($entry->{'end'} <= $entry->{'start'} + 1);
my @body = @lines[$entry->{'start'} + 1 .. $entry->{'end'} - 1];
@body = &grub2_unindent_custom_body(\@body);
return join("\n", @body).(@body ? "\n" : "");
}

# grub2_unindent_custom_body(&lines)
# Removes the common storage indentation from a custom entry body.
sub grub2_unindent_custom_body
{
my ($lines) = @_;
my $prefix;
foreach my $line (@$lines) {
	next if ($line !~ /\S/);
	my ($indent) = $line =~ /^([ \t]*)/;
	if (!defined($prefix)) {
		# First nonblank line sets the candidate common indentation.
		$prefix = $indent;
		}
	else {
		# Trim the prefix until every nonblank line shares it.
		while ($prefix ne '' && index($indent, $prefix) != 0) {
			chop($prefix);
			}
		}
	last if (defined($prefix) && $prefix eq '');
	}
return @$lines if (!defined($prefix) || $prefix eq '');
my @out = @$lines;
foreach my $line (@out) {
	$line =~ s/^\Q$prefix\E//;
	}
return @out;
}

# grub2_save_custom_entry(index|undef, title, id, body)
# Adds or replaces a custom GRUB menuentry in the configured custom file.
sub grub2_save_custom_entry
{
my ($index, $title, $id, $body) = @_;
my $file = &grub2_config_value('custom_file') || '';
return $text{'custom_efile'} if ($file eq '');
return &text('defaults_econfigpath', $file) if ($file !~ m{^/});
my $dir = &grub2_dirname($file);
return &text('defaults_edir', $dir) if ($dir eq '' || !-d $dir);
my $err = &grub2_validate_custom_entry($title, $id, $body);
return $err if ($err);
my $entry_text = &grub2_format_custom_entry($title, $id, $body);
my @entry_lines = split(/\n/, $entry_text);
return &grub2_with_file_lock($file, sub {
	my @lines = &grub2_custom_file_lines($file);
	if (defined($index) && $index ne '') {
		# Replacement uses the latest parsed ranges under the file lock.
		my @entries = &grub2_custom_entries_from_lines(\@lines, $file);
		my $entry = $index =~ /^\d+\z/ ? $entries[$index] : undef;
		return $text{'custom_eentry'} if (!$entry);
		splice(@lines, $entry->{'start'},
		       $entry->{'end'} - $entry->{'start'} + 1, @entry_lines);
		}
	else {
		# New entries are appended after a blank separator when needed.
		push(@lines, '') if (@lines && $lines[-1] ne '');
		push(@lines, @entry_lines);
		}
	my $data = join("\n", @lines)."\n";
	&grub2_write_custom_file($file, $data);
	return;
	});
}

# grub2_delete_custom_entry_indexes(index, ...)
# Deletes entries by custom-file index.
sub grub2_delete_custom_entry_indexes
{
my (@indexes) = @_;
return $text{'delete_enone'} if (!@indexes);
my $file = &grub2_config_value('custom_file') || '';
return $text{'delete_ecustom'} if ($file eq '' || !-r $file);
return &grub2_with_file_lock($file, sub {
	my @lines = &grub2_custom_file_lines($file);
	my @entries = &grub2_custom_entries_from_lines(\@lines, $file);
	my %seen;
	my @ranges;
	foreach my $index (@indexes) {
		# Validate all selected indexes before deleting any ranges.
		return $text{'custom_eentry'}
			if (!defined($index) || $index !~ /^\d+\z/ ||
			    !$entries[$index]);
		next if ($seen{$index}++);
		push(@ranges,
		     [ $entries[$index]->{'start'}, $entries[$index]->{'end'} ]);
		}
	return &grub2_delete_custom_ranges($file, \@ranges, \@lines);
	});
}

# grub2_move_custom_entry(index, direction)
# Moves one custom entry up or down within the custom file.
sub grub2_move_custom_entry
{
my ($index, $direction) = @_;
return $text{'custom_eentry'} if (!defined($index) || $index !~ /^\d+\z/);
return $text{'custom_emove'} if ($direction !~ /^(up|down)\z/);
my $file = &grub2_config_value('custom_file') || '';
return $text{'delete_ecustom'} if ($file eq '' || !-r $file);
return &grub2_with_file_lock($file, sub {
	my @lines = &grub2_custom_file_lines($file);
	my @entries = &grub2_custom_entries_from_lines(\@lines, $file);
	return $text{'custom_eentry'} if (!$entries[$index]);
	return $text{'custom_emove'} if ($direction eq 'up' && $index == 0);
	return $text{'custom_emove'} if ($direction eq 'down' && $index == $#entries);
	my $entry = $entries[$index];
	my $other = $direction eq 'up' ? $entries[$index - 1] :
		    $entries[$index + 1];
	# Moving across submenu paths would alter the meaning of the custom file.
	return $text{'custom_emove'} if (!&grub2_paths_equal($entry, $other));
	my @block = @lines[$entry->{'start'} .. $entry->{'end'}];
	my $len = scalar(@block);
	splice(@lines, $entry->{'start'}, $len);
	my $insert = $direction eq 'up' ? $other->{'start'} :
		     $other->{'end'} - $len + 1;
	splice(@lines, $insert, 0, @block);
	my $data = join("\n", @lines)."\n";
	&grub2_write_custom_file($file, $data);
	return;
	});
}

# grub2_validate_custom_entry(title, id, body)
# Validates one custom entry before writing it to the custom file.
sub grub2_validate_custom_entry
{
my ($title, $id, $body) = @_;
$title = '' if (!defined($title));
$id = '' if (!defined($id));
$body = '' if (!defined($body));
return $text{'custom_etitle'} if ($title eq '' || $title =~ /[\r\n\0]/);
return $text{'custom_eid'} if ($id =~ /[\r\n\0]/ ||
			       ($id ne '' && $id !~ /^[A-Za-z0-9_.:+=,\@-]+\z/));
return $text{'custom_eid'} if ($id =~ /^-/);
return $text{'custom_ebody'} if ($body =~ /\0/);
# Validate the full wrapped menuentry, not just the user-entered body.
return &grub2_validate_grub_script_text(
	&grub2_format_custom_entry($title, $id, $body));
}

# grub2_validate_grub_script_text(text, [context-file])
# Validates GRUB script with grub-script-check when available, or braces.
sub grub2_validate_grub_script_text
{
my ($data, $context_file) = @_;
my $cmd = &grub2_command('script_check_cmd');
if ($cmd) {
	# Prefer GRUB's own parser when it is installed.
	my $file = $context_file || &grub2_config_value('custom_file') || '';
	return &text('defaults_econfigpath', $file) if ($file !~ m{^/});
	my $dir = &grub2_dirname($file);
	return &text('defaults_edir', $dir) if ($dir eq '' || !-d $dir);
	my ($temp, $terr) = &grub2_make_temp_file($dir, 'script', $data);
	return $terr if ($terr);
	my ($out, $failed);
	my $die;
	eval {
		$out = &backquote_command(
			quotemeta($cmd).' '.quotemeta($temp).
			' 2>&1 </dev/null');
		$failed = $?;
		1;
		} || do { $die = $@ || $!; };
	&grub2_unlink_temp($temp);
	return $die if ($die);
	if ($failed) {
		$out =~ s/^\s+|\s+\z//g if (defined($out));
		return $out || $text{'custom_evalidate'};
		}
	return;
	}
my $depth = 0;
foreach my $line (split(/\n/, $data)) {
	# Fallback validation catches unbalanced braces on minimal systems.
	my ($opens, $closes) = &count_grub_braces($line);
	$depth += $opens - $closes;
	return $text{'custom_ebraces'} if ($depth < 0);
	}
return if ($depth == 0);
return $text{'custom_ebraces'};
}

# grub2_custom_script_text(text)
# Returns the GRUB script portion of a 40_custom-style file.
sub grub2_custom_script_text
{
my ($data) = @_;
$data = '' if (!defined($data));
$data =~ s/\r\n/\n/g;
$data =~ s/\r/\n/g;
my @lines = split(/\n/, $data, -1);
if (@lines >= 2 && $lines[0] =~ /^#!/ &&
    $lines[1] =~ /^\s*exec\s+tail\s+-n\s+\+3\b/) {
	# Standard 40_custom has a shell wrapper that GRUB never sees.
	splice(@lines, 0, 2);
	}
return join("\n", @lines);
}

# grub2_format_custom_entry(title, id, body)
# Returns normalized GRUB script for one custom menuentry.
sub grub2_format_custom_entry
{
my ($title, $id, $body) = @_;
$body = '' if (!defined($body));
$body =~ s/\r\n/\n/g;
$body =~ s/\r/\n/g;
my @body = split(/\n/, $body);
@body = &grub2_unindent_custom_body(\@body);
@body = ('true') if (!grep { /\S/ } @body);
my $line = 'menuentry '.&grub2_quote_word($title);
$line .= ' --id '.&grub2_quote_word($id) if (defined($id) && $id ne '');
$line .= ' {';
# Store custom bodies with one tab so future edits can unindent cleanly.
my @indented = map { "\t".$_ } @body;
return join("\n", $line, @indented, '}')."\n";
}

# grub2_quote_word(text)
# Quotes one GRUB command word using double-quote shell syntax.
sub grub2_quote_word
{
my ($text) = @_;
$text = '' if (!defined($text));
$text =~ s/(["\\\$`])/\\$1/g;
return '"'.$text.'"';
}

# grub2_paths_equal(&entry-a, &entry-b)
# Returns true when two entries belong to the same submenu path.
sub grub2_paths_equal
{
my ($a, $b) = @_;
return join("\n", @{$a->{'path'} || []}) eq
       join("\n", @{$b->{'path'} || []});
}

# grub2_with_file_lock(file, &code)
# Runs a code reference while holding a Webmin lock on a file.
sub grub2_with_file_lock
{
my ($file, $code) = @_;
my ($ret, $die);
&lock_file($file);
eval {
	# The callback performs any validation that must happen under the lock.
	$ret = $code->();
	1;
	} || do { $die = $@ || $!; };
&unlock_file($file);
return $die if ($die);
return $ret;
}

# grub2_write_custom_file(file, data)
# Writes the custom file and ensures it remains executable.
sub grub2_write_custom_file
{
my ($file, $data) = @_;
open_tempfile(my $fh, ">$file");
print_tempfile($fh, $data);
close_tempfile($fh);
chmod(0755, $file);
return;
}

# grub2_make_temp_file(dir, prefix, [data])
# Creates a private temporary file in a live config directory.
sub grub2_make_temp_file
{
my ($dir, $prefix, $data) = @_;
return ('', &text('defaults_edir', $dir)) if ($dir eq '' || !-d $dir);
&seed_random();
my $last_err;
for (my $i = 0; $i < 20; $i++) {
	my $temp = "$dir/.webmin-grub2-$prefix-$$-".
		   int(rand(1000000000))."-$i";
	my $fh;
	# O_EXCL avoids racing another Webmin process in the same directory.
	if (!sysopen($fh, $temp, O_WRONLY|O_CREAT|O_EXCL, 0600)) {
		$last_err = $!;
		next if ($! == EEXIST);
		next;
		}
	binmode($fh);
	if (defined($data) && !(print $fh $data)) {
		my $err = $!;
		close($fh);
		unlink($temp);
		return ('', $err);
		}
	if (!close($fh)) {
		my $err = $!;
		unlink($temp);
		return ('', $err);
		}
	push(@main::temporary_files, $temp);
	return ($temp);
	}
return ('', "Failed to create temporary file in $dir : $last_err");
}

# grub2_unlink_temp(file)
# Removes a temporary file and unregisters it from Webmin cleanup.
sub grub2_unlink_temp
{
my ($temp) = @_;
return if (!defined($temp) || $temp eq '');
unlink($temp);
@main::temporary_files = grep { $_ ne $temp } @main::temporary_files;
}

# grub2_custom_file_lines(file)
# Returns current or new custom file contents as editable lines.
sub grub2_custom_file_lines
{
my ($file) = @_;
my $data;
if ($file && -r $file) {
	# Existing custom files are preserved, including their shell wrapper.
	$data = &read_file_contents($file);
	}
else {
	# New custom files use the conventional 40_custom wrapper.
	$data = "#!/bin/sh\nexec tail -n +3 \$0\n";
	}
$data =~ s/\r\n/\n/g;
$data =~ s/\r/\n/g;
my @lines = split(/\n/, $data, -1);
pop(@lines) if (@lines && $lines[-1] eq '');
return @lines;
}

# parse_grub_statement(line, keyword)
# Returns the title and ID from a menuentry or submenu line.
sub parse_grub_statement
{
my ($line, $keyword) = @_;
$line =~ s/^\s*\Q$keyword\E\s+//;
my ($title, $rest) = &parse_grub_word($line);
my $id;
# Accept both explicit --id and distro scripts using $menuentry_id_option.
if (defined($rest) &&
    $rest =~ /(?:--id|\$menuentry_id_option)\s+((?:"(?:\\.|[^"])*")|(?:'[^']*')|\S+)/) {
	($id) = &parse_grub_word($1);
	}
return ($title, $id);
}

# parse_grub_word(text)
# Parses one GRUB shell-style word.
sub parse_grub_word
{
my ($text) = @_;
return if (!defined($text));
$text =~ s/^\s+//;
return if ($text eq '');
my $quote = substr($text, 0, 1);
if ($quote eq "'" || $quote eq '"') {
	# Parse one quoted word and return the unparsed remainder to the caller.
	my $out = '';
	my $escape = 0;
	for (my $i = 1; $i < length($text); $i++) {
		my $ch = substr($text, $i, 1);
		if ($escape) {
			$out .= $ch;
			$escape = 0;
			next;
			}
		if ($quote eq '"' && $ch eq '\\') {
			$escape = 1;
			next;
			}
		if ($ch eq $quote) {
			return ($out, substr($text, $i + 1));
			}
		$out .= $ch;
		}
	return ($out, '');
	}
if ($text =~ /^(\S+)(.*)\z/s) {
	# Unquoted words end at the next whitespace.
	return ($1, $2);
	}
return;
}

# count_grub_braces(line)
# Counts unquoted braces on a GRUB config line.
sub count_grub_braces
{
my ($line) = @_;
my ($opens, $closes) = (0, 0);
my $quote = '';
my $escape = 0;
for (my $i = 0; $i < length($line); $i++) {
	my $ch = substr($line, $i, 1);
	if ($escape) {
		# Escaped characters inside double quotes are not syntax braces.
		$escape = 0;
		next;
		}
	if ($quote eq '"') {
		if ($ch eq '\\') {
			$escape = 1;
			}
		elsif ($ch eq '"') {
			$quote = '';
			}
		next;
		}
	if ($quote eq "'") {
		$quote = '' if ($ch eq "'");
		next;
		}
	if ($ch eq '"' || $ch eq "'") {
		$quote = $ch;
		next;
		}
	# Comments terminate syntax scanning for this line.
	last if ($ch eq '#');
	$opens++ if ($ch eq '{');
	$closes++ if ($ch eq '}');
	}
return ($opens, $closes);
}

# grub2_statement_block_end(&lines, start-index)
# Returns the final line index for a GRUB statement block.
sub grub2_statement_block_end
{
my ($lines, $start) = @_;
my $depth = 0;
my $seen_open = 0;
for (my $i = $start; $i < @$lines; $i++) {
	my ($opens, $closes) = &count_grub_braces($lines->[$i]);
	$seen_open ||= $opens;
	$depth += $opens - $closes;
	# A block ends on the first line that balances the opening brace.
	return $i if ($seen_open && $depth <= 0);
	}
return $start;
}

# grub2_entry_selector(&entry)
# Returns the safest selector to pass to grub-set-default or grub-reboot.
sub grub2_entry_selector
{
my ($entry) = @_;
return $entry->{'id'} if ($entry->{'id'});
my @path = (@{$entry->{'path'} || []}, $entry->{'title'});
return if (grep { !defined($_) || />/ } @path);
return join('>', @path);
}

# grub2_entry_by_index(index)
# Returns a parsed boot entry by non-negative index.
sub grub2_entry_by_index
{
my ($index) = @_;
return if (!defined($index) || $index !~ /^\d+\z/);
my @entries = &grub2_boot_entries();
return if ($index >= @entries);
return $entries[$index];
}

# grub2_entry_selection_roles(&entries, [&parsed-defaults], [&env])
# Returns entry indexes mapped to active default and next-boot roles.
sub grub2_entry_selection_roles
{
my ($entries, $parsed, $env) = @_;
$entries ||= [ &grub2_boot_entries() ];
$parsed ||= &read_grub_defaults();
if (!$env) {
	my %read_env = &grub2_read_env();
	$env = \%read_env;
	}
my %roles;
my $default = $parsed->{'values'}->{'GRUB_DEFAULT'};
$default = '0' if (!defined($default) || $default eq '');
if ($default eq 'saved') {
	# saved resolves through grubenv, not directly through grub.cfg.
	&grub2_mark_entry_role(\%roles, $entries, $env->{'saved_entry'}, 'saved');
	}
else {
	&grub2_mark_entry_role(\%roles, $entries, $default, 'default');
	}
&grub2_mark_entry_role(\%roles, $entries, $env->{'next_entry'}, 'next');
return %roles;
}

# grub2_mark_entry_role(&roles, &entries, selector, role)
# Adds one selection role to the entry matched by a GRUB selector.
sub grub2_mark_entry_role
{
my ($roles, $entries, $selector, $role) = @_;
return if (!defined($selector) || $selector eq '');
foreach my $entry (@$entries) {
	if (&grub2_entry_matches_selector($entry, $selector)) {
		push(@{$roles->{$entry->{'index'}}}, $role);
		return;
		}
	}
}

# grub2_entry_matches_selector(&entry, selector)
# Returns true when a selector names an entry by index, ID, title, or path.
sub grub2_entry_matches_selector
{
my ($entry, $selector) = @_;
return 0 if (!defined($entry) || !defined($selector) || $selector eq '');
return 1 if ($selector =~ /^\d+\z/ && $selector == $entry->{'index'});
return 1 if (defined($entry->{'id'}) && $entry->{'id'} eq $selector);
return 1 if (defined($entry->{'title'}) && $entry->{'title'} eq $selector);
my @path = (@{$entry->{'path'} || []}, $entry->{'title'});
return 0 if (grep { !defined($_) || />/ } @path);
return join('>', @path) eq $selector;
}

# grub2_delete_custom_ranges(file, &ranges)
# Removes line ranges from the custom file.
sub grub2_delete_custom_ranges
{
my ($file, $ranges, $lines) = @_;
my @lines = $lines ? @$lines : &grub2_custom_file_lines($file);
foreach my $range (sort { $b->[0] <=> $a->[0] } @$ranges) {
	# Delete from bottom to top so earlier indexes remain valid.
	splice(@lines, $range->[0], $range->[1] - $range->[0] + 1);
	}
my $new_data = join("\n", @lines);
$new_data .= "\n" if (@lines);
&grub2_write_custom_file($file, $new_data);
return;
}

# grub2_run_entry_command(command-key, &entry)
# Runs a GRUB command that takes one menu entry selector.
sub grub2_run_entry_command
{
my ($key, $entry) = @_;
my $cmd = &grub2_command($key);
return $text{'runtime_ecmd'} if (!$cmd);
my $selector = &grub2_entry_selector($entry);
return $text{'runtime_eselector'}
	if (!defined($selector) || $selector eq '' || $selector =~ /^-/);
# Quote the selector because titles and submenu paths may contain spaces.
my $out = &backquote_logged(
	quotemeta($cmd).' '.quotemeta($selector).' 2>&1 </dev/null');
if ($?) {
	$out =~ s/^\s+|\s+\z//g if (defined($out));
	return $out || $text{'runtime_err'};
	}
return;
}

# grub2_read_env()
# Reads key/value state from grubenv using grub-editenv when available.
sub grub2_read_env
{
my %env;
my $file = &grub2_config_value('grubenv_file') || '';
my $cmd = &grub2_command('editenv_cmd');
if ($cmd && $file ne '' && -e $file) {
	# grub-editenv handles the binary environment format when available.
	my $out = &backquote_command(
		quotemeta($cmd).' '.quotemeta($file).' list 2>&1 </dev/null',
		1);
	if (!$?) {
		foreach my $line (split(/\r?\n/, $out || '')) {
			if ($line =~ /^([A-Za-z_][A-Za-z0-9_]*)=(.*)\z/) {
				$env{$1} = $2;
				}
			}
		return %env;
		}
	}
if ($file ne '' && -r $file) {
	# Plain fallback helps in tests and on systems with text grubenv files.
	my $data = &read_file_contents($file);
	foreach my $line (split(/\r?\n/, $data || '')) {
		if ($line =~ /^([A-Za-z_][A-Za-z0-9_]*)=(.*)\z/) {
			$env{$1} = $2;
			}
		}
	}
return %env;
}

# grub2_validate_install_options(&options)
# Returns an error if GRUB installation options are unsafe or incomplete.
sub grub2_validate_install_options
{
my ($opts) = @_;
my $target = $opts->{'target'} || '';
my $efi_dir = $opts->{'efi_dir'} || '';
my $platform = $opts->{'platform'} || '';
my $directory = $opts->{'directory'} || '';
my $boot_directory = $opts->{'boot_directory'} || '';
my $bootloader_id = $opts->{'bootloader_id'} || '';
return $text{'install_etarget'} if ($target eq '' && $efi_dir eq '');
if ($target ne '') {
	# BIOS targets must be existing absolute device paths under /dev.
	return $text{'install_etarget'}
		if ($target =~ /[\r\n\0]/ || $target !~ m{\A/} ||
		    $target !~ m{\A/dev/} ||
		    $target !~ m{\A/[A-Za-z0-9._/+:-]+\z} ||
		    $target =~ m{/(?:\.|\.\.)(?:/|\z)} || $target =~ /^-/);
	return &text('install_etarget_missing', $target) if (!-e $target);
	}
if ($efi_dir ne '') {
	# EFI installs target an existing absolute ESP mount path.
	return $text{'install_eefi'}
		if ($efi_dir =~ /[\r\n\0]/ || $efi_dir !~ m{\A/} ||
		    $efi_dir !~ m{\A/[A-Za-z0-9._/+:-]+\z} ||
		    $efi_dir =~ m{/(?:\.|\.\.)(?:/|\z)});
	return &text('install_eefi_missing', $efi_dir) if (!-d $efi_dir);
	}
if ($platform ne '') {
	# Platform targets are GRUB names such as x86_64-efi or arm64-efi.
	return $text{'install_eplatform'}
		if ($platform =~ /[\r\n\0]/ ||
		    $platform !~ /\A[A-Za-z0-9_-]+\z/ || $platform =~ /^-/);
	}
if ($directory ne '') {
	# Custom module directories must contain modinfo.sh for grub-install.
	return $text{'install_edirectory'}
		if ($directory =~ /[\r\n\0]/ || $directory !~ m{\A/} ||
		    $directory !~ m{\A/[A-Za-z0-9._/+:-]+\z} ||
		    $directory =~ m{/(?:\.|\.\.)(?:/|\z)});
	return &text('install_edirectory_missing', $directory)
		if (!-d $directory);
	return &text('install_edirectory_modinfo', $directory)
		if (!-r "$directory/modinfo.sh");
	}
elsif ($platform ne '' && !&grub2_platform_module_dir($platform)) {
	# Without an explicit directory, require a discoverable platform directory.
	return &text('install_eplatform_modules', $platform,
		     join(', ', &grub2_platform_module_dirs($platform)));
	}
if ($boot_directory ne '') {
	# --boot-directory is optional but still needs the same path hygiene.
	return $text{'install_eboot_directory'}
		if ($boot_directory =~ /[\r\n\0]/ ||
		    $boot_directory !~ m{\A/} ||
		    $boot_directory !~ m{\A/[A-Za-z0-9._/+:-]+\z} ||
		    $boot_directory =~ m{/(?:\.|\.\.)(?:/|\z)});
	return &text('install_eboot_directory_missing', $boot_directory)
		if (!-d $boot_directory);
	}
if ($bootloader_id ne '') {
	# EFI boot loader IDs become paths below EFI/, so keep them simple.
	return $text{'install_ebootloader'}
		if ($bootloader_id =~ /[\r\n\0]/ ||
		    $bootloader_id !~ /\A[A-Za-z0-9_.+-]+\z/ ||
		    $bootloader_id =~ /^-/);
	}
foreach my $key (qw(recheck removable no_nvram force)) {
	return $text{'install_eoption'}
		if (defined($opts->{$key}) && $opts->{$key} !~ /^[01]\z/);
	}
return;
}

# grub2_install_command(&options)
# Returns shell and display forms of the grub-install command.
sub grub2_install_command
{
my ($opts) = @_;
my $cmd = &grub2_command('install_cmd');
return ('', '') if (!$cmd);
my @run = (quotemeta($cmd));
my @display = ($cmd);
foreach my $pair (
	[ 'recheck', '--recheck' ],
	[ 'removable', '--removable' ],
	[ 'no_nvram', '--no-nvram' ],
	[ 'force', '--force' ],
    )
{
	my ($key, $arg) = @$pair;
	if ($opts->{$key}) {
		# Boolean options are emitted before path-like options.
		push(@run, quotemeta($arg));
		push(@display, $arg);
		}
	}
if (($opts->{'efi_dir'} || '') ne '') {
	# EFI installs can omit a BIOS-style block-device target.
	push(@run, quotemeta('--efi-directory='.$opts->{'efi_dir'}));
	push(@display, '--efi-directory='.$opts->{'efi_dir'});
	}
if (($opts->{'platform'} || '') ne '') {
	push(@run, quotemeta('--target='.$opts->{'platform'}));
	push(@display, '--target='.$opts->{'platform'});
	}
if (($opts->{'directory'} || '') ne '') {
	push(@run, quotemeta('--directory='.$opts->{'directory'}));
	push(@display, '--directory='.$opts->{'directory'});
	}
if (($opts->{'boot_directory'} || '') ne '') {
	push(@run, quotemeta('--boot-directory='.$opts->{'boot_directory'}));
	push(@display, '--boot-directory='.$opts->{'boot_directory'});
	}
if (($opts->{'bootloader_id'} || '') ne '') {
	push(@run, quotemeta('--bootloader-id='.$opts->{'bootloader_id'}));
	push(@display, '--bootloader-id='.$opts->{'bootloader_id'});
	}
if (($opts->{'target'} || '') ne '') {
	push(@run, quotemeta($opts->{'target'}));
	push(@display, $opts->{'target'});
	}
return (join(' ', @run).' </dev/null', join(' ', @display));
}

# grub2_install_bootloader(&options, [&callback])
# Runs grub-install with explicit administrator-selected options.
sub grub2_install_bootloader
{
my ($opts, $callback) = @_;
my $cmd = &grub2_command('install_cmd');
return $text{'install_ecmd'} if (!$cmd);
my $err = &grub2_validate_install_options($opts);
return $err if ($err);
my ($run, $display) = &grub2_install_command($opts);
my ($out, $failed);
my $die;
eval {
	&grub2_generate_progress($callback, 'command', $display);
	if ($callback) {
		# Progress mode streams output and records the executed command.
		$out = &grub2_run_command_progress($run, $callback);
		$failed = $?;
		}
	else {
		# Non-progress callers still get logged command execution.
		$out = &backquote_logged($run.' 2>&1');
		$failed = $?;
		}
	&grub2_generate_progress($callback,
		$failed ? 'command_failed' : 'command_done', $display);
	1;
	} || do { $die = $@ || $!; };
return $die if ($die);
if ($failed) {
	$out =~ s/^\s+|\s+\z//g if (defined($out));
	return $out || $text{'install_failed'};
	}
return;
}

# grub2_install_log_target(&options)
# Returns a concise installation target string for logs.
sub grub2_install_log_target
{
my ($opts) = @_;
return $opts->{'target'} if (($opts->{'target'} || '') ne '');
return &text('install_log_efi', $opts->{'efi_dir'})
	if (($opts->{'efi_dir'} || '') ne '');
return '';
}

# grub2_generate_config([&callback])
# Runs grub-mkconfig to a test file, then replaces the live generated menu.
sub grub2_generate_config
{
my ($callback) = @_;
my $cmd = &grub2_command('mkconfig_cmd');
return $text{'generate_missing'} if (!$cmd);
my $target = &grub2_config_value('grub_cfg') || '';
return $text{'index_warn_missing_cfg'} if ($target eq '');
return &text('defaults_econfigpath', $target) if ($target !~ m{^/});
my $dir = &grub2_dirname($target);
return &text('index_missing_detail', $dir) if ($dir eq '' || !-d $dir);
my ($temp, $terr) = &grub2_make_temp_file($dir, 'mkconfig');
return $terr if ($terr);
my ($out, $failed, $data, $validation_err);
my $die;
eval {
	# Always generate to a sibling temp file before touching the live menu.
	my $run = quotemeta($cmd).' -o '.quotemeta($temp).' </dev/null';
	my $display = $cmd.' -o '.$temp;
	&grub2_generate_progress($callback, 'command', $display);
	if ($callback) {
		$out = &grub2_run_command_progress($run, $callback);
		$failed = $?;
		}
	else {
		$out = &backquote_logged($run.' 2>&1');
		$failed = $?;
		}
	if (!$failed) {
		&grub2_generate_progress($callback, 'command_done', $display);
		&grub2_generate_progress($callback, 'check', $temp);
		if (-s $temp) {
			# Non-empty output is the first guard against broken generators.
			$data = &read_file_contents($temp);
			}
		if (defined($data) && $data ne '') {
			# grub-script-check catches syntax errors before replacement.
			$validation_err =
				&grub2_validate_grub_script_text($data, $target);
			}
		if (defined($data) && $data ne '' && !$validation_err) {
			&grub2_generate_progress($callback, 'check_done', $temp);
			}
		else {
			&grub2_generate_progress($callback, 'check_failed', $temp);
			}
		}
	else {
		&grub2_generate_progress($callback, 'command_failed', $display);
		}
	1;
	} || do { $die = $@ || $!; };
if ($die) {
	&grub2_unlink_temp($temp);
	return $die;
	}
if ($failed || !defined($data) || $data eq '' || $validation_err) {
	# Leave the existing grub.cfg untouched on all generation/check failures.
	&grub2_unlink_temp($temp);
	$out =~ s/^\s+|\s+\z//g if (defined($out));
	return &text('generate_evalidate', $validation_err)
		if ($validation_err);
	return $out || ($failed ? $text{'generate_failed'} :
			$text{'generate_empty'});
	}
&grub2_unlink_temp($temp);
&grub2_generate_progress($callback, 'replace', $target);
# Re-open the live target via Webmin's locked tempfile writer for logging.
open_lock_tempfile(my $fh, ">$target");
print_tempfile($fh, $data);
close_tempfile($fh);
&grub2_generate_progress($callback, 'replace_done', $target);
return;
}

# grub2_run_command_progress(command, &callback)
# Runs one command and streams combined stdout/stderr to a callback.
sub grub2_run_command_progress
{
my ($cmd, $callback) = @_;
my $out = '';
&additional_log('exec', undef, $cmd);
local *GRUB2CMD;
my $pid = &open_execute_command(\*GRUB2CMD, $cmd, 2, 0);
if (!$pid) {
	# Match shell-style command failure status for callers checking $?
	$? = 1 << 8;
	return "$cmd : $!";
	}
while (defined(my $line = readline(\*GRUB2CMD))) {
	# Stream line-by-line so progress pages update during long commands.
	$out .= $line;
	&grub2_generate_progress($callback, 'output', $line);
	}
close(\*GRUB2CMD);
return $out;
}

# grub2_generate_progress(&callback, event, value)
# Sends a generation progress event when a callback was supplied.
sub grub2_generate_progress
{
my ($callback, $event, $value) = @_;
return if (!$callback);
$callback->($event, $value);
return;
}

# grub2_config_files()
# Returns files and directories that should be included in config backups.
sub grub2_config_files
{
my @files;
foreach my $key (qw(default_file grub_cfg grub_dir custom_file password_file
		   color_file theme_dir background_dir grubenv_file bls_dir)) {
	my $file = &grub2_config_value($key);
	push(@files, $file) if (defined($file) && $file ne '');
	}
return &unique(@files);
}

# grub2_status_warnings()
# Returns actionable warnings for the index page.
sub grub2_status_warnings
{
my @warnings;
my $default_file = &grub2_config_value('default_file') || '';
my $grub_cfg = &grub2_config_value('grub_cfg') || '';
push(@warnings, $text{'index_warn_missing_default'})
	if ($default_file ne '' && !-r $default_file);
push(@warnings, $text{'index_warn_missing_cfg'})
	if ($grub_cfg ne '' && !-r $grub_cfg);
push(@warnings, $text{'index_warn_mkconfig'})
	if (!&grub2_command('mkconfig_cmd'));
my %env = &grub2_read_env();
return @warnings if ($default_file eq '' || !-r $default_file);
my $parsed = &read_grub_defaults($default_file);
if (($parsed->{'values'}->{'GRUB_DEFAULT'} || '') eq 'saved' &&
    !$env{'saved_entry'}) {
	push(@warnings, $text{'index_warn_saved'});
	}
my $theme = $parsed->{'values'}->{'GRUB_THEME'} || '';
if ($theme ne '') {
	my $terr = &grub2_validate_theme_path($theme, $text{'defaults_theme'});
	push(@warnings, &text('index_warn_theme_invalid', $terr)) if ($terr);
	}
if ($theme ne '' &&
    ($parsed->{'values'}->{'GRUB_TERMINAL_OUTPUT'} || '') eq 'console') {
	push(@warnings, $text{'index_warn_theme_console'});
	}
return @warnings;
}

# grub2_dirname(path)
# Returns the directory component of a Unix path.
sub grub2_dirname
{
my ($path) = @_;
return '' if (!defined($path) || $path eq '');
my $dir = dirname($path);
return '' if ($dir eq '.');
return $dir;
}

1;
