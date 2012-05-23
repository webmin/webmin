# Check if some lm_sensors value is too high

sub get_sensors_status
{
return { 'up' => 1 } if (!&has_command("sensors"));
local @sens = &get_sensors_values();
local ($sens) = grep { $_->{'name'} eq $_[0]->{'name'} } @sens;
return { 'up' => 1 } if (!$sens);
if ($_[0]->{'mode'} == 0) {
	return $sens->{'alarm'} ? { 'up' => 0 } : { 'up' => 1 };
	}
else {
	local $up;
	if ($_[0]->{'mode'} == 1) {
		$up = $sens->{'value'} < $_[0]->{'min'} ? 0 : 1;
		}
	elsif ($_[0]->{'mode'} == 2) {
		$up = $sens->{'value'} > $_[0]->{'max'} ? 0 : 1;
		}
	return { 'up' => $up,
		 'value' => $sens->{'value'} };
	}
}

sub show_sensors_dialog
{
if (!&has_command("sensors")) {
	print &ui_table_row(undef, $text{'sensors_cmd'}, 4);
	}
elsif (@sens = &get_sensors_values()) {
	print &ui_table_row($text{'sensors_name'},
	   &ui_select("name", $_[0]->{'name'},
		[ map { [ $_->{'name'}, &text('sensors_cur', $_->{'name'}, $_->{'value'}, $_->{'units'}) ] } @sens ]), 3);

	print &ui_table_row($text{'sensors_value'},
	  &ui_radio("mode", $_[0]->{'mode'} || 0,
		[ [ 0, $text{'sensors_value0'} ],
		  [ 1, &text('sensors_value1',
			     &ui_textbox("min", $_[0]->{'min'}, 8)) ],
		  [ 2, &text('sensors_value2',
			     &ui_textbox("max", $_[0]->{'max'}, 8)) ] ]), 3);
	}
else {
	print &ui_table_row(undef, $text{'sensors_none'}, 4);
	}
}

sub parse_sensors_dialog
{
&has_command("sensors") || &error($text{'sensors_cmd'});
local @sens = &get_sensors_values();
@sens || &error($text{'sensors_none'});
$_[0]->{'name'} = $in{'name'};
$_[0]->{'mode'} = $in{'mode'};
$_[0]->{'max'} = $in{'max'};
$_[0]->{'min'} = $in{'min'};
if ($in{'mode'} == 1) {
	$in{'min'} =~ /^[0-9\.\+\-]+$/ || &error($text{'sensors_emin'});
	}
elsif ($in{'mode'} == 2) {
	$in{'max'} =~ /^[0-9\.\+\-]+$/ || &error($text{'sensors_emax'});
	}
}

# get_sensors_values()
# Returns a list of lm_sensors names, values and maxes
sub get_sensors_values
{
if (!scalar(@get_sensors_cache)) {
	local @rv;
	open(SENS, "sensors 2>/dev/null |");
	while(<SENS>) {
		if (/^([^:]+):\s+([0-9\.\+\-]+)\s*(\S+)\s+\(min\s+=\s+([0-9\.\+\-]+)\s*(\S+),\s+max\s+=\s+([0-9\.\+\-]+)/) {
			# Value with min and max
			push(@rv, { 'name' => $1,
				    'value' => $2,
				    'units' => $3,
				    'min' => $4,
				    'max' => $6 });
			$rv[$#rv]->{'alarm'} = 1 if (/ALARM/);
			}
		elsif (/^([^:]+):\s+([0-9\.\+\-]+)\s*(\S+)\s+\(min\s+=\s+([0-9\.\+\-]+)\s*(\S+),\s+div\s+=\s+([0-9\.\+\-]+)/) {
			# Value with min and div
			push(@rv, { 'name' => $1,
				    'value' => $2,
				    'units' => $3,
				    'min' => $4,
				    'div' => $6 });
			$rv[$#rv]->{'alarm'} = 1 if (/ALARM/);
			}
		elsif (/^([^:]+):\s+([0-9\.\+\-]+)\s*(\S+)\s+\(min\s+=\s+([0-9\.\+\-]+)\s*(\S+)/) {
			# Value with min only
			push(@rv, { 'name' => $1,
				    'value' => $2,
				    'units' => $3,
				    'min' => $4 });
			$rv[$#rv]->{'alarm'} = 1 if (/ALARM/);
			}
		elsif (/^([^:]+):\s+([0-9\.\+\-]+)\s*(\S+)\s+\((limit|high)\s+=\s+([0-9\.\+\-]+)\s*(\S+)/) {
			# Value with max only
			push(@rv, { 'name' => $1,
				    'value' => $2,
				    'units' => $3,
				    'max' => $5 });
			$rv[$#rv]->{'alarm'} = 1 if (/ALARM/);
			}
		elsif (/^([^:]+):\s+([0-9\.\+\-]+)\s*(\S+)\s+\(low\s+=\s+([0-9\.\+\-]+)\s*(\S+)\s*,\s+high\s+=\s+([0-9\.\+\-]+)/) {
			# Value with low and high
			push(@rv, { 'name' => $1,
				    'value' => $2,
				    'units' => $3,
				    'min' => $4,
				    'max' => $6 });
			$rv[$#rv]->{'alarm'} = 1 if (/ALARM/);
			}
		}
	close(SENS);
	@get_sensors_cache = @rv;
	}
return @get_sensors_cache;
}

