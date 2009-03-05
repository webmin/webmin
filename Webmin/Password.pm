package Webmin::Password;
@ISA = ( "Webmin::Textbox" );
use Webmin::Textbox;
use WebminCore;

=head2 new Webmin::Password(name, value, [size])
Create a new text input field, for a password
=cut
sub new
{
if (defined(&Webmin::Theme::Password::new)) {
	return new Webmin::Theme::Password(@_[1..$#_]);
	}
my ($self, $name, $value, $size) = @_;
$self = new Webmin::Textbox($name, $value, $size);
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



