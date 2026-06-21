sub show_raid_devices
{
my ($value) = @_;
$value ||= "";
$value =~ s/\t/\n/g;
my $placeholder = &quote_escape("/dev/sg0 cciss 0 3");
return &ui_textarea("raid_devices", $value, 3, 60, undef, 0,
		    "placeholder=\"$placeholder\"");
}

sub parse_raid_devices
{
my $value = $in{'raid_devices'} || "";
$value =~ s/\r//g;
$value =~ s/\n/\t/g;
$value =~ s/\s+$//;
return $value;
}

1;
