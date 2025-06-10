package WebminUI::Checkboxes;
use WebminUI::Input;
use WebminCore;
@ISA = ( "WebminUI::Input" );

=head2 new WebminUI::Checkboxes(name, value|&values, &options, [disabled])
Create a list of checkboxes, of which zero or more may be selected
=cut
sub new
{
if (defined(&WebminUI::Theme::Checkboxes::new)) {
        return new WebminUI::Theme::Checkboxes(@_[1..$#_]);
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
Returns the HTML for all the checkboxes, one after the other
=cut
sub html
{
my ($self) = @_;
my $rv;
for(my $i=0; $i<@{$self->{'options'}}; $i++) {
	$rv .= $self->one_html($i)."\n";
	}
return $rv;
}

=head2 one_html(number)
Returns the HTML for a single one of the checkboxes
=cut
sub one_html
{
my ($self, $num) = @_;
my $opt = $self->{'options'}->[$num];
my $value = $self->get_value();
my %sel = map { $_, 1 } (ref($value) ? @$value : ( $value ));
return &ui_checkbox($self->get_name(), $opt->[0],
			  defined($opt->[1]) ? $opt->[1] : $opt->[0],
			  $sel{$opt->[0]}, undef, $self->get_disabled()).
       ($num == 0 ? &ui_hidden("ui_exists_".$self->get_name(), 1) : "");
}

=head2 get_value()
Returns a hash ref of all selected values
=cut
sub get_value
{
my ($self) = @_;
my $in = $self->{'form'} ? $self->{'form'}->{'in'} : undef;
if ($in && (defined($in->{$self->{'name'}}) ||
	    defined($in->{"ui_exists_".$self->{'name'}}))) {
	return [ split(/\0/, $in->{$self->{'name'}}) ];
	}
elsif ($in && defined($in->{"ui_value_".$self->{'name'}})) {
	return [ split(/\0/, $in->{"ui_value_".$self->{'name'}}) ];
	}
else {
	return $self->{'value'};
	}
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

=head2 validate()
Returns a list of error messages for this field
=cut
sub validate
{
my ($self) = @_;
my $value = $self->get_value();
if ($self->{'mandatory'} && !@$value) {
	return ( $self->{'mandmesg'} || $text{'ui_checkmandatory'} );
	}
return ( );
}

=head2 get_input_names()
Returns the actual names of all HTML elements that make up this input
=cut
sub get_input_names
{
my ($self) = @_;
my @rv;
for(my $i=0; $i<@{$self->{'options'}}; $i++) {
	push(@rv, $self->{'name'}."[".$i."]");
	}
return @rv;
}

1;


