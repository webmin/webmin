# raid-monitor.pl
# Check if some RAID device is reporting errors

sub get_raid_status
{
return { 'up' => -1 } if (!&foreign_check("raid"));
&foreign_require("raid", "raid-lib.pl");
local $conf = &raid::get_raidtab();
local ($raid) = grep { $_->{'value'} eq $_[0]->{'device'} } @$conf;
if ($raid) {
	if (ref($raid->{'errors'})) {
		local ($bad) = grep { $_ eq "_" } @{$raid->{'errors'}};
		if ($bad) {
			return { 'up' => 0,
				 'desc' => $text{'raid_bad'} };
			}
		else {
			return { 'up' => 1 };
			}
		}
	elsif ($raid->{'resync'}) {
		return { 'up' => 0,
			 'desc' => $text{'raid_resync'} };
		}
	else {
		return { 'up' => 1 };
		}
	}
else {
	return { 'up' => -1,
		 'desc' => &text('raid_notfound', $_[0]->{'device'}) };
	}
}

sub show_raid_dialog
{
&foreign_require("raid", "raid-lib.pl");
local $conf = &raid::get_raidtab();
local @opts;
foreach my $c (@$conf) {
	local $lvl = &raid::find_value('raid-level', $c->{'members'});
	push(@opts, [ $c->{'value'},
		      $c->{'value'}." - ".
		      ($lvl eq 'linear' ? $raid::text{'linear'}
					: $raid::text{"raid$lvl"}) ]);
	}
local ($got) = grep { $_->[0] eq $_[0]->{'device'} } @opts;
if (!@opts) {
	print &ui_table_row($text{'raid_device'},
			    &ui_textbox("other", $_[0]->{'device'}, 10));
	}
else {
	push(@opts, [ "", $text{'raid_other'} ]);
	print &ui_table_row($text{'raid_device'},
		&ui_select("device", !$_[0]->{'device'} ? $opts[0]->[0] :
				     !$got ? "" : $_[0]->{'device'}, \@opts).
		" ".&ui_textbox("other", $got ? "" : $_[0]->{'device'}, 10));
	}
}

sub parse_raid_dialog
{
&depends_check($_[0], "raid");
$_[0]->{'device'} = $in{'device'} || $in{'other'};
$_[0]->{'device'} =~ /^\S+$/ || &error($text{'raid_edevice'});
}

