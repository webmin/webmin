package WebminUI::Columns;
use WebminCore;

=head2 new WebminUI::Columns(cols)
Displays some page elements in a multi-column table
=cut
sub new
{
my ($self, $cols) = @_;
if (defined(&WebminUI::Theme::Columns::new)) {
        return new WebminUI::Theme::Columns(@_[1..$#_]);
        }
$self = { 'columns' => 2 };
bless($self);
$self->set_columns($cols) if (defined($cols));
return $self;
}

=head2 html()
Returns HTML for the objects, arranged in columns
=cut
sub html
{
my ($self) = @_;
my $rv;
my $n = scalar(@{$self->{'contents'}});
$rv .= "<table width=100% cellpadding=4><tr>\n";
my $h = int($n / $self->{'columns'})+1;
my $i = 0;
my $pc = int(100/$self->{'columns'});
foreach my $c (@{$self->{'contents'}}) {
	if ($i%$h == 0) {
		$rv .= "<td valign=top width=$pc%>";
		}
	$rv .= $c->html()."<p>\n";
	$i++;
	if ($i%$h == 0) {
		$rv .= "</td>\n";
		}
	}
$rv .= "</tr></table>\n";
return $rv;
}

=head2 add(object)
Adds some WebminUI:: object to this list
=cut
sub add
{
my ($self, $object) = @_;
push(@{$self->{'contents'}}, $object);
if ($self->{'page'}) {
	$object->set_page($self->{'page'});
	}
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

=head2 set_page(WebminUI::Page)
Called when this menu is added to a page
=cut
sub set_page
{
my ($self, $page) = @_;
$self->{'page'} = $page;
foreach my $c (@{$self->{'contents'}}) {
	$c->set_page($page);
	}
}

1;

