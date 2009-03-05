package Webmin::Checkbox;
use Webmin::Input;
use WebminCore;
@ISA = ( "Webmin::Input" );

=head2 new Webmin::Checkbox(name, return, label, checked, [disabled])
Create a single checkbox field
=cut
sub new
{
if (defined(&Webmin::Theme::Checkbox::new)) {
        return new Webmin::Theme::Checkbox(@_[1..$#_]);
        }
my ($self, $name, $return, $label, $checked, $disabled) = @_;
$self = { };
bless($self);
$self->set_name($name);
$self->set_return($return);
$self->set_label($label);
$self->set_value($checked);
$self->set_disabled($disabled);
return $self;
}

=head2 html()
Returns the HTML for this single checkbox
=cut
sub html
{
my ($self) = @_;
my $dis = $self->{'form'}->get_changefunc($self);
return &ui_checkbox($self->get_name(), $self->get_return(),
			  $self->get_label(), $self->get_value(),
			  $dis ? "onClick='$dis'" : undef,
			  $self->get_disabled()).
       &ui_hidden("ui_exists_".$self->get_name(), 1);
}

sub set_return
{
my ($self, $return) = @_;
$self->{'return'} = $return;
}

sub set_label
{
my ($self, $label) = @_;
$self->{'label'} = $label;
}

sub get_return
{
my ($self) = @_;
return $self->{'return'};
}

sub get_label
{
my ($self) = @_;
return $self->{'label'};
}

1;

