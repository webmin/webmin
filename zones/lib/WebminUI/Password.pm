package WebminUI::Password;
@ISA = ( "WebminUI::Textbox" );
use WebminUI::Textbox;
use WebminCore;

=head2 new WebminUI::Password(name, value, [size])
Create a new text input field, for a password
=cut
sub new
{
if (defined(&WebminUI::Theme::Password::new)) {
	return new WebminUI::Theme::Password(@_[1..$#_]);
	}
my ($self, $name, $value, $size) = @_;
$self = new WebminUI::Textbox($name, $value, $size);
bless($self);
return $self;
}

=head2 html()
Returns the HTML for this password input
=cut
sub html
{
my ($self) = @_;
return &ui_password($self->get_name(), $self->get_value(),
			  $self->{'size'},
			  $self->{'$disabled'});
}



