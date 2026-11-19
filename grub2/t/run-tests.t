#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

# script_dir()
# Returns the directory containing this test file, without relying on Cwd.
sub script_dir
{
    my $path = $0;
    if ($path =~ m{^/}) {
        $path =~ s{/[^/]+$}{};
        return $path;
    }
    my $cwd = `pwd`;
    chomp($cwd);
    if ($path =~ m{/}) {
        $path =~ s{/[^/]+$}{};
        return $cwd.'/'.$path;
    }
    return $cwd;
}

# write_test_file(file, data)
# Writes fixture content atomically enough for local test setup.
sub write_test_file
{
    my ($file, $data) = @_;
    open(my $fh, '>', $file) or die "$file: $!";
    print $fh $data;
    close($fh);
}

# slurp_test_file(file)
# Reads a source or fixture file as one scalar for regex-based checks.
sub slurp_test_file
{
    my ($file) = @_;
    open(my $fh, '<', $file) or die "$file: $!";
    local $/ = undef;
    my $data = <$fh>;
    close($fh);
    return $data;
}

# make_script(file, data)
# Writes an executable shell fixture used as a fake GRUB helper.
sub make_script
{
    my ($file, $data) = @_;
    write_test_file($file, $data);
    chmod 0755, $file or die "chmod $file: $!";
}

my $bindir = script_dir();
my $rootdir = abs_path("$bindir/../..") or die "rootdir: $!";

my $confdir = tempdir(CLEANUP => 1);
my $vardir = tempdir(CLEANUP => 1);
write_test_file("$confdir/config", "os_type=linux\nos_version=0\n");
write_test_file("$confdir/var-path", "$vardir\n");
$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'grub2';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;

chdir("$bindir/..") or die "chdir: $!";
require "$bindir/../grub2-lib.pl";
our (%config, %text, $grub2_config_change_flag, $grub2_generate_time_flag);

my $work = tempdir(CLEANUP => 1);
my $default_file = "$work/default-grub";
my $custom_file = "$work/40_custom";
my $cfg_file = "$work/grub.cfg";
my $env_file = "$work/grubenv";
my $bls_dir = "$work/loader-entries";
my $password_file = "$work/grub.d/01_webmin_password";
my $color_file = "$work/grub.d/06_webmin_colors";
my $theme_dir = "$work/boot/grub2/themes";
my $background_dir = "$work/boot/grub2/backgrounds";
my $os_prober_file = "$work/grub.d/30_os-prober";
my $readme_file = "$work/grub.d/README";
my $bls_entry_file = "$bls_dir/rocky-5.14.0.conf";

$config{'default_file'} = $default_file;
$config{'custom_file'} = $custom_file;
$config{'password_file'} = $password_file;
$config{'color_file'} = $color_file;
$config{'theme_dir'} = $theme_dir;
$config{'background_dir'} = $background_dir;
$config{'grub_cfg'} = $cfg_file;
$config{'grub_dir'} = "$work/grub.d";
$config{'grubenv_file'} = $env_file;
$config{'bls_dir'} = $bls_dir;
$config{'script_check_cmd'} = '';
$config{'grubby_cmd'} = '';
$config{'shell_cmd'} = '/bin/sh';
mkdir $config{'grub_dir'} or die "mkdir grub.d: $!";
mkdir $bls_dir or die "mkdir bls_dir: $!";

ok(!grub2_needs_regenerate(), 'fresh module does not need regeneration');
grub2_mark_regenerate_needed();
ok(grub2_needs_regenerate(), 'config change flag requires regeneration');
grub2_mark_generated();
ok(!grub2_needs_regenerate(), 'generate flag clears regeneration need');
utime(time() + 2, time() + 2, $grub2_config_change_flag);
ok(grub2_needs_regenerate(), 'newer config flag requires regeneration again');
utime(time() + 3, time() + 3, $grub2_generate_time_flag);
ok(!grub2_needs_regenerate(), 'newer generate flag clears stale change');

my $version_cmd = "$work/grub-version";
make_script($version_cmd, "#!/bin/sh\necho 'grub2-mkconfig (GRUB) 2.06'\n");
{
    local $config{'install_cmd'} = '';
    local $config{'mkconfig_cmd'} = $version_cmd;
    is(grub2_version_text(), 'GRUB version 2.06',
       'GRUB version text is parsed for page headers');
}

my $efi_firmware_dir = "$work/firmware-efi";
make_path($efi_firmware_dir);
is(grub2_boot_mode($efi_firmware_dir), 'uefi',
   'boot mode detection reports UEFI when EFI firmware directory exists');
is(grub2_boot_mode("$work/no-efi-firmware"), 'bios',
   'boot mode detection reports BIOS when EFI firmware directory is absent');
my $efivars_dir = "$efi_firmware_dir/efivars";
make_path($efivars_dir);
write_test_file("$efivars_dir/SecureBoot-webmin-test",
		"\0\0\0\0\1");
is(grub2_secure_boot_status($efi_firmware_dir, $efivars_dir, ''),
   'enabled', 'Secure Boot detection reads enabled EFI variable');
write_test_file("$efivars_dir/SecureBoot-webmin-test",
		"\0\0\0\0\0");
is(grub2_secure_boot_status($efi_firmware_dir, $efivars_dir, ''),
   'disabled', 'Secure Boot detection reads disabled EFI variable');
is(grub2_secure_boot_status("$work/no-efi-firmware", "$work/no-efivars", ''),
   'not_applicable', 'Secure Boot detection is not applicable for BIOS boot');

