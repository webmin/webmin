package WebminUI::Select;
use WebminUI::Input;
use WebminCore;
@ISA = ( "WebminUI::Input" );

=head2 new WebminUI::Select(name, value|&values, &options, [multiple-size],
			  [add-missing], [disabled])
Create a menu or multiple-selection field
=cut
sub new
{
if (defined(&WebminUI::Theme::Select::new)) {
        return new WebminUI::Theme::Select(@_[1..$#_]);
        }
my ($self, $name, $value, $options, $size, $missing, $disabled) = @_;
$self = { 'size' => 1 };
bless($self);
$self->set_name($name);
$self->set_value($value);
$self->set_options($options);
$self->set_size($size) if (defined($size));
$self->set_missing($missing);
$self->set_disabled($disabled);
return $self;
}

=head2 add_option(name, [label])
=cut
sub add_option
{
my ($self, $name, $label) = @_;
push(@{$self->{'options'}}, [ $name, $label ]);
}

=head2 html()
Returns the HTML for this menu or multi-select input
=cut
sub html
{
my ($self) = @_;
my $dis = $self->{'form'}->get_changefunc($self);
return &ui_select($self->get_name(), $self->get_value(),
			$self->get_options(), 
			$self->get_size() > 1 ? $self->get_size() : undef,
			$self->get_size() > 1 ? 1 : 0,
			undef,
			$self->get_disabled(),
			$dis ? "onChange='$dis'" : undef).
       ($self->get_size() > 1 ? 
	       &ui_hidden("ui_exists_".$self->get_name(), 1) : "");
}

=head2 get_value()
For a multi-select field, returns an array ref of all values. For a menu,
return just the one value.
=cut
sub get_value
{
my ($self) = @_;
my $in = $self->{'form'} ? $self->{'form'}->{'in'} : undef;
if ($in && (defined($in->{$self->{'name'}}) ||
	    defined($in->{"ui_exists_".$self->{'name'}}))) {
	if ($self->get_size() > 1) {
		return [ split(/\0/, $in->{$self->{'name'}}) ];
		}
	else {
		return $in->{$self->{'name'}};
		}
	}
elsif ($in && defined($in->{"ui_value_".$self->{'name'}})) {
	if ($self->get_size() > 1) {
		return [ split(/\0/, $in->{"ui_value_".$self->{'name'}}) ];
		}
	else {
		return $in->{"ui_value_".$self->{'name'}};
		}
	}
else {
	return $self->{'value'};
	}
}

sub set_options
{
my ($self, $options) = @_;
$self->{'options'} = $options;
}

sub set_size
{
my ($self, $size) = @_;
$self->{'size'} = $size;
}

sub set_missing
{
my ($self, $missing) = @_;
$self->{'missing'} = $missing;
}

sub get_options
{
my ($self) = @_;
return $self->{'options'};
}

sub get_size
{
my ($self) = @_;
return $self->{'size'};
}

sub get_missing
{
my ($self) = @_;
return $self->{'missing'};
}

=head2 validate()
Returns a list of error messages for this field
=cut
sub validate
{
my ($self) = @_;
if ($self->{'size'} > 1) {
	my $value = $self->get_value();
	if ($self->{'mandatory'} && !@$value) {
		return ( $self->{'mandatorymsg'} || $text{'ui_mandatory'} );
		}
	}
return ( );
}

1;

