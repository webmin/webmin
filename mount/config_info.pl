require './mount-lib.pl';

sub show_dashboard_mount_regex
{
my ($value) = @_;
return &ui_textbox('sysinfo_exclude_mount_regex', $value, 50);
}

sub parse_dashboard_mount_regex
{
my $value = $in{'sysinfo_exclude_mount_regex'} // '';
if (length($value) && !defined(&dashboard_mount_regex($value))) {
	&error($text{'config_edashboard_mount_regex'});
	}
return $value;
}

1;
