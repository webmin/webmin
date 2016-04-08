package WebminUI::LinkTable;
use WebminUI::Table;
use WebminCore;

=head2 new WebminUI::LinkTable(heading, [columns], [width], [name])
Creates a new table that just displays links, like in the Users and Groups module
=cut
sub new
{
if (defined(&WebminUI::Theme::LinkTable::new) &&
    caller() !~ /WebminUI::Theme::LinkTable/) {
        return new WebminUI::Theme::LinkTable(@_[1..$#_]);
        }
my ($self, $heading, $columns, $width, $name) = @_;
$self = { 'sorter' => \&WebminUI::Table::default_sorter,
	  'columns' => 4,
	  'sortable' => 1 };
bless($self);
$self->set_heading($heading);
$self->set_name($name) if (defined($name));
$self->set_width($width) if (defined($width));
$self->set_columns($columns) if (defined($columns));
return $self;
}

=head2 add_entry(name, link)
Adds one item to appear in the table
=cut
sub add_entry
{
my ($self, $name, $link) = @_;
push(@{$self->{'entries'}}, [ $name, $link ]);
}

=head2 html()
Returns the HTML for this table.
=cut
sub html
{
my ($self) = @_;

# Prepare the selector
my @srows = @{$self->{'entries'}};
my %selmap;
if (defined($self->{'selectinput'})) {
	my $i = 0;
	foreach my $r (@srows) {
		$selmap{$r} = $self->{'selectinput'}->one_html($i);
		$i++;
		}
	}

# Sort the entries
my $sortdir = $self->get_sortdir();
if (defined($sortdir)) {
	my $func = $self->{'sorter'};
	@srows = sort { my $so = &$func($a->[0], $b->[0]);
			$sortdir ? -$so : $so } @srows;
	}

# Build the sorter
my $head;
my $thisurl = $self->{'form'}->{'page'}->get_myurl();
$thisurl .= $thisurl =~ /\?/ ? "&" : "?";
my $name = $self->get_name();
if ($self->get_sortable()) {
	$head = "<table cellpadding=0 cellspacing=0 width=100%><tr>";
	$head .= "<td><b>".$self->get_heading()."</b></td> <td align=right>";
	if (!defined($sortdir)) {
		# Not sorting .. show grey button
		$head .= "<a href='${thisurl}ui_sortdir_${name}=0'>".
			 "<img src=/images/nosort.gif border=0></a>";
		}
	else {
		# Sorting .. show button to switch mode
		my $notsort = !$sortdir;
		$head .= "<a href='${thisurl}ui_sortdir_${name}=$notsort'>".
			 "<img src=/images/sort.gif border=0></a>";
		}
	$head .= "</td></tr></table>";
	}
else {
	$head = $self->get_heading();
	}

# Find any errors
my $rv;
if ($self->{'selectinput'}) {
	# Get any errors for inputs
	my @errs = $self->{'form'}->field_errors(
			$self->{'selectinput'}->get_name());
	if (@errs) {
		foreach my $e (@errs) {
			$rv .= "<font color=#ff0000>$e</font><br>\n";
			}
		}
	}

# Create the actual table
$rv .= &ui_table_start($head,
			     defined($self->{'width'}) ? "width=$self->{'width'}"
						       : undef, 1);
$rv .= "<td colspan=2><table width=100%>";
my $i = 0;
my $cols = $self->get_columns();
my $pc = 100/$cols;
foreach my $r (@srows) {
	$rv .= "<tr>\n" if ($i%$cols == 0);
	$rv .= "<td width=$pc%>".$selmap{$r}."<a href='$r->[1]'>".
	       &html_escape($r->[0])."</a></td>\n";
	$rv .= "<tr>\n" if ($i%$cols == $cols-1);
	$i++;
	}
if ($i%$cols) {
	# Finish off row
	while($i++%$cols != $cols-1) {
		$rv .= "<td width=$pc%></td>\n";
		}
	$rv .= "</tr>\n";
	}
$rv .= "</table></td>";
$rv .= &ui_table_end();
return $rv;
}

=head2 set_heading(text)
Sets the heading text to appear above the table
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

sub set_name
{
my ($self, $name) = @_;
$self->{'name'} = $name;
}

=head2 get_name()
Returns the name for indentifying this table in HTML
=cut
sub get_name
{
my ($self) = @_;
if (defined($self->{'name'})) {
	return $self->{'name'};
	}
elsif ($self->{'form'}) {
	my $secs = $self->{'form'}->{'sections'};
	for(my $i=0; $i<@$secs; $i++) {
		return "table".$i if ($secs->[$i] eq $self);
		}
	}
return "table";
}

=head2 set_sorter(function)
Sets a function used for sorting fields. Will be called with two values to compare
=cut
sub set_sorter
{
my ($self, $func) = @_;
$self->{'sorter'} = $func;
}

=head2 default_sorter(value1, value2)
=cut
sub default_sorter
{
my ($value1, $value2, $col) = @_;
return lc($value1) cmp lc($value2);
}

=head2 set_sortable(sortable?)
Tells the table if sorting is allowed or not. By default, it is.
=cut
sub set_sortable
{
my ($self, $sortable) = @_;
$self->{'sortable'} = $sortable;
}

sub get_sortable
{
my ($self) = @_;
return $self->{'sortable'};
}

=head2 get_sortdir()
Returns the order to sort in (1 for descending)
=cut
sub get_sortdir
{
my ($self) = @_;
my $in = $self->{'form'} ? $self->{'form'}->{'in'} : undef;
my $name = $self->get_name();
if ($in && defined($in->{"ui_sortdir_".$name})) {
	return ( $in->{"ui_sortdir_".$name} );
	}
else {
	return ( $self->{'sortdir'} );
	}
}

=head2 set_sortdir(descending?)
Sets the default sort direction, unless overridden by the user.
=cut
sub set_sortcolumn
{
my ($self, $desc) = @_;
$self->{'sortdir'} = $desc;
}

=head2 set_width([number|number%])
Sets the width of this entire table. Can be called with 100%, 500 or undef to use
the minimum possible width.
=cut
sub set_width
{
my ($self, $width) = @_;
$self->{'width'} = $width;
}

=head2 set_columns(cols)
Sets the number of columns to display
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

=head2 set_form(form)
Called by the WebminUI::Form object when this table is added to it
=cut
sub set_form
{
my ($self, $form) = @_;
$self->{'form'} = $form;
if ($self->{'selectinput'}) {
	$self->{'selectinput'}->set_form($form);
	}
}

=head2 set_selector(input)
Takes a WebminUI::Checkboxes or WebminUI::Radios object, and uses it to add checkboxes
to all the entries
=cut
sub set_selector
{
my ($self, $input) = @_;
$self->{'selectinput'} = $input;
$input->set_form($form);
}

=head2 get_selector()
Returns the UI element used for selecting rows
=cut
sub get_selector
{
my ($self) = @_;
return $self->{'selectinput'};
}

=head2 validate()
Validates the selector input
=cut
sub validate
{
my ($self) = @_;
my $seli = $self->{'selectinput'};
if ($seli) {
	return map { [ $seli->get_name(), $_ ] } $seli->validate();
	}
return ( );
}

=head2 get_value(input-name)
Returns the value of the input with the given name.
=cut
sub get_value
{
my ($self, $name) = @_;
if ($self->{'selectinput'} && $self->{'selectinput'}->get_name() eq $name) {
	return $self->{'selectinput'}->get_value();
	}
return undef;
}

=head2 list_inputs()
Returns all inputs in all form sections
=cut
sub list_inputs
{
my ($self) = @_;
return $self->{'selectinput'} ? ( $self->{'selectinput'} ) : ( );
}

1;

