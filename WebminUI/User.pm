package WebminUI::User;
use WebminUI::Textbox;
use WebminCore;
@ISA = ( "WebminUI::Textbox" );

=head2 new WebminUI::User(name, value, [multiple], [disabled])
A text box for entering or selecting one or many Unix usernames
=cut
sub new
{
if (defined(&WebminUI::Theme::User::new)) {
        return new WebminUI::Theme::User(@_[1..$#_]);
        }
my ($self, $name, $value, $multiple, $disabled) = @_;
$self = new WebminUI::Textbox($name, $value, $multiple ? 40 : 15, $disabled);
bless($self);
$self->set_multiple($multiple);
return $self;
}

=head2 html()
Returns the HTML for this user input
=cut
sub html
{
my ($self) = @_;
my $rv = WebminUI::Textbox::html($self);
my $name = $self->get_name();
my $multiple = $self->get_multiple();
local $w = $multiple ? 500 : 300;
$rv .= "&nbsp;<input type=button name=${name}_button onClick='ifield = form.$name; chooser = window.open(\"$gconfig{'webprefix'}/user_chooser.cgi?multi=$multiple&user=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=$w,height=200\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
return $rv;
}

sub set_multiple
{
my ($self, $multiple) = @_;
$self->{'multiple'} = $multiple;
}

sub get_multiple
{
my ($self) = @_;
return $self->{'multiple'};
}

=head2 get_input_names()
Returns the actual names of all HTML elements that make up this input
=cut
sub get_input_names
{
my ($self) = @_;
return ( $self->{'name'}, $self->{'name'}."_button" );
}

1;

