package WebminUI::OptTextbox;
use WebminUI::Textbox;
use WebminCore;
@ISA = ( "WebminUI::Textbox" );

=head2 new WebminUI::OptTextbox(name, value, size, [default-msg], [other-msg])
Create a text field whose value is optional.
=cut
sub new
{
if (defined(&WebminUI::Theme::OptTextbox::new)) {
        return new WebminUI::Theme::OptTextbox(@_[1..$#_]);
        }
my ($self, $name, $value, $size, $default, $other) = @_;
$self = new WebminUI::Textbox($name, $value, $size);
bless($self);
$self->set_default($default || $text{'default'});
$self->set_other($other) if ($other);
return $self;
}

=head2 html()
Returns the HTML for this optional text input
=cut
sub html
{
my ($self) = @_;
return &ui_opt_textbox($self->get_name(), $self->get_value(),
			     $self->{'size'}, $self->{'default'},
			     $self->{'other'});
}

=head2 validate(&inputs)
=cut
sub validate
{
my ($self, $in) = @_;
if (defined($self->get_value())) {
	if ($self->get_value() eq "") {
		return ( $text{'ui_nothing'} );
		}
	return WebminUI::Textbox::validate($self);
	}
return ( );
}

sub set_default
{
my ($self, $default) = @_;
$self->{'default'} = $default;
}

sub set_other
{
my ($self, $other) = @_;
$self->{'other'} = $other;
}

=head2 get_value()
Returns the specified initial value for this field, or the value set when the
form is re-displayed due to an error.
=cut
sub get_value
{
my ($self) = @_;
my $in = $self->{'form'} ? $self->{'form'}->{'in'} : undef;
if ($in && (defined($in->{$self->{'name'}}) ||
	    defined($in->{$self->{'name'}.'_def'}))) {
	return $in->{$self->{'name'}.'_def'} ? undef : $in->{$self->{'name'}};
	}
elsif ($in && defined($in->{"ui_value_".$self->{'name'}})) {
	return $in->{"ui_value_".$self->{'name'}};
	}
else {
	return $self->{'value'};
	}
}

=head2 get_input_names()
Returns the actual names of all HTML elements that make up this input
=cut
sub get_input_names
{
my ($self) = @_;
return ( $self->{'name'}, $self->{'name'}."_def[0]",
			  $self->{'name'}."_def[1]" );
}

1;

