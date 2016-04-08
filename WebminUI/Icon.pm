package WebminUI::Icon;
use WebminCore;

=head2 WebminUI::Icon(type, [message])
This object generates an icon indicating some status. Possible types are :
ok - OK
critial - A serious problem
major - A relatively serious problem
minor - A small problem
Can be used inside tables and property lists
=cut
sub new
{
if (defined(&WebminUI::Theme::Icon::new) && caller() !~ /WebminUI::Theme::Icon/) {
        return new WebminUI::Theme::Icon(@_[1..$#_]);
        }
my ($self, $type, $message) = @_;
$self = { };
bless($self);
$self->set_type($type);
$self->set_message($message) if (defined($message));
return $self;
}

=head2 html()
Returns HTML for the icon
=cut
sub html
{
my ($self) = @_;
my $rv;
$rv .= "<img src=/images/".$self->get_type().".gif align=middle>";
if ($self->get_message()) {
	$rv .= "&nbsp;".$self->get_message();
	}
return $rv;
}

sub set_type
{
my ($self, $type) = @_;
$self->{'type'} = $type;
}

sub get_type
{
my ($self) = @_;
return $self->{'type'};
}

sub set_message
{
my ($self, $message) = @_;
$self->{'message'} = $message;
}

sub get_message
{
my ($self) = @_;
return $self->{'message'};
}

1;

