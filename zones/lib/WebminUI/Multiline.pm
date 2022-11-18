package WebminUI::Multiline;
use WebminUI::Textarea;
use WebminCore;
@ISA = ( "WebminUI::Textarea" );

=head2 new WebminUI::Multiline(name, &lines, rows, cols, [disabled])
Create a new input for entering multiple text entries. By default, just uses
a textbox
=cut
sub new
{
if (defined(&WebminUI::Theme::Multiline::new)) {
        return new WebminUI::Theme::Multiline(@_[1..$#_]);
        }
my ($self, $name, $lines, $rows, $cols, $wrap, $disabled) = @_;
$self = new WebminUI::Textarea($name, join("\n", @$lines), $rows, $cols, undef, $disabled);
bless($self);
return $self;
}

=head2 set_lines(&lines)
Sets the lines to display
=cut
sub set_lines
{
my ($self, $lines) = @_;
$self->set_value(join("\n", @$lines));
}

=head2 get_lines()
Returns an array ref of lines to display
=cut
sub get_lines
{
my ($self) = @_;
return [ split(/[\r|\n]+/, $self->get_value()) ];
}

1;

