package WebminUI::Submit;
use WebminUI::Input;
use WebminCore;
@ISA = ( "WebminUI::Input" );

=head2 new WebminUI::Submit(label, [name], [disabled])
Create a form submit button
=cut
sub new
{
if (defined(&WebminUI::Theme::Submit::new) &&
    caller() !~ /WebminUI::Theme::Submit/) {
        return new WebminUI::Theme::Submit(@_[1..$#_]);
        }
my ($self, $value, $name, $disabled) = @_;
$self = { };
bless($self);
$self->set_value($value);
$self->set_name($name) if ($name);
$self->set_disabled($disabled) if ($disabled);
return $self;
}

=head2 html()
Returns the HTML for this form submit button
=cut
sub html
{
my ($self) = @_;
return &ui_submit($self->get_value(), $self->get_name(),
			$self->get_disabled());
}

sub get_value
{
my ($self) = @_;
return $self->{'value'};
}

1;

