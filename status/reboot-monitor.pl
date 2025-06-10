# Check if a reboot is required

sub get_reboot_status
{
return { 'up' => -1 } if (!&foreign_check("package-updates"));
&foreign_require("package-updates");
if (&package_updates::check_reboot_required()) {
	return { 'up' => 0,
	         'desc' => $text{'reboot_pkgs'} };
	}
else {
	return { 'up' => 1 };
	}
}

sub parse_reboot_dialog
{
return undef;
}

1;

