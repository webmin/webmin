package WebminUI::InputTable;
use WebminUI::Table;
use WebminCore;
@ISA = ( "WebminUI::Table" );

=head2 new WebminUI::InputTable(&headings, [width], [name], [heading])
A table containing multiple rows of inputs, each of which is the same
=cut
sub new
{
if (defined(&WebminUI::Theme::InputTable::new) &&
    caller() !~ /WebminUI::Theme::InputTable/) {
        return new WebminUI::Theme::InputTable(@_[1..$#_]);
        }
my $self = defined(&WebminUI::Theme::Table::new) ? WebminUI::Theme::Table::new(@_)
					       : WebminUI::Table::new(@_);
bless($self);
$self->{'rowcount'} = 0;
return $self;
}

=head2 set_inputs(&inputs)
Sets the objects to be used for each row
=cut
sub set_inputs
{
my ($self, $classes) = @_;
$self->{'classes'} = $classes;
}

=head2 add_values(&values)
Adds a row of inputs, with the given values
=cut
sub add_values
{
my ($self, $values) = @_;
my @row;
for(my $i=0; $i<@$values; $i++) {
	my $cls = $self->{'classes'}->[$i];
	my $newin = { %$cls };
	bless($newin, ref($cls));
	$newin->set_value($values->[$i]);
	$newin->set_name($newin->get_name()."_".$self->{'rowcount'});
	$newin->set_form($self->{'form'}) if ($self->{'form'});
	push(@row, $newin);
	}
$self->add_row(\@row);
$self->{'rowcount'}++;
}

=head2 get_values(row)
Returns the values of the inputs in the given row
=cut
sub get_values
{
my ($self, $row) = @_;
my @rv;
foreach my $i (@{$self->{'rows'}->[$row]}) {
	if (ref($i) && $i->isa("WebminUI::Input")) {
		push(@rv, $i->get_value());
		}
	}
return @rv;
}

=head2 list_inputs()
=cut
sub list_inputs
{
my ($self) = @_;
my @rv = WebminUI::Table::list_inputs($self);
foreach my $r (@{$self->{'rows'}}) {
	foreach my $i (@$r) {
		if ($i && ref($i) && $i->isa("WebminUI::Input")) {
			push(@rv, $i);
			}
		}
	}
return @rv;
}

sub get_rowcount
{
my ($self) = @_;
return $self->{'rowcount'};
}

=head2 validate()
Validates all inputs, and returns a list of error messages
=cut
sub validate
{
my ($self) = @_;
my $seli = $self->{'selectinput'};
my @errs;
if ($seli) {
	push(@errs, map { [ $seli->get_name(), $_ ] } $seli->validate());
	}
foreach my $i (@{$self->{'inputs'}}) {
	foreach my $e ($i->validate()) {
		push(@errs, [ $i->get_name(), $e ]);
		}
	}
my $k = 1;
foreach my $r (@{$self->{'rows'}}) {
	my $j = 0;
	my $skip;
	if (defined($self->{'control'})) {
		if ($r->[$self->{'control'}]->get_value() eq "") {
			$skip = 1;
			}
		}
	foreach my $i (@$r) {
		if ($i && ref($i) && $i->isa("WebminUI::Input") && !$skip) {
			my $label = &text('ui_rowlabel', $k, $self->{'headings'}->[$j]);
			foreach my $e ($i->validate()) {
				push(@errs, [ $i->get_name(), $label." ".$e ]);
				}
			}
		$j++;
		}
	$k++;
	}
return @errs;
}

=head2 set_control(column)
Sets the column for which an empty value means no validation should be done
=cut
sub set_control
{
my ($self, $control) = @_;
$self->{'control'} = $control;
}

1;

