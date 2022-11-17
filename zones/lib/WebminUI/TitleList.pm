package WebminUI::TitleList;
use WebminCore;

=head2 new WebminUI::TitleList(title, &links, [alt-text])
Generates a title with a list of links under it
=cut
sub new
{
my ($self, $title, $links, $alt) = @_;
if (defined(&WebminUI::Theme::TitleList::new)) {
        return new WebminUI::Theme::TitleList(@_[1..$#_]);
        }
$self = { };
bless($self);
$self->set_title($title);
$self->set_links($links);
$self->set_alt($alt) if (defined($alt));
return $self;
}

=head2 html()
Returns the list
=cut
sub html
{
my ($self) = @_;
my $rv;
if (defined(&ui_subheading)) {
	$rv .= &ui_subheading($self->get_title());
	}
else {
	$rv .= "<h3>".$self->get_title()."</h3>\n";
	}
$rv .= "<hr>\n";
foreach my $l (@{$self->get_links()}) {
	if ($l->[1]) {
		$rv .= "<a href='$l->[1]'>$l->[0]</a><br>\n";
		}
	else {
		$rv .= $l->[0]."<br>\n";
		}
	}
return $rv;
}

sub set_title
{
my ($self, $title) = @_;
$self->{'title'} = $title;
}

sub get_title
{
my ($self) = @_;
return $self->{'title'};
}

sub set_links
{
my ($self, $links) = @_;
$self->{'links'} = $links;
}

sub get_links
{
my ($self) = @_;
return $self->{'links'};
}

sub set_alt
{
my ($self, $alt) = @_;
$self->{'alt'} = $alt;
}

sub get_alt
{
my ($self) = @_;
return $self->{'alt'};
}

=head2 add_link(name, link)
Adds a link to be displayed in the list
=cut
sub add_link
{
my ($self, $name, $link) = @_;
push(@{$self->{'links'}}, [ $name, $link ]);
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

