# consume-monitor.pl
# Check the rate at which disk space is being consumed on some filesystem

sub get_consume_status
{
return { 'up' => -1 } if (!&foreign_check("mount", 1));
&foreign_require("mount", "mount-lib.pl");
local $m;
foreach $f (&mount::list_mounted()) {
	$m = $f if ($f->[0] eq $_[0]->{'fs'});
	}
local %consume;
&read_file("$module_config_directory/consume", \%consume);
if ($m) {
	local @sp = &mount::disk_space($m->[2], $m->[0]);
	local $now = time();
	local ($lastfree, $lasttime) = split(/\s+/, $consume{$_[0]->{'fs'}});
	local $rv = { 'up' => 1 };
	if ($lasttime) {
		# Compare with last time
		local $diff = ($lastfree - $sp[1]) / ($now - $lasttime);
		if ($diff > $_[0]->{'rate'}) {
			$rv = { 'up' => 0,
				'desc' => &text('consume_high',
						&nice_size($diff*1024)) };
			}
		$rv->{'value'} = $diff*1024;
		$rv->{'nice_value'} = &nice_size($diff*1024);
		}
	$consume{$_[0]->{'fs'}} = "$sp[1] $now";
	&write_file("$module_config_directory/consume", \%consume);
	return $rv;
	}
else {
	return { 'up' => -1,
		 'desc' => $text{'space_nofs'} };
	}
}

sub show_consume_dialog
{
&foreign_require("mount", "mount-lib.pl");
local @mounted = &mount::list_mounted();
local ($got) = grep { $_->[0] eq $_[0]->{'fs'} } @mounted;
print &ui_table_row($text{'space_fs'},
	&ui_select("fs", !$_[0]->{'fs'} ? $mounted[0]->[0] :
			 !$got ? "" : $_[0]->{'fs'},
		   [ (map { [ $_->[0] ] } @mounted),
		     [ "", $text{'space_other'} ] ])."\n".
	&ui_textbox("other", $got ? "" : $_[0]->{'fs'}, 30),
	3);

print &ui_table_row($text{'consume_rate'},
	&ui_bytesbox("rate", $_[0]->{'rate'}*1024));

}

sub parse_consume_dialog
{
&depends_check($_[0], "mount");
if ($in{'fs'}) {
	$_[0]->{'fs'} = $in{'fs'};
	}
else {
	$in{'other'} =~ /^\// || &error($text{'space_eother'});
	$_[0]->{'fs'} = $in{'other'};
	}
$in{'rate'} =~ /^[0-9\.]+$/ || &error($text{'consume_erate'});
$_[0]->{'rate'} = $in{'rate'}*$in{'rate_units'}/1024;
}

1;

