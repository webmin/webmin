package WebminUI::PlainText;
use WebminCore;

=head2 new WebminUI::PlainText(text, columns)
Displays a block of plain fixed-width text, within a page or form.
=cut
sub new
{
if (defined(&WebminUI::Theme::PlainText::new) &&
    caller() !~ /WebminUI::Theme::PlainText/) {
        return new WebminUI::Theme::PlainText(@_[1..$#_]);
        }
my ($self, $text, $columns) = @_;
$self = { 'columns' => 80 };
bless($self);
$self->set_text($text);
$self->set_columns($columns) if (defined($columns));
return $self;
}

=head2 html()
=cut
sub html
{
my ($self) = @_;
my $rv;
$rv .= "<table border><tr $cb><td><pre>";
foreach my $l (&wrap_lines($self->get_text(), $self->get_columns())) {
	if (length($l) < $self->get_columns()) {
		$l .= (" " x $self->get_columns() - length($l));
		}
	$rv .= &html_escape($l)."\n";
	}
if (!$self->get_text()) {
	print (" " x $self->get_columns()),"\n";
	}
$rv .= "</pre></td></tr></table>\n";
return $rv;
}

sub set_text
{
my ($self, $text) = @_;
$self->{'text'} = $text;
}

sub get_text
{
my ($self) = @_;
return $self->{'text'};
}

sub set_columns
{
my ($self, $columns) = @_;
$self->{'columns'} = $columns;
}

sub get_columns
{
my ($self) = @_;
return $self->{'columns'};
}

# wrap_lines(text, width)
# Given a multi-line string, return an array of lines wrapped to
# the given width
sub wrap_lines
{
local @rv;
local $w = $_[1];
foreach $rest (split(/\n/, $_[0])) {
	if ($rest =~ /\S/) {
		while($rest =~ /^(.{1,$w}\S*)\s*([\0-\377]*)$/) {
			push(@rv, $1);
			$rest = $2;
			}
		}
	else {
		# Empty line .. keep as it is
		push(@rv, $rest);
		}
	}
return @rv;
}

=head2 set_page(WebminUI::Page)
Called when this form is added to a page
=cut
sub set_page
{
my ($self, $page) = @_;
$self->{'page'} = $page;
}

1;

