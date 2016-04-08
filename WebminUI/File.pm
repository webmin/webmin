package WebminUI::File;
use WebminUI::Textbox;
use WebminCore;
@ISA = ( "WebminUI::Textbox" );

=head2 new WebminUI::File(name, value, size, [directory], [disabled])
A text box for selecting a file
=cut
sub new
{
if (defined(&WebminUI::Theme::File::new)) {
        return new WebminUI::Theme::File(@_[1..$#_]);
        }
my ($self, $name, $value, $size, $directory, $disabled) = @_;
$self = new WebminUI::Textbox($name, $value, $size, $disabled);
bless($self);
$self->set_directory($directory);
return $self;
}

=head2 html()
Returns the HTML for this file input
=cut
sub html
{
my ($self) = @_;
my $rv = WebminUI::Textbox::html($self);
my $name = $self->get_name();
my $directory = $self->get_directory();
my $add = 0;
my $chroot = $self->get_chroot();
$rv .= "<input type=button name=${name}_button onClick='ifield = form.$name; chooser = window.open(\"$gconfig{'webprefix'}/chooser.cgi?add=$add&type=$directory&chroot=$chroot&file=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbar=no,width=400,height=300\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
return $rv;
}

sub set_directory
{
my ($self, $directory) = @_;
$self->{'directory'} = $directory;
}

sub get_directory
{
my ($self) = @_;
return $self->{'directory'};
}

sub set_chroot
{
my ($self, $chroot) = @_;
$self->{'chroot'} = $chroot;
}

sub get_chroot
{
my ($self) = @_;
return $self->{'chroot'};
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

