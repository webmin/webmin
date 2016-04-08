package WebminUI::Textarea;
use WebminUI::Input;
use WebminCore;
@ISA = ( "WebminUI::Input" );

=head2 new WebminUI::Textarea(name, value, rows, cols, [wrap], [disabled])
Create a new text box, with the given size
=cut
sub new
{
if (defined(&WebminUI::Theme::Textarea::new)) {
        return new WebminUI::Theme::Textarea(@_[1..$#_]);
        }
my ($self, $name, $value, $rows, $cols, $wrap, $disabled) = @_;
$self = { };
bless($self);
$self->set_name($name);
$self->set_value($value);
$self->set_rows($rows);
$self->set_cols($cols);
$self->set_disabled($disabled);
return $self;
}

=head2 html()
Returns the HTML for this text area
=cut
sub html
{
my ($self) = @_;
return &ui_textarea($self->get_name(), $self->get_value(),
			  $self->get_rows(), $self->get_cols(),
			  $self->get_wrap(), $self->get_disabled());
}

sub set_rows
{
my ($self, $rows) = @_;
$self->{'rows'} = $rows;
}

sub get_rows
{
my ($self) = @_;
return $self->{'rows'};
}

sub set_cols
{
my ($self, $cols) = @_;
$self->{'cols'} = $cols;
}

sub get_cols
{
my ($self) = @_;
return $self->{'cols'};
}

sub set_wrap
{
my ($self, $wrap) = @_;
$self->{'wrap'} = $wrap;
}

sub get_wrap
{
my ($self) = @_;
return $self->{'wrap'};
}

sub set_validation_func
{
my ($self, $func) = @_;
$self->{'validation_func'} = $func;
}

=head2 set_validation_regexp(regexp, message)
=cut
sub set_validation_regexp
{
my ($self, $regexp, $message) = @_;
$self->{'validation_regexp'} = $regexp;
$self->{'validation_message'} = $message;
}

=head2 validate()
Returns a list of error messages for this field
=cut
sub validate
{
my ($self) = @_;
my $value = $self->get_value();
if ($self->{'mandatory'} && $value eq '') {
	return ( $self->{'mandmesg'} || $text{'ui_mandatory'} );
	}
if ($self->{'validation_func'}) {
	my $err = &{$self->{'validation_func'}}($value, $self->{'name'},
						$self->{'form'});
	return ( $err ) if ($err);
	}
if ($self->{'validation_regexp'}) {
	if ($value !~ /$self->{'validation_regexp'}/) {
		return ( $self->{'validation_message'} );
		}
	}
return ( );
}

=head2 get_value()
Returns the value, without any \r characters
=cut
sub get_value
{
my ($self) = @_;
my $rv = WebminUI::Input::get_value($self);
$rv =~ s/\r//g;
return $rv;
}

1;

