package WebminUI::Input;
use WebminCore;

sub set_form
{
my ($self, $form) = @_;
$self->{'form'} = $form;
}

sub set_name
{
my ($self, $name) = @_;
$self->{'name'} = $name;
}

sub get_name
{
my ($self) = @_;
return $self->{'name'};
}

sub set_disabled
{
my ($self, $disabled) = @_;
$self->{'disabled'} = $disabled;
}

sub get_disabled
{
my ($self) = @_;
return $self->{'disabled'};
}

=head2 validate()
No validation is done by default
=cut
sub validate
{
return ( );
}

sub set_value
{
my ($self, $value) = @_;
$self->{'value'} = $value;
}

=head2 get_value()
Returns the current value for this field as entered by the user, the value
set when the form is re-displayed due to an error, or the initial value.
=cut
sub get_value
{
my ($self) = @_;
my $in = $self->{'form'} ? $self->{'form'}->{'in'} : undef;
if ($in && (defined($in->{$self->{'name'}}) ||
	    defined($in->{"ui_exists_".$self->{'name'}}))) {
	return $in->{$self->{'name'}};
	}
elsif ($in && defined($in->{"ui_value_".$self->{'name'}})) {
	return $in->{"ui_value_".$self->{'name'}};
	}
else {
	return $self->{'value'};
	}
}

=head2 set_disable_code(javascript)
Must be provided with a Javascript expression that will return true when this
input should be disabled. May refer to other fields, via the variable 'form'.
ie. form.mode.value = "0"
Will be called every time any field's value changes.
=cut
sub set_disable_code
{
my ($self, $code) = @_;
$self->{'disablecode'} = $code;
}

sub get_disable_code
{
my ($self) = @_;
return $self->{'disablecode'};
}

=head2 get_input_names()
Returns the actual names of all HTML elements that make up this input
=cut
sub get_input_names
{
my ($self) = @_;
return ( $self->{'name'} );
}

=head2 set_label(text)
Sets HTML to be displayed before this field
=cut
sub set_label
{
my ($self, $label) = @_;
$self->{'label'} = $label;
}

sub get_label
{
my ($self) = @_;
return $self->{'label'};
}

sub set_mandatory
{
my ($self, $mandatory, $mandmesg) = @_;
$self->{'mandatory'} = $mandatory;
$self->{'mandmesg'} = $mandmesg if (defined($mandmesg));
}

sub get_mandatory
{
my ($self) = @_;
return $self->{'mandatory'};
}

=head2 get_errors()
Returns a list of errors associated with this field
=cut
sub get_errors
{
my ($self) = @_;
return $self->{'form'} ? $self->{'form'}->field_errors($self->get_name())
		       : ( );
}

1;

