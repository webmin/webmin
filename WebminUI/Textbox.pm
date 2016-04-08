package WebminUI::Textbox;
use WebminUI::Input;
use WebminCore;
@ISA = ( "WebminUI::Input" );

=head2 new WebminUI::Textbox(name, value, [size], [disabled])
Create a new text input field
=cut
sub new
{
if (defined(&WebminUI::Theme::Textbox::new)) {
        return new WebminUI::Theme::Textbox(@_[1..$#_]);
        }
my ($self, $name, $value, $size, $disabled) = @_;
$self = { 'size' => 30 };
bless($self);
$self->{'name'} = $name;
$self->{'value'} = $value;
$self->{'size'} = $size if ($size);
$self->set_disabled($disabled) if (defined($disabled));
return $self;
}

=head2 html()
Returns the HTML for this text input
=cut
sub html
{
my ($self) = @_;
return &ui_textbox($self->get_name(), $self->get_value(),
			 $self->{'size'},
			 $self->{'$disabled'});
}

sub set_size
{
my ($self, $size) = @_;
$self->{'size'} = $size;
}

sub set_validation_func
{
my ($self, $func) = @_;
$self->{'validation_func'} = $func;
}

=head2 set_validation_regexp(regexp, message)
=cut
sub set_validation_regexp
{
my ($self, $regexp, $message) = @_;
$self->{'validation_regexp'} = $regexp;
$self->{'validation_message'} = $message;
}

=head2 validate()
Returns a list of error messages for this field
=cut
sub validate
{
my ($self) = @_;
my $value = $self->get_value();
if ($self->{'mandatory'} && $value eq '') {
	return ( $self->{'mandmesg'} || $text{'ui_mandatory'} );
	}
if ($self->{'validation_func'}) {
	my $err = &{$self->{'validation_func'}}($value, $self->{'name'},
						$self->{'form'});
	return ( $err ) if ($err);
	}
if ($self->{'validation_regexp'}) {
	if ($value !~ /$self->{'validation_regexp'}/) {
		return ( $self->{'validation_message'} );
		}
	}
return ( );
}

1;

