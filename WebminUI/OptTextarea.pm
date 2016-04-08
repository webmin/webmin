package WebminUI::OptTextarea;
use WebminUI::Textarea;
use WebminCore;
@ISA = ( "WebminUI::Textarea" );

=head2 new WebminUI::OptTextarea(name, value, rows, cols, [default-msg], [other-msg])
Create a text area whose value is optional.
=cut
sub new
{
if (defined(&WebminUI::Theme::OptTextarea::new)) {
        return new WebminUI::Theme::OptTextarea(@_[1..$#_]);
        }
my ($self, $name, $value, $rows, $cols, $default, $other) = @_;
$self = new WebminUI::Textarea($name, $value, $rows, $cols);
bless($self);
$self->set_default($default || $text{'default'});
$self->set_other($other) if ($other);
return $self;
}

=head2 html()
Returns the HTML for this optional text input
=cut
sub html
{
my ($self) = @_;
my $rv;
my $name = $self->get_name();
my $value = $self->get_value();
my $dis = $self->get_disabled();
my $rows = $self->get_rows();
my $columns = $self->get_cols();
my $dis1 = &js_disable_inputs([ $name ], [ ]);
my $dis2 = &js_disable_inputs([ ], [ $name ]);
my $opt1 = $self->get_default();
my $opt2 = $self->get_other();
$rv .= "<input type=radio name=\"".&quote_escape($name."_def")."\" ".
       "value=1 ".($value ne '' ? "" : "checked").
       ($dis ? " disabled=true" : "")." onClick='$dis1'> ".$opt1."\n";
$rv .= "<input type=radio name=\"".&quote_escape($name."_def")."\" ".
       "value=0 ".($value ne '' ? "checked" : "").
       ($dis ? " disabled=true" : "")." onClick='$dis2'> ".$opt2."<br>\n";
$rv .= "<textarea name=\"".&quote_escape($name)."\" ".
       ($value eq "" || $dis ? " disabled=true" : "").
       "rows=$rows columns=$columns>".&html_escape($value)."</textarea>\n";
return $rv;

}

=head2 validate(&inputs)
=cut
sub validate
{
my ($self, $in) = @_;
if (defined($self->get_value())) {
	if ($self->get_value() eq "") {
		return ( $text{'ui_nothing'} );
		}
	return WebminUI::Textbox::validate($self);
	}
return ( );
}

sub set_default
{
my ($self, $default) = @_;
$self->{'default'} = $default;
}

sub get_default
{
my ($self) = @_;
return $self->{'default'};
}

sub set_other
{
my ($self, $other) = @_;
$self->{'other'} = $other;
}

sub get_other
{
my ($self) = @_;
return $self->{'other'};
}

=head2 get_value()
Returns the specified initial value for this field, or the value set when the
form is re-displayed due to an error.
=cut
sub get_value
{
my ($self) = @_;
my $in = $self->{'form'} ? $self->{'form'}->{'in'} : undef;
if ($in && (defined($in->{$self->{'name'}}) ||
	    defined($in->{$self->{'name'}.'_def'}))) {
	return $in->{$self->{'name'}.'_def'} ? undef : $in->{$self->{'name'}};
	}
elsif ($in && defined($in->{"ui_value_".$self->{'name'}})) {
	return $in->{"ui_value_".$self->{'name'}};
	}
else {
	return $self->{'value'};
	}
}

=head2 get_input_names()
Returns the actual names of all HTML elements that make up this input
=cut
sub get_input_names
{
my ($self) = @_;
return ( $self->{'name'}, $self->{'name'}."_def[0]",
			  $self->{'name'}."_def[1]" );
}

1;

