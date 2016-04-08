package WebminUI::Date;
use WebminUI::Input;
use Time::Local;
use WebminCore;
@ISA = ( "WebminUI::Input" );

=head2 new WebminUI::Date(name, time, [disabled])
Create a new field for selecting a date
=cut
sub new
{
if (defined(&WebminUI::Theme::Date::new)) {
        return new WebminUI::Theme::Date(@_[1..$#_]);
        }
my ($self, $name, $value, $disabled) = @_;
bless($self = { });
$self->set_name($name);
$self->set_value($value);
$self->set_disabled($disabled) if (defined($disabled));
return $self;
}

=head2 html()
Returns the HTML for the date chooser
=cut
sub html
{
my ($self) = @_;
my $rv;
my @tm = localtime($self->get_value());
my $name = $self->get_name();
$rv .= &ui_date_input($tm[3], $tm[4]+1, $tm[5]+1900,
			    "day_".$name, "month_".$name, "year_".$name,
			    $self->get_disabled())." ".
       &date_chooser_button("day_".$name, "month_".$name, "year_".$name);
return $rv;
}

=head2 get_value()
Returns the date as a Unix time number (for zero o'clock)
=cut
sub get_value
{
my ($self) = @_;
my $in = $self->{'form'} ? $self->{'form'}->{'in'} : undef;
if ($in && defined($in->{"day_".$self->{'name'}})) {
	my $rv = $self->to_time($in);
	return defined($rv) ? $rv : $self->{'value'};
	}
elsif ($in && defined($in->{"ui_value_".$self->{'name'}})) {
	return $in->{"ui_value_".$self->{'name'}};
	}
else {
	return $self->{'value'};
	}
}

sub to_time
{
my ($self, $in) = @_;
my $day = $in->{"day_".$self->{'name'}};
return undef if ($day !~ /^\d+$/);
my $month = $in->{"month_".$self->{'name'}}-1;
my $year = $in->{"year_".$self->{'name'}}-1900;
return undef if ($year !~ /^\d+$/);
my $rv = eval { timelocal(0, 0, 0, $day, $month, $year) };
return $@ ? undef : $rv;
}

sub set_validation_func
{
my ($self, $func) = @_;
$self->{'validation_func'} = $func;
}

=head2 validate()
Ensures that the date is valid
=cut
sub validate
{
my ($self) = @_;
my $tm = $self->to_time($self->{'form'}->{'in'});
if (!defined($tm)) {
	return ( $text{'ui_edate'} );
	}
if ($self->{'validation_func'}) {
	my $err = &{$self->{'validation_func'}}($self->get_value(),
					        $self->{'name'},
						$self->{'form'});
	return ( $err ) if ($err);
	}
return ( );
}

1;

