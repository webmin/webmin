package WebminUI::Section;
use WebminCore;

=head2 new WebminUI::Section(header, [columns], [title], [width])
Create a new form section, which has a header and contains some inputs
=cut
sub new
{
if (defined(&WebminUI::Theme::Section::new) &&
    caller() !~ /WebminUI::Theme::Section/) {
        return new WebminUI::Theme::Section(@_[1..$#_]);
        }
my ($self, $header, $columns, $title, $width) = @_;
$self = { 'columns' => 4 };
bless($self);
$self->set_header($header);
$self->set_columns($columns) if (defined($columns));
$self->set_title($title) if (defined($title));
$self->set_width($width) if (defined($width));
return $self;
}

=head2 html()
Returns the HTML for this form section
=cut
sub html
{
my ($self) = @_;
my $rv;
$rv .= &ui_table_start($self->{'header'},
		     $self->{'width'} ? "width=$self->{'width'}" : undef,
		     $self->{'columns'});
foreach my $i (@{$self->{'inputs'}}) {
	if (is_input($i->[1])) {
		my $errs;
		my @errs = $self->{'form'}->field_errors($i->[1]->get_name());
		if (@errs) {
			foreach my $e (@errs) {
				$errs .= "<br><font color=#ff0000>$e</font>\n";
				}
			}
		$rv .= &ui_table_row($i->[0], $i->[1]->html().$errs,
					   $i->[2]);
		}
	else {
		$rv .= &ui_table_row($i->[0],
			ref($i->[1]) ? $i->[1]->html() : $i->[1], $i->[2]);
		}
	}
$rv .= &ui_table_end();
return $rv;
}

=head2 add_input(label, input, [columns])
Adds some WebminUI::Input object to this form section
=cut
sub add_input
{
my ($self, $label, $input, $cols) = @_;
push(@{$self->{'inputs'}}, [ $label, $input, $cols ]);
$input->set_form($self->{'form'});
}

=head2 add_row(label, text, [columns])
Adds a non-editable row to this form section
=cut
sub add_row
{
my ($self, $label, $text, $cols) = @_;
push(@{$self->{'inputs'}}, [ $label, $text, $cols ]);
}

=head2 add_separator()
Adds some kind of separator at this point in the section
=cut
sub add_separator
{
my ($self) = @_;
push(@{$self->{'inputs'}}, [ undef, "<hr>", $self->{'columns'} ]);
}

sub set_header
{
my ($self, $header) = @_;
$self->{'header'} = $header;
}

sub set_columns
{
my ($self, $columns) = @_;
$self->{'columns'} = $columns;
}

sub set_title
{
my ($self, $title) = @_;
$self->{'title'} = $title;
}

=head2 set_width([number|number%])
Sets the width of this section. Can be called with 100%, 500, or undef to use
the minimum possible width.
=cut
sub set_width
{
my ($self, $width) = @_;
$self->{'width'} = $width;
}

=head2 validate()
Validates all form inputs, based on the given CGI input hash. Returns a list
of errors, each of which is field name, error message and field label.
=cut
sub validate
{
my ($self) = @_;
my @errs;
foreach my $i (@{$self->{'inputs'}}) {
	if (is_input($i->[1])) {
		foreach my $e ($i->[1]->validate()) {
			push(@errs, [ $i->[1]->get_name(), $e, $i->[0] ]);
			}
		}
	}
return @errs;
}

=head2 get_value(input-name)
Returns the value of the input with the given name.
=cut
sub get_value
{
my ($self, $name) = @_;
foreach my $i (@{$self->{'inputs'}}) {
	if (is_input($i->[1]) && $i->[1]->get_name() eq $name) {
		return $i->[1]->get_value();
		}
	}
return undef;
}

=head2 set_form(form)
Called by the WebminUI::Form object when this section is added to it
=cut
sub set_form
{
my ($self, $form) = @_;
$self->{'form'} = $form;
foreach my $i (@{$self->{'inputs'}}) {
	if (is_input($i->[1])) {
		$i->[1]->set_form($form);
		}
	}
}

sub list_inputs
{
my ($self) = @_;
return map { $_->[1] } grep { is_input($_->[1]) } @{$self->{'inputs'}};
}

=head2 is_input(object)
=cut
sub is_input
{
my ($object) = @_;
return ref($object) && ref($object) =~ /::/ &&
       $object->isa("WebminUI::Input");
}

1;

