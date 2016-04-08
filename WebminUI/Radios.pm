package WebminUI::Radios;
use WebminUI::Input;
use WebminCore;
@ISA = ( "WebminUI::Input" );

=head2 new WebminUI::Radios(name, value, &options, [disabled])
Create a list of radio buttons, of which one may be selected
=cut
sub new
{
if (defined(&WebminUI::Theme::Radios::new)) {
        return new WebminUI::Theme::Radios(@_[1..$#_]);
        }
my ($self, $name, $value, $options, $disabled) = @_;
$self = { };
bless($self);
$self->set_name($name);
$self->set_value($value);
$self->set_options($options);
$self->set_disabled($disabled);
return $self;
}

=head2 add_option(name, [label])
=cut
sub add_option
{
my ($self, $name, $label) = @_;
push(@{$self->{'options'}}, [ $name, $label ]);
}

=head2 html()
Returns the HTML for all the radio buttons, one after the other
=cut
sub html
{
my ($self) = @_;
my $dis = $self->{'form'}->get_changefunc($self);
my $opts = $self->get_options();
if ($dis) {
	foreach my $o (@$opts) {
		$o->[2] = "onClick='$dis'";
		}
	}
return &ui_radio($self->get_name(), $self->get_value(),
		       $opts, $self->get_disabled());
}

=head2 one_html(number)
Returns the HTML for a single one of the radio buttons
=cut
sub one_html
{
my ($self, $num) = @_;
my $opt = $self->{'options'}->[$num];
my $dis = $self->{'form'}->get_changefunc($self);
return &ui_oneradio($self->get_name(), $opt->[0],
			  defined($opt->[1]) ? $opt->[1] : $opt->[0],
			  $self->get_value() eq $opt->[0],
			  $dis ? "onClick='$dis'" : undef,
			  $self->get_disabled());
}

sub set_options
{
my ($self, $options) = @_;
$self->{'options'} = $options;
}

sub get_options
{
my ($self) = @_;
return $self->{'options'};
}

1;

