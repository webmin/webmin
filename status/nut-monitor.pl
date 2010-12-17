# Check if some NUT value is too low or high

sub get_nut_status
{
return { 'up' => -1 } if (!&has_command("upsc"));
local @sens = &get_ups_values($_[0]->{'ups'});
local ($sens) = grep { $_->{'name'} eq $_[0]->{'name'} } @sens;
return { 'up' => 1 } if (!$sens);
if ($_[0]->{'mode'} == 1) {
	return $sens->{'value'} < $_[0]->{'min'} ? { 'up' => 0 }
						 : { 'up' => 1 };
	}
elsif ($_[0]->{'mode'} == 2) {
	return $sens->{'value'} > $_[0]->{'max'} ? { 'up' => 0 }
						 : { 'up' => 1 };
	}
}

sub show_nut_dialog
{
if (!&has_command("upsc")) {
	print &ui_table_row(undef, $text{'nut_cmd'}, 4);
	}
else {
	# UPS name
	print &ui_table_row($text{'nut_ups'},
		&ui_textbox("ups", $_[0]->{'ups'}, 20));

	# Value to check
	local @sens = &get_ups_values();
	if (@sens) {
		print &ui_table_row($text{'nut_name'},
		    &ui_select("name", $_[0]->{'name'},
			[ map { [ $_->{'name'},
			    &text('nut_cur', $_->{'name'}, $_->{'value'}) ] }
			  @sens ]));
		}
	else {
		print &ui_table_row($text{'nut_name'},
		    &ui_textbox("name", $_[0]->{'name'}, 20));
		}

	# Expected value
	print &ui_table_row($text{'nut_value'},
	    &ui_radio("mode", $_[0]->{'mode'} || 1,
		[ [ 1, &text('sensors_value1',
			     &ui_textbox("min", $_[0]->{'min'}, 8)) ],
		  [ 2, &text('sensors_value2',
			     &ui_textbox("max", $_[0]->{'max'}, 8)) ] ]),
	    3);
	}
}

sub parse_nut_dialog
{
&has_command("upsc") || &error($text{'nut_cmd'});
$in{'ups'} =~ /^\S+$/ || &error($text{'nut_eups'});
$_[0]->{'ups'} = $in{'ups'};
$_[0]->{'name'} = $in{'name'};
$_[0]->{'mode'} = $in{'mode'};
$_[0]->{'max'} = $in{'max'};
$_[0]->{'min'} = $in{'min'};
if ($in{'mode'} == 1) {
	$in{'min'} =~ /^[0-9\.\+\-]+$/ || &error($text{'nut_emin'});
	}
elsif ($in{'mode'} == 2) {
	$in{'max'} =~ /^[0-9\.\+\-]+$/ || &error($text{'nut_emax'});
	}
}

# get_ups_values(ups)
# Returns a list of NUT attribute names and values for some UPS
sub get_ups_values
{
if (!scalar(@get_ups_cache)) {
	local @rv;
	open(SENS, "upsc ".quotemeta($_[0])." |");
	while(<SENS>) {
		if (/^(\S+):\s+(.*)/) {
			push(@rv, { 'name' => $1,
				    'value' => $2 });
			}
		}
	close(SENS);
	@get_ups_cache = @rv;
	}
return @get_ups_cache;
}

