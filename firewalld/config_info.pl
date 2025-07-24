require './firewalld-lib.pl';

# show_timeout_data(value, config-option-name)
# Returns a radio button and a select box for timeout values
sub show_timeout_data
{
my ($value, $name) = @_;
$name = &format_option_name($name);
my $radio = &ui_radio(
	"${name}_def", !$value ? 1 : 0,
	[ [ 1, $text{'config_timeout_none'} ],
	  [ 0, ' ' ] ] );
my @list = &get_timeouts();
my @opts = map { [ $_, $text{"config_timeout_$_"} ] } @list;
my $select = &ui_select($name, !$value ? $list[3] : $value, \@opts);
return $radio . '&nbsp;' . $select;
}

# parse_timeout_data(old-value, config-option-name)
# Parses the timeout value from the form input
sub parse_timeout_data
{
my ($oldval, $name) = @_;
$name = &format_option_name($name);
my $val = $in{$name} // ''; 
return 0 if ($in{"${name}_def"});
my %valid = map { $_ => 1 } &get_timeouts();
&error(&text('config_timeout_err', $val)) unless($valid{$val});
return $val;
}

# get_timeouts
# Returns a list of valid timeout values for the select box
sub get_timeouts
{
return qw(1m 5m 15m 30m 1h 3h 6h 12h 1d 3d 7d 30d);
}

# format_option_name(name)
# Formats the option name for use in HTML element names
sub format_option_name
{
my ($name) = @_;
$name =~ s/\s+/_/g;
$name =~ s/[^\x00-\x7F]/_/g;
$name = lc($name);
return $name;
}
