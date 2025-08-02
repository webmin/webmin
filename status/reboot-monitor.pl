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
	return { 'up' => 1,
		 'desc' => $text{'reboot_no'} };
	}
}

sub parse_reboot_dialog
{
return undef;
}

sub get_reboot_upmsg
{
my ($up) = @_;
return $up == 0 ? $text{'yes'} :
       $up == 1 ? $text{'no'} : undef;
}

1;

