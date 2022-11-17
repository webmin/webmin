package WebminUI::Menu;
use WebminCore;

=head2 new WebminUI::Menu(&options, [columns])
Generates a menu of options, typically using icons.
=cut
sub new
{
my ($self, $options, $columns) = @_;
if (defined(&WebminUI::Theme::Menu::new)) {
        return new WebminUI::Theme::Menu(@_[1..$#_]);
        }
$self = { 'columns' => 4 };
bless($self);
$self->set_options($options);
$self->set_columns($columns) if (defined($columns));
return $self;
}

=head2 html()
Returns the HTML for the table
=cut
sub html
{
my ($self) = @_;
my (@links, @titles, @icons, @hrefs);
foreach my $o (@{$self->{'options'}}) {
	push(@links, $o->{'link'});
	if ($o->{'link2'}) {
		push(@titles, "$o->{'title'}</a> <a href='$o->{'link2'}'>$o->{'title2'}");
		}
	else {
		push(@titles, $o->{'title'});
		}
	push(@icons, $o->{'icon'});
	push(@hrefs, $o->{'href'});
	}
my $rv = &capture_function_output(\&icons_table,
		\@links, \@titles, \@icons, $self->get_columns(),
		\@hrefs);
return $rv;
}

=head2 add_option(&option)
=cut
sub add_option
{
my ($self, $option) = @_;
push(@{$self->{'options'}}, $option);
}

sub set_options
{
my ($self, $options) = @_;
$self->{'options'} = $options;
}

sub get_options
{
my ($self) = @_;
return $self->{'options'};
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
}

1;

