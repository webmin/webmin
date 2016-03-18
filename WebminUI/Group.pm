package Webmin::Group;
use Webmin::Textbox;
use WebminCore;
@ISA = ( "Webmin::Textbox" );

=head2 new Webmin::Group(name, value, [multiple], [disabled])
A text box for entering or selecting one or many Unix groupnames
=cut
sub new
{
if (defined(&Webmin::Theme::Group::new)) {
        return new Webmin::Theme::Group(@_[1..$#_]);
        }
my ($self, $name, $value, $multiple, $disabled) = @_;
$self = new Webmin::Textbox($name, $value, $multiple ? 40 : 15, $disabled);
bless($self);
$self->set_multiple($multiple);
return $self;
}

=head2 html()
Returns the HTML for this group input
=cut
sub html
{
my ($self) = @_;
my $rv = Webmin::Textbox::html($self);
my $name = $self->get_name();
my $multiple = $self->get_multiple();
local $w = $multiple ? 500 : 300;
$rv .= "&nbsp;<input type=button name=${name}_button onClick='ifield = form.$name; chooser = window.open(\"$gconfig{'webprefix'}/group_chooser.cgi?multi=$multiple&group=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=$w,height=200\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
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

