package WebminUI::Button;
use WebminUI::Input;
use WebminCore;
@ISA = ( "WebminUI::Input" );

=head2 new WebminUI::Button(cgi, label, [name])
Creates a button that when clicked will link to some other page
=cut
sub new
{
if (defined(&WebminUI::Theme::Button::new) &&
    caller() !~ /WebminUI::Theme::Button/) {
        return new WebminUI::Theme::Button(@_[1..$#_]);
        }
my ($self, $cgi, $value, $name) = @_;
$self = { };
bless($self);
$self->set_cgi($cgi);
$self->set_value($value);
$self->set_name($name) if ($name);
return $self;
}

=head2 html()
Returns HTML for this button
=cut
sub html
{
my ($self) = @_;
my $rv = "<form action=".$self->get_cgi().">";
foreach my $h (@{$self->{'hiddens'}}) {
	$rv .= &ui_hidden($h->[0], $h->[1])."\n";
	}
$rv .= &ui_submit($self->get_value(), $self->get_name(),
			$self->get_disabled())."</form>";
return $rv;
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

=head2 add_hidden(name, value)
Adds some hidden input to this button, for passing to the CGI
=cut
sub add_hidden
{
my ($self, $name, $value) = @_;
push(@{$self->{'hiddens'}}, [ $name, $value ]);
}

1;

