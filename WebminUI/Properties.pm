package WebminUI::Properties;
use WebminCore;

=head2 new WebminUI::Properties([heading], [columns], [width])
Creates a read-only properties list
=cut
sub new
{
if (defined(&WebminUI::Theme::Properties::new) &&
    caller() !~ /WebminUI::Theme::Properties/) {
        return new WebminUI::Theme::Properties(@_[1..$#_]);
        }
my ($self, $heading, $columns, $width) = @_;
$self = { 'columns' => 2 };
bless($self);
$self->set_heading($heading) if (defined($heading));
$self->set_columns($columns) if (defined($columns));
$self->set_width($width) if (defined($width));
return $self;
}

=head2 add_row(label, value, ...)
Adds one row to the properties table
=cut
sub add_row
{
my ($self, @row) = @_;
push(@{$self->{'rows'}}, \@row);
}

=head2 set_heading_row(head1, head2, ...)
Adds a row of headings
=cut
sub set_heading_row
{
my ($self, @row) = @_;
$self->{'heading_row'} = \@row;
}

=head2 html()
Returns the HTML for this properties list
=cut
sub html
{
my ($self) = @_;
my $rv;
my $width = $self->get_width();
$rv .= "<table border ".($width ? "width=$width" : "").">\n";
$rv .= "<tr><td><table width=100% cellspacing=0 cellpadding=3>\n";
my $cols = $self->get_columns();
if ($self->get_heading()) {
	$rv .= "<tr $tb><td colspan=$cols><b>".
	       $self->get_heading()."</b></td> </tr>\n";
	}
if ($self->{'heading_row'}) {
	$rv .= "<tr $tb>\n";
	foreach my $r (@{$self->{'heading_row'}}) {
		$rv .= "<td><b>$r</b></td>\n";
		}
	$rv .= "</tr>\n";
	}
foreach my $r (@{$self->{'rows'}}) {
	$rv .= "<tr $cb>\n";
	$rv .= "<td><b>$r->[0]</b></td>\n";
	for(my $i=1; $i<@$r || $i<$cols; $i++) {
		$rv .= "<td>".(ref($r->[$i]) ? $r->[$i]->html()
					    : $r->[$i])."</td>\n";
		}
	$rv .= "</tr>\n";
	}
$rv .= "</table></td></tr></table>\n";
return $rv;
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

sub get_width
{
my ($self) = @_;
return $self->{'width'};
}

=head2 set_columns(number)
Sets the number of columns in the properties table, including the title column
=cut
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

=head2 set_heading(number)
Sets the heading to appear above the properties list
=cut
sub set_heading
{
my ($self, $heading) = @_;
$self->{'heading'} = $heading;
}

sub get_heading
{
my ($self) = @_;
return $self->{'heading'};
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

