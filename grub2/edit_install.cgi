#!/usr/local/bin/perl
# Show a form for installing the GRUB 2 boot loader.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%text);

&ReadParse();
&error_setup($text{'install_err'});
&grub2_assert_acl('install');

my $cmd = &grub2_command('install_cmd');
my $platform = &grub2_default_platform_target();
my $module_dir = $platform ? &grub2_platform_module_dir($platform) : '';
my $efi_dir = &grub2_default_efi_directory();
my $bootloader_id = &grub2_default_bootloader_id($efi_dir);

&ui_print_header(undef, $text{'install_title'}, "", "install_target");

# Installation is unavailable unless the configured grub-install is runnable.
if (!$cmd) {
	print &ui_alert($text{'install_ecmd'}, 'warning');
	&ui_print_footer("index.cgi", $text{'index_return'});
	exit;
	}
if ($platform && !$module_dir) {
	# Missing module directories usually mean the platform package is absent.
	print &ui_alert(&text('install_warn_modules', $platform), 'warning');
	}

print &ui_form_start("install.cgi", "post");
print &ui_table_start($text{'install_header'}, "width=100%", 2);
print &ui_table_row($text{'install_command'},
		    &ui_tag('tt', &html_escape($cmd)));
print &ui_table_row($text{'index_boot_mode'}, &install_boot_mode_cell());
print &ui_table_row($text{'index_secure_boot'}, &install_secure_boot_cell());
print &ui_table_row(
	&hlink($text{'install_target'}, "install_target"),
	&ui_filebox("target", "", 45)
);
print &ui_table_row(
	&hlink($text{'install_efi_dir'}, "install_efi_dir"),
	&ui_filebox("efi_dir", $efi_dir, 45, 0, undef, undef, 1)
);
print &ui_table_row(
	&hlink($text{'install_platform'}, "install_platform"),
	&ui_textbox("platform", $platform, 25)
);
print &ui_table_row(
	&hlink($text{'install_directory'}, "install_directory"),
	&ui_filebox("directory", $module_dir, 45, 0, undef, undef, 1)
);
# Keep --boot-directory opt-in because it changes install layout.
print &ui_table_row(
	&hlink($text{'install_boot_directory'}, "install_boot_directory"),
	&ui_filebox("boot_directory", "/boot", 45, 0, undef, undef, 1).
	&ui_tag('div',
		&ui_checkbox("use_boot_directory", 1,
			     $text{'install_boot_directory_enable'}, 0),
		{ 'style' => 'margin-left: 2px' })
);
print &ui_table_row(
	&hlink($text{'install_bootloader_id'}, "install_bootloader_id"),
	&ui_textbox("bootloader_id", $bootloader_id, 30)
);
print &ui_table_hr();
print &ui_table_row(
	$text{'install_options'},
	&ui_div(&ui_checkbox("recheck", 1, $text{'install_recheck'}, 0)).
	&ui_div(&ui_checkbox("removable", 1, $text{'install_removable'}, 0)).
	&ui_div(&ui_checkbox("no_nvram", 1, $text{'install_no_nvram'}, 0)).
	&ui_div(&ui_checkbox("force", 1,
			     &hlink($text{'install_force'}, "install_force"),
			     0))
);
print &ui_table_hr();
print &ui_table_row(
	&hlink($text{'install_confirm'}, "install_confirm"),
	&ui_checkbox("confirm", 1, $text{'install_confirm_label'}, 0)
);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'install_submit'} ] ]);

&ui_print_footer("index.cgi", $text{'index_return'});

# install_boot_mode_cell()
# Returns the detected firmware boot mode for display.
sub install_boot_mode_cell
{
my $mode = &grub2_boot_mode();
return $text{'index_boot_mode_uefi'} if ($mode eq 'uefi');
return $text{'index_boot_mode_bios'};
}

# install_secure_boot_cell()
# Returns the detected Secure Boot state for display.
sub install_secure_boot_cell
{
my $state = &grub2_secure_boot_status();
return $text{'index_secure_boot_'.$state} || $text{'index_secure_boot_unknown'};
}