my $index_source = slurp_test_file("$bindir/../index.cgi");
my $defaults_source = slurp_test_file("$bindir/../edit_defaults.cgi");
my $save_defaults_source = slurp_test_file("$bindir/../save_defaults.cgi");
my $theme_source = slurp_test_file("$bindir/../edit_theme.cgi");
my $save_theme_source = slurp_test_file("$bindir/../save_theme.cgi");
my $edit_install_source = slurp_test_file("$bindir/../edit_install.cgi");
my $acl_source = slurp_test_file("$bindir/../acl_security.pl");
unlike($index_source, qr/\[\s*'security'\s*,/,
       'index has no separate security tab');
unlike($index_source, qr/\[\s*'defaults'\s*,/,
       'index has no separate defaults tab');
unlike($index_source, qr/\[\s*'status'\s*,/,
       'index has no separate status tab');
unlike($index_source, qr/sub print_defaults_tab\b/,
       'index has no separate default settings panel');
unlike($index_source, qr/sub print_status_tab\b|sub print_summary\b/,
       'index does not carry status-page rendering code');
my $status_source = slurp_test_file("$bindir/../status.cgi");
like($index_source,
     qr/ui_print_header\(&grub2_version_text\(\) \|\| "".*?\$text\{'index_title'\}/s,
     'index header displays GRUB version text when available');
like($index_source,
     qr/sub can_use_index\b.*?\$access->\{'view'\}.*?\$access->\{'edit'\}.*?\$access->\{'security'\}.*?\$access->\{'manual'\}.*?\$access->\{'install'\}.*?\$access->\{'apply'\} && &grub2_command\('mkconfig_cmd'\)/s,
     'index allows action-only ACLs without granting entry view');
like($index_source,
     qr/if \(\$access\{'view'\}\) \{.*?grub2_install_issues/s,
     'index hides install issue details without view ACL');
like($index_source,
     qr/if \(\$access\{'view'\}\) \{.*?grub2_status_warnings.*?ui_tabs_start/s,
     'index hides status warnings and entry tabs without view ACL');
like($index_source,
     qr/my \$can_default = \$access->\{'view'\} && \$access->\{'runtime'\}/,
     'index runtime default actions require view ACL');
like($index_source,
     qr/my \$can_once = \$access->\{'view'\} && \$access->\{'runtime'\}/,
     'index one-time boot actions require view ACL');
like($index_source,
     qr/sub print_action_buttons\b.*?ui_buttons_row\("status\.cgi".*?ui_buttons_row\("generate\.cgi"/ms,
     'index exposes status above the bottom regenerate action');
like($acl_source,
     qr/ui_table_row\(\$text\{'acl_view'\},\s*&ui_yesno_radio\("view"/s,
     'ACL view permission is rendered as a standalone row');
unlike($acl_source, qr/acl_section_view/,
       'ACL view permission does not use a one-row section heading');
like($acl_source, qr/&ui_yesno_radio\("view", \$o->\{'view'\}\)/,
     'ACL editor uses the supplied view ACL value directly');
unlike($acl_source, qr/grub2_(?:check|effective)_acl/,
       'ACL editor does not normalize supplied ACL values');
like($status_source,
     qr/%access = &get_module_acl\(\).*?\$access\{'view'\}/s,
     'status page enforces view ACL directly');
like($status_source, qr/index_boot_mode.*boot_mode_cell/s,
     'status page displays detected boot mode');
like($status_source, qr/index_secure_boot.*secure_boot_cell/s,
     'status page displays Secure Boot status');
like($status_source,
     qr/&print_summary\(\$parsed\);.*?&print_boot_selection\(\$parsed, \\%env\);.*?&print_security_status\(\);.*?&print_theme_status\(\$parsed\);/ms,
     'status page renders summary, boot selection, password protection, and theme state');
like($status_source,
     qr/sub print_summary\b.*?GRUB_TIMEOUT_STYLE.*?GRUB_DISABLE_OS_PROBER.*?^}/ms,
     'configuration summary includes common default settings');
like($status_source,
     qr/sub print_summary\b.*?ui_table_start\(\$text\{'index_summary'\}.*?ui_table_end\(\)/s,
     'status page keeps configuration summary as a normal table');
like($status_source,
     qr/sub print_theme_status\b.*?ui_hidden_table_start\(\$text\{'defaults_theme_header'\}.*?"theme", 0.*?ui_hidden_table_end\("theme"\)/s,
     'status page puts theme status in a closed collapsible table');
like($status_source,
     qr/sub print_boot_selection\b.*?ui_hidden_table_start\(\$text\{'index_boot_selection'\}.*?"boot_selection", 0.*?ui_hidden_table_end\("boot_selection"\)/s,
     'status page puts boot selection in a closed collapsible table');
like($status_source,
     qr/sub print_security_status\b.*?ui_hidden_table_start\(\$text\{'security_header'\}.*?"security", 0.*?ui_hidden_table_end\("security"\)/s,
     'status page puts password protection in a closed collapsible table');
like($status_source,
     qr/index_install_cmd'\}.*?&ui_table_hr\(\);.*?index_entries'\}/ms,
     'configuration summary separates paths and commands from defaults');
like($status_source, qr/index_kernel_options_source.*grub2_kernel_options_source_text/s,
     'status page displays detected kernel options source');
like($status_source,
     qr/sub value_cell\b.*defaults_true.*defaults_false/s,
     'status page displays GRUB boolean values as yes or no');
like($status_source,
     qr/sub literal_cell\b.*ui_tag\('tt', &html_escape\(\$value\)\)/s,
     'status page renders literal GRUB values with tt tags');
like($status_source,
     qr/status_table_row\(\$text\{'defaults_default'\}, "default",\s*&literal_cell/s,
     'status page renders the default menu entry as a literal value');
like($status_source,
     qr/status_table_row\(\$text\{'index_saved_entry'\}, "saved_entry",\s*&literal_cell/s,
     'status page renders the environment default entry as a literal value');
like($status_source,
     qr/status_table_row\(\$text\{'index_next_entry'\}, "next_entry",\s*&literal_cell/s,
     'status page renders the next boot entry as a literal value');
unlike($index_source.$status_source.$theme_source.$edit_install_source,
       qr/ui_tag\('code'/,
       'GRUB pages use tt tags instead of code tags for literal values');
like($status_source,
     qr/sub path_cell\b.*manual_path_link\(\$path, &ui_tag\('tt'/s,
     'status page renders paths with tt tags');
like($status_source,
     qr/sub manual_path_link\b.*\$access\{'manual'\}.*grub2_manual_file\(\$path\).*edit_manual\.cgi\?file=/s,
     'status page links allowlisted paths to the manual editor when permitted');
like($status_source, qr/sub status_table_row\b.*hlink\(\$label, \$help\)/s,
     'status page labels use contextual help links');
like($status_source,
     qr/status_table_row\(\$text\{'index_boot_mode'\}, "boot_mode".*status_table_row\(\$text\{'index_secure_boot'\}, "secure_boot"/s,
     'status page links firmware state rows to help');
like($status_source,
     qr/status_table_row\(\$text\{'index_default_file'\}, "default_file".*status_table_row\(\$text\{'index_grub_cfg'\}, "grub_cfg"/s,
     'status page links GRUB path rows to help');
like($status_source,
     qr/\[ 'GRUB_TIMEOUT_STYLE', \$text\{'defaults_timeout_style'\}, "timeout_style" \]/,
     'status page reuses default-setting help files');
foreach my $help (
	"boot_mode", "secure_boot", "default_file", "grub_cfg", "grub_dir",
	"bls_dir", "mkconfig", "install_cmd", "entries", "saved_entry",
	"next_entry", "grubenv", "security_file", "security_mkpasswd",
    )
{
	ok(-r "$bindir/../help/$help.html", "status help file exists for $help");
	}
like($defaults_source,
     qr/sub default_entry_input\b.*?ui_select\("default"/ms,
     'defaults editor uses a generated default-entry selector');
like($defaults_source,
     qr/ui_table_row\(\s*&hlink\(\$text\{'defaults_default'\}, "default"\),\s*&default_entry_input/s,
     'defaults editor renders default-entry selector as a standard table row');
unlike($defaults_source, qr/ui_table_span\(&default_entry_row/,
       'defaults editor does not render default-entry selector as a span row');
like($defaults_source, qr/field-sizing:\s*content/,
     'defaults editor sizes default-entry selector to selected content');
unlike($defaults_source, qr/default_custom|defaults_default_custom|__custom__/,
       'defaults editor does not expose a free-form default entry value');
unlike($defaults_source, qr/defaults_saved_note/,
       'defaults editor keeps saved-entry explanation in help');
unlike($defaults_source, qr/default_bls_update_input|update_bls/,
       'defaults editor does not expose a BLS update checkbox');
like($defaults_source, qr/grub2_bls_kernel_option_warnings/,
     'defaults editor warns when BLS kernel option sources need attention');
like($save_defaults_source, qr/grub2_update_bls_kernel_args/s,
     'defaults save can apply changed all-kernel options to BLS entries');
like($save_defaults_source,
     qr/GRUB_CMDLINE_LINUX_DEFAULT.*?grub2_bls_kernel_arg_targets/s,
     'defaults save can apply changed default-kernel options to BLS entries');
like($save_defaults_source,
     qr/lock_bls_update_files.*?update_bls_kernel_args.*?webmin_log\("defaults"\)/s,
     'defaults save logs BLS updates with the defaults action');
like($save_defaults_source,
     qr/sub lock_bls_update_files\b.*?grub2_entry_uses_kernelopts.*?grubenv_file/ms,
     'defaults save logs grubenv when BLS kernelopts may change');
like($save_defaults_source, qr/grub2_set_bls_rescue_disabled/s,
     'defaults save can hide BLS rescue entries');
unlike($save_defaults_source, qr/webmin_log\("bls_args"\)/,
       'defaults save does not create a separate BLS log entry');
like($save_defaults_source, qr/sub valid_default_entry_value\b.*?grub2_entry_selector/ms,
     'defaults save validates posted default entries against detected entries');
unlike($index_source, qr/entries_action\.cgi/,
       'generated menu uses per-row actions instead of a checked table');
like($index_source, qr/set_default\.cgi\?idx=/,
     'generated menu exposes per-row default action');
like($index_source, qr/reboot_once\.cgi\?idx=/,
     'generated menu exposes per-row one-time boot action');
unlike($index_source, qr/ui_alert\(\$text\{'custom_empty'\}/,
       'empty custom entries use inline text instead of an alert');
unlike($index_source, qr/custom_add_msg/,
       'empty custom entries use a standalone add button');
like($index_source,
     qr/if \(!\@entries\).*ui_br\(\).*ui_p\(\$text\{'custom_empty'\}\).*ui_link\("edit_custom\.cgi", \$text\{'custom_add'\},\s*"plus"\)/s,
     'empty custom entries add a break before the message and use a compact add link');
unlike($index_source,
       qr/if \(!\@entries\).*ui_buttons_row\("edit_custom\.cgi"/s,
       'empty custom entries do not use large button rows');
like($index_source,
     qr/my \$show_order = \$can_edit && \@entries > 1;.*\(\$show_order \? \( \$text\{'index_col_order'\} \) : \( \)\).*custom_order_cell/s,
     'custom entries hide the order column until multiple entries can be reordered');
like($index_source,
     qr/sub entry_details_content\b.*index_col_index.*index_col_id.*entry_source_detail_line.*index_col_version.*index_col_kernel.*index_col_initrd.*index_col_machine_id.*index_col_options.*^}/ms,
     'entry details include useful generated entry metadata');
like($index_source,
     qr/sub entry_source_detail_line\b.*index_col_file.*index_col_generator.*ui_tag\('a'.*edit_manual\.cgi\?file=/ms,
     'entry details label generator scripts and link direct entry files to the manual editor');
like($index_source,
     qr/sub entry_source_detail_line\b.*else \{\s*\$html = &ui_tag\('tt', &html_escape\(\$file\)\).*?\$access\{'manual'\}.*?edit_manual\.cgi\?file=/s,
     'entry details link editable generator scripts to the manual editor');
like($index_source,
     qr/sub entry_source_detail_line\b.*entry_file_display_name.*'title'\s*=>\s*\$file.*edit_manual\.cgi\?file=/s,
     'entry details display short direct file names while preserving full paths');
like($index_source,
     qr!sub entry_file_display_name\b.*s\{\.\*/\}\{\}!s,
     'entry file display names strip leading directories');
like($index_source,
     qr/sub entry_detail_line\b.*white-space: pre-wrap.*grid-template-columns: max-content minmax\(0, 1fr\)/s,
     'entry detail values wrap with hanging indentation');
unlike($index_source,
       qr/entry_detail_line\(\$text\{'index_col_group'\}/,
       'entry details do not duplicate submenu metadata');
unlike($index_source,
       qr/entry_detail_line\(\$text\{'index_col_line'\}/,
       'entry details do not include low-value line metadata');
like($index_source, qr/edit_theme\.cgi/,
     'index exposes GRUB theme and appearance action');
like($theme_source, qr/color_pair_select\("color_normal".*color_pair_select\("color_highlight".*\$name\."_mode"/s,
     'theme editor uses color-pair modes instead of unset per color');
like($theme_source, qr/grub2_color_mode_changed/,
     'theme editor hides custom color controls until needed');
like($theme_source, qr/querySelector\('select\[name="' \+ name \+ '_mode"\]'\)/,
     'theme editor finds color mode selects by name for SPA themes');
like($theme_source, qr/document\.addEventListener\('change', function\(event\)/,
     'theme editor uses delegated color mode change handling');
like($theme_source, qr/custom\.style\.visibility.*?visible.*?hidden/s,
     'theme editor uses hidden visibility for inactive color pairs');
unlike($theme_source, qr/defaults_color_text'\}\)\)\." "/,
       'theme editor does not make color labels bold');
like($theme_source, qr/sub gfxmode_select\b.*ui_select\("gfxmode".*sub gfxmode_options\b.*1920x1080/s,
     'theme editor provides a graphics mode resolution dropdown');
like($save_theme_source, qr/\$input\.'_mode'/,
     'theme save uses the color-pair mode field');
like($save_theme_source, qr/grub2_install_background_source/,
     'theme save installs background images below the GRUB boot tree');
like($theme_source, qr/ui_print_footer\("index\.cgi"/,
     'theme editor returns to the module index');
like($save_theme_source, qr/redirect\("index\.cgi"\)/,
     'theme save redirects to the module index');
like($index_source, qr/edit_install\.cgi/,
     'index exposes GRUB boot loader install action');
like($edit_install_source, qr/index_boot_mode.*install_boot_mode_cell/s,
     'install form displays boot mode');
like($edit_install_source, qr/index_secure_boot.*install_secure_boot_cell/s,
     'install form displays Secure Boot state');
like($edit_install_source, qr/grub2_default_bootloader_id/,
     'install form prefills boot loader ID when detected');
like($edit_install_source, qr/install_boot_directory.*use_boot_directory/s,
     'install form exposes optional boot directory');
like($index_source,
     qr/sub print_action_buttons\b.*?&icons_table\(/ms,
     'index action shortcuts use an icon table');
like($index_source,
     qr/sub print_action_buttons\b.*?print &ui_hr\(\) if \(\$access->\{'view'\}\)/ms,
     'index omits the top action separator for action-only ACLs');
like($index_source,
     qr/sub print_action_buttons\b.*?ui_buttons_row\("generate\.cgi"/ms,
     'index exposes a bottom regenerate action button');
my $generate_source = slurp_test_file("$bindir/../generate.cgi");
like($generate_source, qr/ui_details/,
     'generate progress keeps command output in details');
like($generate_source, qr/data-second-print/,
     'generate progress keeps second progress print markers');
unlike($generate_source, qr/ui_tag_start\('pre'/,
       'generate progress does not print a raw output block');

my $defaults = <<'EOF';
# Existing administrator comment
GRUB_DEFAULT=0 # keep this comment
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_DISABLE_OS_PROBER=false
EXTERNAL_SETTING="preserve me"
EOF
write_test_file($default_file, $defaults);

my $parsed = read_grub_defaults($default_file);
is($parsed->{'values'}->{'GRUB_DEFAULT'}, '0', 'parsed default entry');
is($parsed->{'values'}->{'GRUB_CMDLINE_LINUX_DEFAULT'}, 'quiet splash',
   'parsed quoted kernel args');
is($parsed->{'values'}->{'EXTERNAL_SETTING'}, 'preserve me',
   'parsed unmanaged setting');

my $new_text = set_grub_default_values($parsed, {
    GRUB_DEFAULT => 'saved',
    GRUB_TIMEOUT => '10',
    GRUB_TIMEOUT_STYLE => undef,
    GRUB_TERMINAL_OUTPUT => 'gfxterm',
    GRUB_GFXMODE => '1024x768,800x600',
    GRUB_CMDLINE_LINUX_DEFAULT => 'quiet splash mitigations=off',
    GRUB_CMDLINE_LINUX => 'console=ttyS0',
    GRUB_DISABLE_RECOVERY => 'true',
    GRUB_DISABLE_OS_PROBER => 'true',
    GRUB_THEME => '/boot/grub/themes/webmin/theme.txt',
    GRUB_BACKGROUND => '/boot/grub/background.png',
    GRUB_COLOR_NORMAL => 'white/black',
    GRUB_COLOR_HIGHLIGHT => 'black/light-gray',
});
like($new_text, qr/# Existing administrator comment/,
     'whole-line comments are preserved');
like($new_text, qr/GRUB_DEFAULT=saved # keep this comment/,
     'trailing assignment comment is preserved');
unlike($new_text, qr/GRUB_TIMEOUT_STYLE=/,
       'unset setting is removed');
like($new_text, qr/EXTERNAL_SETTING="preserve me"/,
     'unmanaged setting is preserved');
like($new_text, qr/GRUB_CMDLINE_LINUX=console=ttyS0/,
     'missing managed setting is appended');
like($new_text, qr/GRUB_TERMINAL_OUTPUT=gfxterm/,
     'terminal output setting is appended');
like($new_text, qr/GRUB_GFXMODE=1024x768,800x600/,
     'graphics mode setting is appended');
like($new_text, qr{GRUB_THEME=/boot/grub/themes/webmin/theme\.txt},
     'theme setting is appended');
like($new_text, qr/GRUB_COLOR_HIGHLIGHT=black\/light-gray/,
     'color setting is appended');
unlike($new_text, qr/# Added by Webmin/,
       'structured save does not add a Webmin marker comment');
my $kept_default = set_grub_default_values($parsed, {
    GRUB_TIMEOUT => '7',
});
like($kept_default, qr/GRUB_DEFAULT=0 # keep this comment/,
     'default entry is preserved when not updated');
my $unset_cmdline = set_grub_default_values($parsed, {
    GRUB_CMDLINE_LINUX_DEFAULT => undef,
    GRUB_CMDLINE_LINUX => undef,
});
unlike($unset_cmdline, qr/GRUB_CMDLINE_LINUX_DEFAULT=/,
       'blank default kernel args are removed');
unlike($unset_cmdline, qr/GRUB_CMDLINE_LINUX=/,
       'blank kernel args are not appended');
my $webmin_block = parse_grub_defaults_text(<<'EOF', $default_file);
# Added by Webmin
GRUB_COLOR_NORMAL=green/dark-gray
GRUB_COLOR_HIGHLIGHT=light-blue/yellow
EOF
my $changed_block = set_grub_default_values($webmin_block, {
    GRUB_COLOR_NORMAL => undef,
    GRUB_COLOR_HIGHLIGHT => undef,
    GRUB_THEME => '/boot/grub2/themes/webmin/theme.txt',
});
unlike($changed_block, qr/# Added by Webmin/,
       'managed default marker is not written when replacing appended settings');
like($changed_block, qr/GRUB_THEME=\/boot\/grub2\/themes\/webmin\/theme\.txt/,
     'new appended setting is written without a Webmin marker');
unlike($changed_block, qr/GRUB_COLOR_NORMAL=/,
       'removed color setting is not kept in reused Webmin block');
my $cleared_block = set_grub_default_values($webmin_block, {
    GRUB_COLOR_NORMAL => undef,
    GRUB_COLOR_HIGHLIGHT => undef,
});
unlike($cleared_block, qr/# Added by Webmin/,
       'orphan managed default marker is removed');

SKIP: {
    skip '/bin/sh is unavailable', 2 if (!-x '/bin/sh');
    is(validate_grub_defaults_text($new_text, $default_file), undef,
       'valid defaults pass shell syntax validation');
    ok(validate_grub_defaults_text("if then\n", $default_file),
       'invalid defaults fail shell syntax validation');
}
like(validate_grub_defaults_text($new_text, 'relative-grub'),
     qr/absolute/, 'relative default file path is rejected');
is(grub2_validate_setting_path('/boot/grub/themes/webmin/theme.txt',
                              $text{'defaults_theme'}), undef,
   'safe defaults path is accepted');
like(grub2_validate_setting_path('/tmp/theme$(touch bad).txt',
                                $text{'defaults_theme'}),
     qr/characters/, 'unsafe defaults path characters are rejected');
my $theme_file = "$work/theme.txt";
my $background_file = "$work/background.png";
write_test_file($theme_file, "# theme\n");
write_test_file($background_file, "png\n");
is(grub2_validate_theme_path($theme_file, $text{'defaults_theme'}), undef,
   'readable theme file is accepted');
like(grub2_validate_theme_path("$work/Marathon-TitleScreen.tar.gz",
                               $text{'defaults_theme'}),
     qr/archive/, 'theme archive is rejected');
like(grub2_validate_theme_path("$work/missing-theme.txt",
                               $text{'defaults_theme'}),
     qr/does not exist|cannot be read/, 'missing theme file is rejected');
is(grub2_validate_background_path($background_file,
                                  $text{'defaults_background'}), undef,
   'readable background file is accepted');
like(grub2_validate_background_path("$work/missing-background.png",
                                    $text{'defaults_background'}),
     qr/does not exist|cannot be read/, 'missing background file is rejected');
write_test_file("$work/background.txt", "not an image\n");
like(grub2_validate_background_path("$work/background.txt",
                                    $text{'defaults_background'}),
     qr/PNG|JPEG|TGA/, 'unsupported background image type is rejected');
my ($installed_background, $background_err) =
    grub2_install_background_source($background_file);
is($background_err, undef, 'background image install succeeds');
like($installed_background, qr{\Q$background_dir\E/background\.png\z},
     'background image installs below configured boot background directory');
like(slurp_test_file($installed_background), qr/png/,
     'installed background image is copied');
my ($same_background, $same_background_err) =
    grub2_install_background_source($installed_background);
is($same_background_err, undef, 'already-installed background is accepted');
is($same_background, $installed_background,
   'already-installed background image is reused');
my $theme_source_dir = "$work/source-theme";
make_path("$theme_source_dir/icons");
write_test_file("$theme_source_dir/theme.txt", "# source theme\n");
write_test_file("$theme_source_dir/icons/logo.png", "png\n");
my $theme_icon_link = "$theme_source_dir/icons/Manjaro.i686.svg";
my $can_symlink = symlink("logo.png", $theme_icon_link);
my ($installed_theme, $install_err) =
    grub2_install_theme_source($theme_source_dir);
is($install_err, undef, 'theme directory install succeeds');
like($installed_theme, qr{\Q$theme_dir\E/source-theme/theme\.txt\z},
     'theme directory installs below configured boot theme directory');
like(slurp_test_file($installed_theme), qr/source theme/,
     'installed theme file is copied');
like(slurp_test_file("$theme_dir/source-theme/icons/logo.png"), qr/png/,
     'installed theme assets are copied');
SKIP: {
    skip 'symlink unavailable', 3 if (!$can_symlink);
    my $installed_link = "$theme_dir/source-theme/icons/Manjaro.i686.svg";
    like(slurp_test_file($installed_link), qr/png/,
         'safe theme symlink asset is copied');
    ok(!-l $installed_link, 'safe theme symlink is installed as a file');
    my $bad_theme_dir = "$work/bad-symlink-theme";
    make_path("$bad_theme_dir/icons");
    write_test_file("$bad_theme_dir/theme.txt", "# bad symlink theme\n");
    symlink($background_file, "$bad_theme_dir/icons/outside.svg")
        or skip 'second symlink unavailable', 1;
    my ($bad_theme, $bad_err) = grub2_install_theme_source($bad_theme_dir);
    like($bad_err, qr/unsafe|unsupported/,
         'theme symlink outside source tree is rejected');
}
my ($same_theme, $same_err) = grub2_install_theme_source($installed_theme);
is($same_err, undef, 'already-installed theme file is accepted');
is($same_theme, $installed_theme, 'already-installed theme file is reused');
is(grub2_theme_archive_type('https://example.test/theme.zip?download=1'),
   'zip', 'theme archive type ignores URL query string');
is(grub2_theme_source_name('https://example.test/themes/Blue/theme.txt?raw=1'),
   'Blue', 'direct theme.txt URL uses parent directory as theme name');
like(grub2_validate_archive_members('../bad'), qr/unsafe|unsupported/,
     'unsafe archive member is rejected');
my $download_theme_dir = "$work/grub2-theme-download-123";
make_path($download_theme_dir);
write_test_file("$download_theme_dir/theme.txt", "# downloaded theme\n");
my ($download_theme, $download_err) = grub2_install_theme_directory(
    $download_theme_dir, 'https://example.test/themes/Downloaded/theme.txt');
is($download_err, undef, 'downloaded theme.txt directory install succeeds');
like($download_theme, qr{\Q$theme_dir\E/Downloaded/theme\.txt\z},
     'downloaded theme.txt URL names theme from URL parent directory');
SKIP: {
    my $tar = has_command('tar');
    skip 'tar is unavailable', 4 if (!$tar);
    my $archive_source_dir = "$work/source-theme-archive";
    make_path("$archive_source_dir/icons");
    write_test_file("$archive_source_dir/theme.txt", "# source theme\n");
    write_test_file("$archive_source_dir/icons/logo.png", "png\n");
    my $archive = "$work/source-theme.tar.gz";
    my $cmd = quotemeta($tar).' czf '.quotemeta($archive).
              ' -C '.quotemeta($work).' source-theme-archive';
    system($cmd) == 0 or skip 'tar archive creation failed', 4;
    my ($archive_theme, $archive_err) = grub2_install_theme_source($archive);
    is($archive_err, undef, 'theme tar archive install succeeds');
    like($archive_theme, qr{\Q$theme_dir\E/source-theme-archive/theme\.txt\z},
         'theme tar archive installs to a unique boot theme directory');
    like(slurp_test_file($archive_theme), qr/source theme/,
         'theme tar archive content is installed');
    my $bad_archive_dir = "$work/bad-archive-theme";
    make_path($bad_archive_dir);
    write_test_file("$bad_archive_dir/theme.txt", "# bad archive theme\n");
    symlink('theme.txt', "$bad_archive_dir/link.txt")
        or skip 'archive symlink unavailable', 1;
    my $bad_archive = "$work/bad-theme.tar.gz";
    my $bad_cmd = quotemeta($tar).' czf '.quotemeta($bad_archive).
                  ' -C '.quotemeta($work).' bad-archive-theme';
    system($bad_cmd) == 0 or skip 'bad tar archive creation failed', 1;
    my ($bad_archive_extract, $bad_archive_err) =
        grub2_extract_theme_archive($bad_archive, 'targz');
    remove_tree($bad_archive_extract) if ($bad_archive_extract);
    like($bad_archive_err, qr/unsafe|unsupported/,
         'theme archives reject symlink members before extraction');
}

my $save_err = save_grub_defaults_values({
    GRUB_DEFAULT => 'saved',
    GRUB_TIMEOUT => '3',
    GRUB_TIMEOUT_STYLE => 'countdown',
    GRUB_TERMINAL_OUTPUT => 'gfxterm',
    GRUB_GFXMODE => 'auto',
    GRUB_CMDLINE_LINUX_DEFAULT => 'quiet',
    GRUB_CMDLINE_LINUX => '',
    GRUB_DISABLE_RECOVERY => undef,
    GRUB_DISABLE_OS_PROBER => 'true',
    GRUB_THEME => '/boot/grub/themes/webmin/theme.txt',
    GRUB_BACKGROUND => '/boot/grub/background.png',
    GRUB_COLOR_NORMAL => 'white/black',
    GRUB_COLOR_HIGHLIGHT => 'black/light-gray',
});
is($save_err, undef, 'structured save succeeds');
my $saved = slurp_test_file($default_file);
like($saved, qr/GRUB_DEFAULT=saved/, 'structured save writes default');
like($saved, qr/GRUB_DISABLE_OS_PROBER=true/, 'structured save writes boolean');
like($saved, qr/GRUB_TERMINAL_OUTPUT=gfxterm/,
     'structured save writes terminal output');
like($saved, qr/GRUB_GFXMODE=auto/,
     'structured save writes graphics mode');
like($saved, qr/GRUB_THEME=\/boot\/grub\/themes\/webmin\/theme\.txt/,
     'structured save writes theme');
like($saved, qr/GRUB_COLOR_NORMAL=white\/black/,
     'structured save writes colors');
is(grub2_save_color_script(), undef, 'color generator script save succeeds');
my $color_data = slurp_test_file($color_file);
like($color_data, qr/Webmin managed GRUB menu colors/,
     'color generator script is managed');
like($color_data, qr/menu_color_normal/,
     'color generator script emits menu color variables');
like($color_data, qr/GRUB_COLOR_NORMAL/,
     'color generator script reads defaults color variables');
like($color_data, qr/webmin_grub2_defaults_file=.*default-grub/,
     'color generator script sources configured defaults file');
is((stat($color_file))[2] & 0777, 0755,
   'color generator script is executable');
my $color_output = `$color_file`;
like($color_output, qr/set menu_color_normal=white\/black/,
     'color generator script emits configured normal color');
like($color_output, qr/set color_highlight=black\/light-gray/,
     'color generator script emits configured highlight color');
{
    my $unmanaged_color = "$work/grub.d/06_other_colors";
    write_test_file($unmanaged_color, "#!/bin/sh\nexit 0\n");
    local $config{'color_file'} = $unmanaged_color;
    is(grub2_save_color_script(), $text{'defaults_ecolorfile'},
       'unmanaged color script is not overwritten');
}

write_test_file($custom_file, "menuentry 'Custom' { true }\n");
write_test_file($os_prober_file, "#!/bin/sh\nexit 0\n");
chmod(0755, $os_prober_file);
write_test_file($readme_file, "GRUB script directory notes\n");
write_test_file($bls_entry_file, <<'EOF');
title Rocky Linux
version 5.14.0
linux /vmlinuz-5.14.0
EOF
ok(grub2_manual_file($default_file), 'default file is manual-edit allowlisted');
ok(grub2_manual_file($custom_file), 'custom file is manual-edit allowlisted');
ok(grub2_manual_file($os_prober_file), 'grub.d script is manual-edit allowlisted');
ok(grub2_manual_file($readme_file), 'grub.d regular file is manual-edit allowlisted');
ok(grub2_manual_file($bls_entry_file), 'BLS entry is manual-edit allowlisted');
ok(!grub2_manual_file("$work/not-allowed"), 'unexpected file is rejected');
SKIP: {
    my $outside_manual = "$work/outside-manual-target";
    my $manual_link = "$work/grub.d/09_symlink";
    write_test_file($outside_manual, "outside\n");
    skip 'symlink unavailable', 5 if (!symlink($outside_manual, $manual_link));
    ok(!grub2_manual_file($manual_link),
       'grub.d symlink is not manual-edit allowlisted');
    is(save_manual_grub_file($manual_link, "#!/bin/sh\nexit 0\n"),
       $text{'manual_efile'}, 'manual save rejects grub.d symlink');
    is(slurp_test_file($outside_manual), "outside\n",
       'manual save does not write through grub.d symlink');

    my $outside_bls = "$work/outside-bls-target";
    my $bls_link = "$bls_dir/symlink.conf";
    write_test_file($outside_bls, "title Outside\nlinux /vmlinuz\n");
    if (!symlink($outside_bls, $bls_link)) {
        unlink($manual_link);
        skip 'second symlink unavailable', 2;
    }
    ok(!grub2_manual_file($bls_link),
       'BLS symlink is not manual-edit allowlisted');
    {
        local $config{'custom_file'} = $manual_link;
        ok(!grub2_manual_file($manual_link),
           'configured custom symlink is not manual-edit allowlisted');
    }
    unlink($manual_link);
    unlink($bls_link);
}
is(save_manual_grub_file($default_file, $saved), undef,
   'manual save validates default file');
is(save_manual_grub_file($custom_file, "menuentry 'X' { true }\n"), undef,
   'manual save permits custom GRUB script');
like(save_manual_grub_file($custom_file, "menuentry 'Broken' {\n"),
     qr/unbalanced|failed/i,
     'manual save rejects invalid custom GRUB script');
chmod(0644, $custom_file);
is(save_manual_grub_file($custom_file, "menuentry 'X' { true }\n"), undef,
   'manual custom save succeeds after bad file mode');
ok(((stat($custom_file))[2] & 0111), 'manual custom save makes file executable');
is(save_manual_grub_file($os_prober_file, "#!/bin/sh\nexit 0\n"), undef,
   'manual save validates grub.d shell scripts');
like(save_manual_grub_file($os_prober_file, "if then\n"), qr/syntax|unexpected|then/i,
     'manual save rejects invalid grub.d shell scripts');
is(save_manual_grub_file($bls_entry_file, "title Rocky Linux\nlinux /vmlinuz\n"), undef,
   'manual save validates BLS entries');
like(save_manual_grub_file($bls_entry_file, "not-a-key\n"), qr/BLS|syntax/i,
     'manual save rejects invalid BLS entries');

my $mkpasswd = "$work/grub-mkpasswd-pbkdf2";
make_script($mkpasswd, <<'EOF');
#!/bin/sh
read first
read second
[ "$first" = "$second" ] || exit 1
echo "PBKDF2 hash of your password is grub.pbkdf2.sha512.10000.ABCDEF.123456"
EOF
$config{'mkpasswd_cmd'} = $mkpasswd;
my $security = grub2_read_security_config();
ok(!$security->{'enabled'}, 'missing password script is disabled');
is(grub2_save_security_config({
    enabled => 1,
    user => 'root',
    password => 'secret',
    password2 => 'secret',
    hash => '',
}), undef, 'password protection can be enabled');
my $password_data = slurp_test_file($password_file);
like($password_data, qr/set superusers="root"/,
     'password script writes superuser');
like($password_data, qr/password_pbkdf2 root grub\.pbkdf2\.sha512/,
     'password script writes PBKDF2 hash');
unlike($password_data, qr/secret/, 'password script does not store clear text');
is((stat($password_file))[2] & 0777, 0700,
   'password script is root-only executable');
$security = grub2_read_security_config();
ok($security->{'enabled'}, 'password state reads enabled');
is($security->{'user'}, 'root', 'password state reads user');
ok($security->{'hash'}, 'password state reads hash internally');
my $existing_hash = $security->{'hash'};
is(grub2_save_security_config({
    enabled => 1,
    user => 'root',
    password => 'secret2',
    password2 => 'secret2',
    hash => $existing_hash,
}), undef, 'unchanged visible hash does not block password replacement');
is(grub2_save_security_config({
    enabled => 1,
    user => 'root',
    password => 'secret2',
    password2 => 'secret2',
    hash => 'grub.pbkdf2.sha512.10000.CHANGED.7890',
}), $text{'security_epassmode'},
   'changed pasted hash cannot be combined with password replacement');
is(grub2_save_security_config({
    enabled => 1,
    user => 'admin',
    password => '',
    password2 => '',
    hash => '',
}), undef, 'password save keeps existing hash');
like(slurp_test_file($password_file), qr/set superusers="admin"/,
     'password save updates user while keeping hash');
is(grub2_save_security_config({
    enabled => 1,
    user => '-bad',
    password => '',
    password2 => '',
    hash => '',
}), $text{'security_euser'}, 'password save rejects unsafe user');
is(grub2_save_security_config({
    enabled => 1,
    user => 'root',
    password => 'one',
    password2 => 'two',
    hash => '',
}), $text{'security_epassmatch'}, 'password save rejects mismatch');
is(grub2_save_security_config({
    enabled => 1,
    user => 'root',
    password => '',
    password2 => '',
    hash => 'not-a-hash',
}), $text{'security_ehash'}, 'password save rejects invalid pasted hash');
is(grub2_save_security_config({
    enabled => 0,
    user => 'root',
    password => '',
    password2 => '',
    hash => '',
}), undef, 'password protection can be disabled');
unlike(slurp_test_file($password_file), qr/password_pbkdf2/,
       'disabled password script emits no password command');
{
    my $unmanaged_password = "$work/grub.d/01_other_password";
    write_test_file($unmanaged_password, "#!/bin/sh\nexit 0\n");
    local $config{'password_file'} = $unmanaged_password;
    is(grub2_save_security_config({
        enabled => 0,
        user => 'root',
        password => '',
        password2 => '',
        hash => '',
    }), $text{'security_eunmanaged'},
       'unmanaged password script is not overwritten');
}

write_test_file($cfg_file, <<'EOF');
set default="0"
menuentry 'Ubuntu' --class ubuntu --id 'gnulinux-simple-abc' {
    linux /vmlinuz-5.14.0 root=/dev/sda1 quiet
    initrd /initramfs-5.14.0.img
}
submenu 'Advanced options for Ubuntu' $menuentry_id_option 'gnulinux-advanced-abc' {
    menuentry 'Ubuntu, with Linux 6.8' --id 'gnulinux-6.8-advanced-abc' {
    }
    menuentry "Ubuntu, rescue mode" {
    }
}
EOF

my @entries = grub2_boot_entries($cfg_file);
is(scalar(@entries), 3, 'parsed three boot entries');
is($entries[0]->{'title'}, 'Ubuntu', 'parsed top-level title');
is($entries[0]->{'id'}, 'gnulinux-simple-abc', 'parsed top-level ID');
is($entries[0]->{'linux'}, '/vmlinuz-5.14.0',
   'parsed generated kernel path');
is($entries[0]->{'initrd'}, '/initramfs-5.14.0.img',
   'parsed generated initrd path');
is($entries[0]->{'options'}, 'root=/dev/sda1 quiet',
   'parsed generated kernel options');
is($entries[0]->{'version'}, '5.14.0',
   'derived generated kernel version');
is(join(' > ', @{$entries[1]->{'path'}}), 'Advanced options for Ubuntu',
   'parsed submenu path');
is(grub2_entry_selector($entries[1]), 'gnulinux-6.8-advanced-abc',
   'entry selector prefers ID');
is(grub2_entry_selector($entries[2]),
   'Advanced options for Ubuntu>Ubuntu, rescue mode',
   'entry selector falls back to menu path');
is_deeply([ grub2_kernel_options_source_keys(\@entries) ], [ 'defaults' ],
   'ordinary generated entries report defaults as kernel option source');
is(grub2_kernel_options_source_text(\@entries),
   $text{'index_kernel_options_source_defaults'},
   'ordinary generated entry source text is localized');
my %ambiguous_path_entry = (
    title => 'Leaf',
    path => [ 'Foo>Bar' ],
    index => 7,
);
is(grub2_entry_selector(\%ambiguous_path_entry), undef,
   'entry selector rejects path components containing greater-than signs');
ok(!grub2_entry_matches_selector(\%ambiguous_path_entry, 'Foo>Bar>Leaf'),
   'entry path selector with greater-than signs does not match');
ok(!grub2_entry_by_index(-1), 'negative boot entry index is rejected');
ok(!grub2_entry_by_index(99), 'out-of-range boot entry index is rejected');

{
    my $selection_defaults = parse_grub_defaults_text("GRUB_DEFAULT=saved\n",
                                                     $default_file);
    my %selection_env = (
        saved_entry => 'gnulinux-simple-abc',
        next_entry => '1',
    );
    my %roles = grub2_entry_selection_roles(\@entries, $selection_defaults,
                                            \%selection_env);
    is_deeply($roles{0}, [ 'saved' ], 'saved default entry is resolved');
    is_deeply($roles{1}, [ 'next' ], 'next boot entry is resolved');
}

{
    my $selection_defaults = parse_grub_defaults_text(
        "GRUB_DEFAULT=\"Advanced options for Ubuntu>Ubuntu, rescue mode\"\n",
        $default_file);
    my %roles = grub2_entry_selection_roles(\@entries, $selection_defaults, {});
    is_deeply($roles{2}, [ 'default' ], 'path default entry is resolved');
}

write_test_file($bls_entry_file, <<'EOF');
title Rocky Linux (5.14.0-570.12.1.el9_6.x86_64) 9.6
version 5.14.0-570.12.1.el9_6.x86_64
linux /vmlinuz-5.14.0-570.12.1.el9_6.x86_64
initrd /initramfs-5.14.0-570.12.1.el9_6.x86_64.img
options $kernelopts
machine-id 224f8b7897fe459aaefa3de1190e8600
EOF
write_test_file("$work/bls-grub.cfg", <<'EOF');
insmod blscfg
blscfg
menuentry 'UEFI Firmware Settings' --id 'uefi-firmware' {
    fwsetup
}
EOF
my @bls_entries = grub2_boot_entries("$work/bls-grub.cfg");
is(scalar(@bls_entries), 2, 'BLS and static entries are parsed together');
is($bls_entries[0]->{'title'},
   'Rocky Linux (5.14.0-570.12.1.el9_6.x86_64) 9.6',
   'BLS title is parsed');
is($bls_entries[0]->{'id'}, 'rocky-5.14.0',
   'BLS selector falls back to filename');
is($bls_entries[0]->{'version'}, '5.14.0-570.12.1.el9_6.x86_64',
   'BLS version is parsed');
is($bls_entries[0]->{'linux'}, '/vmlinuz-5.14.0-570.12.1.el9_6.x86_64',
   'BLS kernel path is parsed');
is($bls_entries[0]->{'initrd'},
   '/initramfs-5.14.0-570.12.1.el9_6.x86_64.img',
   'BLS initrd path is parsed');
is($bls_entries[0]->{'options'}, '$kernelopts',
   'BLS kernel options are parsed');
is($bls_entries[0]->{'machine-id'}, '224f8b7897fe459aaefa3de1190e8600',
   'BLS machine ID is parsed');
is_deeply([ grub2_kernel_options_source_keys(\@bls_entries) ],
          [ 'kernelopts' ],
          'BLS entries using kernelopts report grubenv as option source');
is(grub2_kernel_options_source_text(\@bls_entries),
   $text{'index_kernel_options_source_kernelopts'},
   'kernel option source text is localized');
my %kernelopts_env = ( kernelopts => 'root=/dev/sda1 quiet' );
is_deeply([ grub2_bls_kernel_option_warnings(\@bls_entries,
                                             \%kernelopts_env) ],
          [ $text{'index_warn_kernelopts_source'} ],
          'BLS kernelopts warning omits missing-env warning when value exists');
is_deeply([ grub2_bls_kernel_option_warnings(\@bls_entries, {}) ],
          [ $text{'index_warn_kernelopts_source'},
            $text{'index_warn_kernelopts_missing'} ],
          'BLS kernelopts warning reports missing grubenv kernelopts');
my @direct_bls_entries = (
    { source => 'bls', options => 'root=/dev/sda1 quiet',
      linux => '/vmlinuz-direct' },
);
is_deeply([ grub2_kernel_options_source_keys(\@direct_bls_entries) ],
          [ 'bls' ],
          'direct BLS options report BLS files as option source');
is_deeply([ grub2_bls_kernel_option_warnings(\@direct_bls_entries, {}) ],
          [ $text{'index_warn_bls_options'} ],
          'direct BLS options warn about BLS entry files');
ok(!grub2_bls_update_available(\@bls_entries),
   'BLS update is unavailable without grubby');
my ($remove_args, $add_args) =
    grub2_kernel_args_delta('quiet crashkernel=old rd.lvm.lv=rl/root',
                            'quiet crashkernel=new console=ttyS0');
is_deeply($remove_args, [ 'crashkernel=old', 'rd.lvm.lv=rl/root' ],
          'kernel arg delta removes deleted or changed arguments');
is_deeply($add_args, [ 'crashkernel=new', 'console=ttyS0' ],
          'kernel arg delta adds new or changed arguments');
is_deeply([ grub2_split_kernel_args('quiet "console=ttyS0,115200n8"') ],
          [ 'quiet', 'console=ttyS0,115200n8' ],
          'kernel args splitter handles quoted words');
ok(!grub2_defaults_updates_need_generate(
        { GRUB_CMDLINE_LINUX => 'quiet old=1' },
        { GRUB_CMDLINE_LINUX => 'quiet new=2' }, 1),
   'BLS-updated all-kernel args do not require regeneration');
ok(!grub2_defaults_updates_need_generate(
        { GRUB_CMDLINE_LINUX_DEFAULT => 'quiet old=1' },
        { GRUB_CMDLINE_LINUX_DEFAULT => 'quiet new=2' },
        { GRUB_CMDLINE_LINUX_DEFAULT => 1 }),
   'BLS-updated default-kernel args do not require regeneration');
ok(grub2_defaults_updates_need_generate(
        { GRUB_CMDLINE_LINUX_DEFAULT => 'quiet old=1' },
        { GRUB_CMDLINE_LINUX_DEFAULT => 'quiet new=2' }, {}),
   'default-kernel args still require regeneration without BLS update');
ok(grub2_defaults_updates_need_generate(
        { GRUB_CMDLINE_LINUX => 'quiet old=1' },
        { GRUB_CMDLINE_LINUX => 'quiet new=2' }, 0),
   'all-kernel args still require regeneration without BLS update');
ok(grub2_defaults_updates_need_generate(
        { GRUB_CMDLINE_LINUX => 'quiet old=1', GRUB_TIMEOUT => '5' },
        { GRUB_CMDLINE_LINUX => 'quiet new=2', GRUB_TIMEOUT => '10' }, 1),
   'non-BLS default changes still require regeneration');
ok(!grub2_defaults_updates_need_generate(
        { GRUB_TIMEOUT => '5' }, { GRUB_TIMEOUT => '5' }, 0),
   'unchanged defaults do not require regeneration');
my $grubby = "$work/grubby";
my $grubby_log = "$work/grubby.log";
make_script($grubby, <<EOF);
#!/bin/sh
printf '%s\\n' "\$@" > '$grubby_log'
EOF
{
    local $config{'grubby_cmd'} = $grubby;
    ok(grub2_bls_update_available(\@bls_entries),
       'BLS update is available with grubby');
    is_deeply([ grub2_bls_kernel_option_warnings(\@direct_bls_entries, {}) ],
              [],
              'direct BLS options do not warn when grubby is available');
    is(grub2_update_bls_kernel_args('quiet old=1 keep',
                                    'quiet new=2 keep'), undef,
       'BLS kernel args update succeeds');
    is(slurp_test_file($grubby_log),
       "--update-kernel=ALL\n--remove-args=old=1\n--args=new=2\n",
       'grubby receives the kernel arg delta');
    is_deeply([ grub2_bls_kernel_arg_targets(\@direct_bls_entries, 0) ],
              [ "$work/vmlinuz-direct" ],
              'BLS kernel arg targets resolve relative to boot directory');
    is(grub2_update_bls_kernel_args('quiet old=1',
                                    'quiet new=2',
                                    [ "$work/vmlinuz-direct" ]), undef,
       'BLS default kernel args update succeeds for selected targets');
    is(slurp_test_file($grubby_log),
       "--update-kernel=$work/vmlinuz-direct\n".
       "--remove-args=old=1\n--args=new=2\n",
       'grubby receives selected BLS kernel target');
}
is(join(' > ', @{$bls_entries[0]->{'path'}}), '',
   'top-level BLS entries do not use their source as submenu label');
is($bls_entries[1]->{'title'}, 'UEFI Firmware Settings',
   'static entries after blscfg keep their menu order');
write_test_file("$work/bls-submenu.cfg", <<'EOF');
submenu 'BLS submenu' {
    blscfg
}
EOF
my @submenu_bls_entries = grub2_boot_entries("$work/bls-submenu.cfg");
is(join(' > ', @{$submenu_bls_entries[0]->{'path'}}), 'BLS submenu',
   'BLS entries inherit the submenu containing blscfg');
ok(!grub2_has_bls_rescue_entries(\@bls_entries),
   'ordinary BLS entries are not treated as rescue entries');
ok(grub2_rpmvercmp('5.14.0-611.55.1.el9_7.aarch64',
                   '5.14.0-611.49.1.el9_7.aarch64') > 0,
   'rpm-style version comparison orders newer kernels higher');
ok(grub2_rpmvercmp('5.14.0-611.45.1.el9_7.aarch64',
                   '0-rescue-224f8b7897fe459aaefa3de1190e8600') > 0,
   'rpm-style version comparison places rescue entries after kernels');
{
    my $bls_order_dir = "$work/bls-order";
    mkdir $bls_order_dir or die "mkdir bls-order: $!";
    foreach my $ver (
        '0-rescue-224f8b7897fe459aaefa3de1190e8600',
        '5.14.0-611.45.1.el9_7.aarch64',
        '5.14.0-611.49.1.el9_7.aarch64',
        '5.14.0-611.55.1.el9_7.aarch64',
        ) {
        my $file = "$bls_order_dir/224f8b7897fe459aaefa3de1190e8600-$ver.conf";
        my $title = $ver =~ /^0-rescue/ ?
            "Rocky Linux ($ver) 9.4 (Blue Onyx)" :
            "Rocky Linux ($ver) 9.7 (Blue Onyx)";
        write_test_file($file, <<"EOF");
title $title
version $ver
linux /vmlinuz-$ver
EOF
        }
    local $config{'bls_dir'} = $bls_order_dir;
    my @ordered_bls = grub2_boot_entries("$work/bls-grub.cfg");
    is_deeply([ map { $_->{'title'} } @ordered_bls ],
              [
               'Rocky Linux (5.14.0-611.55.1.el9_7.aarch64) 9.7 (Blue Onyx)',
               'Rocky Linux (5.14.0-611.49.1.el9_7.aarch64) 9.7 (Blue Onyx)',
               'Rocky Linux (5.14.0-611.45.1.el9_7.aarch64) 9.7 (Blue Onyx)',
               'Rocky Linux (0-rescue-224f8b7897fe459aaefa3de1190e8600) 9.4 (Blue Onyx)',
               'UEFI Firmware Settings',
              ],
              'BLS entries follow GRUB newest-first order before static entries');
    is_deeply([ map { $_->{'index'} } @ordered_bls ], [ 0, 1, 2, 3, 4 ],
              'BLS entry indexes are assigned after sorting');
    ok(grub2_has_bls_rescue_entries(\@ordered_bls),
       'BLS rescue entries are detected separately from recovery entries');
    my $rescue_file = "$bls_order_dir/224f8b7897fe459aaefa3de1190e8600-0-rescue-224f8b7897fe459aaefa3de1190e8600.conf";
    my $disabled_rescue_file =
        $rescue_file.grub2_disabled_bls_rescue_suffix();
    is(grub2_set_bls_rescue_disabled(1, \@ordered_bls), undef,
       'BLS rescue entries can be disabled');
    ok(!-e $rescue_file, 'disabled BLS rescue entry is renamed away');
    ok(-e $disabled_rescue_file,
       'disabled BLS rescue entry is kept for restoration');
    is_deeply([ grub2_disabled_bls_rescue_files($bls_order_dir) ],
              [ $disabled_rescue_file ],
              'disabled BLS rescue entry is detected');
    ok(!grub2_has_bls_rescue_entries(
            [ grub2_bls_entries(0, $bls_order_dir) ]),
       'disabled BLS rescue entries are no longer parsed');
    ok(!grub2_defaults_updates_need_generate(
            { GRUB_DISABLE_RECOVERY => 'false' },
            { GRUB_DISABLE_RECOVERY => 'true' },
            { GRUB_DISABLE_RECOVERY => 1 }),
       'BLS-disabled rescue entries do not require menu regeneration');
    is(grub2_set_bls_rescue_disabled(0), undef,
       'BLS rescue entries can be restored');
    ok(-e $rescue_file, 'restored BLS rescue entry returns to conf file');
    ok(!-e $disabled_rescue_file,
       'restored BLS rescue entry removes disabled copy');
}

write_test_file($custom_file, <<'EOF');
menuentry 'Custom one' --id 'custom-one' { true }
menuentry 'Custom two' { true }
EOF
write_test_file("$work/custom-grub.cfg", <<"EOF");
### BEGIN $custom_file ###
menuentry 'Custom one' --id 'custom-one' { true }
menuentry 'Custom two' { true }
### END $custom_file ###
EOF
{
    local $config{'grub_cfg'} = "$work/custom-grub.cfg";
    my @custom_entries = grub2_boot_entries();
    is($custom_entries[0]->{'source_file'}, $custom_file,
       'custom generated entry keeps source file');
    is($custom_entries[0]->{'index'}, 0,
       'custom generated entry has a generated-menu index');
}

write_test_file($custom_file, <<'EOF');
#!/bin/sh
exec tail -n +3 $0

menuentry "Alpha" --id "alpha" {
	echo alpha
}
menuentry "Beta" --id "beta" {
	echo beta
}
EOF
my @custom_file_entries = grub2_custom_entries();
is(scalar(@custom_file_entries), 2, 'custom file entries are parsed');
is($custom_file_entries[0]->{'title'}, 'Alpha', 'custom entry title parsed');
is(grub2_custom_entry_body($custom_file_entries[0]), "echo alpha\n",
   'custom entry body is extracted without storage indentation');
is(grub2_format_custom_entry('Indented', 'indented',
			     "\techo indented\n\ttrue\n"),
   "menuentry \"Indented\" --id \"indented\" {\n".
   "\techo indented\n\ttrue\n}\n",
   'custom entry formatting avoids accumulating outer indentation');
is(grub2_save_custom_entry(undef, 'Gamma', 'gamma', "echo gamma\ntrue\n"),
   undef,
   'custom entry add succeeds');
like(slurp_test_file($custom_file), qr/menuentry "Gamma" --id "gamma"/,
     'custom entry add writes menuentry');
is(grub2_move_custom_entry(2, 'up'), undef, 'custom entry move succeeds');
my @moved_entries = grub2_custom_entries();
is($moved_entries[1]->{'title'}, 'Gamma', 'custom entry order changes');
is(grub2_save_custom_entry(0, 'Alpha edited', 'alpha-edited',
			   "echo edited\n"), undef,
   'custom entry edit succeeds');
like(slurp_test_file($custom_file), qr/Alpha edited/,
     'custom entry edit writes new title');
is(grub2_delete_custom_entry_indexes(1), undef,
   'custom entry indexed delete succeeds');
unlike(slurp_test_file($custom_file), qr/menuentry "Gamma"/,
       'custom indexed delete removes selected entry');
is(grub2_validate_custom_entry('Bad', '-bad', 'true'),
   $text{'custom_eid'}, 'custom entry rejects dash-leading ID');
is(grub2_validate_custom_entry("Bad\0", 'bad', 'true'),
   $text{'custom_etitle'}, 'custom entry rejects title null byte');
is(grub2_validate_custom_entry('Bad', "bad\0", 'true'),
   $text{'custom_eid'}, 'custom entry rejects ID null byte');
is(grub2_validate_custom_entry('Bad', 'bad', "}\n"),
   $text{'custom_ebraces'}, 'custom entry rejects unbalanced braces');

write_test_file($custom_file, <<'EOF');
submenu "Nested" {
	menuentry "Nested one" {
		true
	}
}
menuentry "Top one" {
	true
}
EOF
is(grub2_move_custom_entry(0, 'down'), $text{'custom_emove'},
   'custom move rejects submenu boundary changes');

{
    local $config{'grub_cfg'} = "$work/missing-grub.cfg";
    prefer_existing_file('grub_cfg', "$work/also-missing", $cfg_file);
    is($config{'grub_cfg'}, $cfg_file,
       'missing generic file is corrected to existing candidate');
}

write_test_file($env_file, "saved_entry=gnulinux-simple-abc\nnext_entry=1\n");
my %env = grub2_read_env();
is($env{'saved_entry'}, 'gnulinux-simple-abc', 'parsed saved entry from env');
is($env{'next_entry'}, '1', 'parsed next entry from env');

{
    local $config{'grub_cfg'} = "$work/bls-grub.cfg";
    my @warnings = grub2_status_warnings();
    ok(!grep { $_ eq $text{'index_warn_kernelopts_source'} } @warnings,
       'BLS kernel option source warning is not shown globally');
    ok(!grep { $_ eq $text{'index_warn_kernelopts_missing'} } @warnings,
       'missing grubenv kernelopts warning is not shown globally');
}

{
    local $config{'default_file'} = "$work/missing-defaults";
    my @warnings = grub2_status_warnings();
    ok(grep { $_ eq $text{'index_warn_missing_default'} } @warnings,
       'missing defaults file warning is shown');
}

{
    my $theme_console_defaults = "$work/theme-console-defaults";
    write_test_file($theme_console_defaults,
                    "GRUB_THEME=$theme_file\nGRUB_TERMINAL_OUTPUT=console\n");
    local $config{'default_file'} = $theme_console_defaults;
    my @warnings = grub2_status_warnings();
    ok(grep { $_ eq $text{'index_warn_theme_console'} } @warnings,
       'theme with console terminal output is warned about');
}

{
    my $bad_theme_defaults = "$work/bad-theme-defaults";
    write_test_file($bad_theme_defaults,
                    "GRUB_THEME=$work/Marathon-TitleScreen.tar.gz\n");
    local $config{'default_file'} = $bad_theme_defaults;
    my @warnings = grub2_status_warnings();
    ok(grep { /theme archive/ } @warnings,
       'theme archive saved as GRUB_THEME is warned about');
}

my $runtime_log = "$work/runtime.log";
my $runtime_cmd = "$work/grub-set-default";
make_script($runtime_cmd, "#!/bin/sh\nprintf '%s\\n' \"\$@\" > '$runtime_log'\n");
$config{'set_default_cmd'} = $runtime_cmd;
is(grub2_run_entry_command('set_default_cmd', $entries[0]), undef,
   'runtime command succeeds');
is(slurp_test_file($runtime_log), "gnulinux-simple-abc\n",
   'runtime command passes entry selector');
my %unsafe_entry = ( 'id' => '-bad', 'title' => 'bad', 'path' => [] );
is(grub2_run_entry_command('set_default_cmd', \%unsafe_entry),
   $text{'runtime_eselector'}, 'dash-leading selector is rejected');

my $install_cmd = "$work/grub-install";
my $install_log = "$work/install.log";
my $install_target = "/dev/null";
my $efi_dir = "$work/efi";
my $install_boot_dir = "$work/boot";
my $install_module_dir = "$work/grub-modules/x86_64-efi";
make_path($efi_dir);
make_path($install_boot_dir);
make_path($install_module_dir);
write_test_file("$install_module_dir/modinfo.sh", "# module info\n");
make_path("$efi_dir/EFI/rocky");
write_test_file("$efi_dir/EFI/rocky/grub.cfg", "# grub\n");
make_script($install_cmd, <<EOF);
#!/bin/sh
printf '%s\\n' "\$@" > '$install_log'
echo "installing boot loader"
EOF
$config{'install_cmd'} = $install_cmd;
is(grub2_default_bootloader_id($efi_dir), 'rocky',
   'boot loader ID is inferred from EFI vendor directory');
{
    local $config{'grub_cfg'} = '/boot/efi/EFI/almalinux/grub.cfg';
    is(grub2_default_bootloader_id($efi_dir), 'almalinux',
       'boot loader ID prefers configured GRUB EFI path');
}
is(grub2_validate_install_options({ target => $install_target }), undef,
   'boot loader install accepts an existing absolute target');
is(grub2_validate_install_options({ efi_dir => $efi_dir }), undef,
   'boot loader install accepts EFI-directory-only install');
is(grub2_validate_install_options({
        target => $install_target,
        platform => 'x86_64-efi',
        directory => $install_module_dir,
        boot_directory => $install_boot_dir,
    }), undef, 'boot loader install accepts platform and module directory');
like(grub2_validate_install_options({ target => 'relative-disk' }),
     qr/absolute|target/, 'boot loader install rejects relative target');
like(grub2_validate_install_options({
        target => "/dev/webmin-grub2-missing-$$",
     }),
     qr/does not exist/, 'boot loader install rejects missing target');
like(grub2_validate_install_options({
        target => $install_target,
        bootloader_id => '../bad',
     }), qr/boot loader ID/, 'boot loader install rejects unsafe ID');
like(grub2_validate_install_options({
        target => $install_target,
        platform => 'webmin-test',
     }), qr/platform files/, 'boot loader install reports missing modules');
like(grub2_validate_install_options({
        target => $install_target,
        directory => $efi_dir,
     }), qr/modinfo/, 'boot loader install rejects module dir without modinfo');
like(grub2_validate_install_options({
        target => $install_target,
        boot_directory => "$work/no-such-boot",
     }), qr/does not exist/, 'boot loader install rejects missing boot directory');
my @install_events;
is(grub2_install_bootloader({
        target => $install_target,
        efi_dir => $efi_dir,
        platform => 'x86_64-efi',
        directory => $install_module_dir,
        boot_directory => $install_boot_dir,
        bootloader_id => 'GRUB',
        recheck => 1,
        no_nvram => 1,
        force => 1,
    }, sub { push(@install_events, [ @_ ]); }), undef,
   'boot loader install succeeds with progress callback');
is(slurp_test_file($install_log),
   "--recheck\n--no-nvram\n--force\n--efi-directory=$efi_dir\n".
   "--target=x86_64-efi\n--directory=$install_module_dir\n".
   "--boot-directory=$install_boot_dir\n".
   "--bootloader-id=GRUB\n$install_target\n",
   'boot loader install passes expected command arguments');
ok((grep { $_->[0] eq 'command' &&
	    $_->[1] =~ /^\Q$install_cmd\E --recheck/ &&
	    $_->[1] !~ /\\/ } @install_events),
   'boot loader install reports readable command');
ok((grep { $_->[0] eq 'output' && $_->[1] =~ /installing boot loader/ }
    @install_events), 'boot loader install streams command output');
ok((grep { $_->[0] eq 'command_done' } @install_events),
   'boot loader install reports command completion');

my $mkconfig = "$work/grub-mkconfig";
make_script($mkconfig, <<'EOF');
#!/bin/sh
out=
while [ $# -gt 0 ]; do
    if [ "$1" = "-o" ]; then
        shift
        out=$1
    fi
    shift
done
echo "menuentry 'Generated' { true }" > "$out"
EOF
$config{'mkconfig_cmd'} = $mkconfig;
is(grub2_generate_config(), undef, 'mkconfig generation succeeds');
like(slurp_test_file($cfg_file), qr/menuentry 'Generated'/,
     'generated menu replaces target after test generation');
my $script_check = "$work/grub-script-check";
make_script($script_check, <<'EOF');
#!/bin/sh
data=`cat "$1"`
case "$data" in
    *Broken*) echo "syntax broken"; exit 1 ;;
esac
exit 0
EOF
my $mkconfig_broken = "$work/grub-mkconfig-broken";
make_script($mkconfig_broken, <<'EOF');
#!/bin/sh
out=
while [ $# -gt 0 ]; do
    if [ "$1" = "-o" ]; then
        shift
        out=$1
    fi
    shift
done
echo "menuentry 'Broken' { true }" > "$out"
EOF
{
    local $config{'script_check_cmd'} = $script_check;
    local $config{'mkconfig_cmd'} = $mkconfig_broken;
    my $before = slurp_test_file($cfg_file);
    like(grub2_generate_config(), qr/generated test menu failed validation.*syntax broken/is,
         'generated menu is validated before replacement');
    is(slurp_test_file($cfg_file), $before,
       'invalid generated menu does not replace target');
}
my $mkconfig_progress = "$work/grub-mkconfig-progress";
make_script($mkconfig_progress, <<'EOF');
#!/bin/sh
out=
while [ $# -gt 0 ]; do
    if [ "$1" = "-o" ]; then
        shift
        out=$1
    fi
    shift
done
echo "probing entries"
echo "writing menu"
echo "menuentry 'Generated with progress' { true }" > "$out"
EOF
$config{'mkconfig_cmd'} = $mkconfig_progress;
my @progress_events;
is(grub2_generate_config(sub { push(@progress_events, [ @_ ]); }), undef,
   'mkconfig generation with progress callback succeeds');
ok((grep { $_->[0] eq 'command' } @progress_events),
   'progress callback reports command');
ok((grep { $_->[0] eq 'command' &&
	    $_->[1] =~ /^\Q$mkconfig_progress\E -o / &&
	    $_->[1] !~ /\\/ } @progress_events),
   'progress callback reports readable command');
ok((grep { $_->[0] eq 'output' && $_->[1] =~ /probing entries/ }
    @progress_events), 'progress callback streams command output');
ok((grep { $_->[0] eq 'command_done' } @progress_events),
   'progress callback reports command completion');
ok((grep { $_->[0] eq 'check_done' } @progress_events),
   'progress callback reports test menu check completion');
ok((grep { $_->[0] eq 'replace' } @progress_events),
   'progress callback reports replacement');
ok((grep { $_->[0] eq 'replace_done' } @progress_events),
   'progress callback reports completion');
unlink($grub2_config_change_flag, $grub2_generate_time_flag);
is(grub2_action_links({ apply => 0 }, 'index.cgi'), '',
   'header apply link is hidden without apply ACL');
like(grub2_action_links({ apply => 1 }, 'index.cgi'), qr/Regenerate GRUB menu/,
     'header apply link is shown with apply ACL');
grub2_mark_regenerate_needed();
like(grub2_action_links({ apply => 1 }, 'index.cgi'),
     qr/<b[^>]*>Regenerate GRUB menu<\/b>/,
     'header apply link is bold when regeneration is pending');
local $ENV{'SCRIPT_NAME'} = '/grub2/status.cgi';
local $ENV{'QUERY_STRING'} = '';
like(grub2_action_links({ apply => 1 }),
     qr/redir=%2Fgrub2%2Fstatus%2Ecgi/,
     'header apply link defaults to current module URL');
grub2_mark_generated();

my @backup = grub2_config_files();
ok(grep { $_ eq $default_file } @backup, 'backup includes default file');
ok(grep { $_ eq $cfg_file } @backup, 'backup includes generated config');
ok(grep { $_ eq $config{'grub_dir'} } @backup, 'backup includes script dir');
ok(grep { $_ eq $password_file } @backup, 'backup includes password file');
ok(grep { $_ eq $color_file } @backup, 'backup includes color script');
ok(grep { $_ eq $theme_dir } @backup, 'backup includes theme directory');
ok(grep { $_ eq $background_dir } @backup,
   'backup includes background directory');
ok(grep { $_ eq $bls_dir } @backup, 'backup includes BLS entries dir');

do "$bindir/../log_parser.pl" or die "log_parser: $@ $!";
like(parse_webmin_log('root', 'save_defaults.cgi', 'defaults', undef, undef, {}),
     qr/Modified GRUB default/, 'log parser handles defaults');
like(parse_webmin_log('root', 'save_defaults.cgi', 'bls_args', undef,
                      undef, {}),
     qr/Updated existing BLS kernel options/,
     'log parser handles BLS kernel option updates');
like(parse_webmin_log('root', 'save_theme.cgi', 'theme', undef, undef, {}),
     qr/Modified GRUB theme/, 'log parser handles theme');
my $generate_log =
    parse_webmin_log('root', 'generate.cgi', 'generate', undef, $cfg_file, {});
like($generate_log, qr/Generated GRUB menu/, 'log parser handles generation');
like($generate_log, qr/<tt\b[^>]*>\Q$cfg_file\E<\/tt>/,
     'log parser renders values with tt tags');
unlike($generate_log, qr/<code>/,
       'log parser does not render values with code tags');
like(parse_webmin_log('root', 'install.cgi', 'install', undef,
                      $install_target, {}),
     qr/Installed GRUB boot loader/, 'log parser handles install');
like(parse_webmin_log('root', 'save_security.cgi', 'security', undef,
                      'enabled', {}),
     qr/Modified GRUB password protection/, 'log parser handles security');
like(parse_webmin_log('root', 'save_custom.cgi', 'custom_create', undef,
                      'Gamma', {}),
     qr/Created custom GRUB entry/, 'log parser handles custom create');
like(parse_webmin_log('root', 'custom_action.cgi', 'custom_delete', undef,
                      1, {}),
     qr/Deleted 1 custom GRUB menu entries/,
     'log parser handles custom delete');

do "$bindir/../install_check.pl" or die "install_check: $@ $!";
$config{'default_file'} = $default_file;
$config{'grub_cfg'} = $cfg_file;
$config{'mkconfig_cmd'} = $mkconfig;
is(is_installed(0), 1, 'install check detects module as installed');
is(is_installed(1), 2, 'install check detects module as configured');

done_testing();
