package WebminUI::Upload;
use WebminUI::Input;
use WebminCore;
@ISA = ( "WebminUI::Input" );

=head2 new WebminUI::Upload(name, [size])
Create a new file upload field
=cut
sub new
{
if (defined(&WebminUI::Theme::Upload::new)) {
        return new WebminUI::Theme::Upload(@_[1..$#_]);
        }
my ($self, $name, $size) = @_;
$self = { 'size' => 30 };
bless($self);
$self->{'name'} = $name;
$self->{'size'} = $size if ($size);
return $self;
}

=head2 html()
Returns the HTML for this text input
=cut
sub html
{
my ($self) = @_;
return &ui_upload($self->get_name(), $self->{'size'},
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
						$self->{'in'});
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

