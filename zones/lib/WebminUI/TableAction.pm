package WebminUI::TableAction;
use WebminCore;

=head2 new WebminUI::TableAction(cgi, label, &args, disabled)
An object of this class can be added to a table or properties object to create
a link or action button of some kind.
=cut
sub new
{
if (defined(&WebminUI::Theme::TableAction::new) &&
    caller() !~ /WebminUI::Theme::TableAction/) {
        return new WebminUI::Theme::TableAction(@_[1..$#_]);
        }
my ($self, $cgi, $value, $args, $disabled) = @_;
$self = { };
bless($self);
$self->set_value($value);
$self->set_cgi($cgi);
$self->set_args($args) if (defined($args));
$self->set_disabled($disabled) if (defined($disabled));
return $self;
}

sub html
{
my ($self) = @_;
my $rv;
if ($self->get_disabled()) {
	$rv .= "<u><i>".$self->get_value()."</i></u>";
	}
else {
	my $link = $self->get_cgi();
	my $i = 0;
	foreach my $a (@{$self->get_args()}) {
		$link .= ($i++ ? "&" : "?");
		$link .= &urlize($a->[0])."=".&urlize($a->[1]);
		}
	$rv .= "<a href='$link'>".$self->get_value()."</a>";
	}
return $rv;
}

sub set_value
{
my ($self, $value) = @_;
$self->{'value'} = $value;
}

sub get_value
{
my ($self) = @_;
return $self->{'value'};
}

sub set_cgi
{
my ($self, $cgi) = @_;
$self->{'cgi'} = $cgi;
}

sub get_cgi
{
my ($self) = @_;
return $self->{'cgi'};
}

sub set_args
{
my ($self, $args) = @_;
$self->{'args'} = $args;
}

sub get_args
{
my ($self) = @_;
return $self->{'args'};
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

1;

