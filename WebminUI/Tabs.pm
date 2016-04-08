package WebminUI::Tabs;
use WebminCore;

=head2 new WebminUI::Tabs([&tabs])
Displayed at the top of a page, to allow selection of various pages
=cut
sub new
{
my ($self, $tabs) = @_;
if (defined(&WebminUI::Theme::Tabs::new)) {
        return new WebminUI::Theme::Tabs(@_[1..$#_]);
        }
$self = { 'tabs' => [ ],
	  'tab' => 0 };
bless($self);
$self->set_tabs($tabs) if (defined($tabs));
return $self;
}

=head2 add_tab(name, link)
=cut
sub add_tab
{
my ($self, $name, $link) = @_;
push(@{$self->{'tabs'}}, [ $name, $link ]);
}

=head2 html()
Returns the HTML for the top of the page
=cut
sub top_html
{
my ($self) = @_;
my $rv;
$rv .= "<table border=0 cellpadding=0 cellspacing=0 width=100% height=20><tr>";
$rv .= "<td valign=bottom>";
$rv .= "<table border=0 cellpadding=0 cellspacing=0 height=20><tr>";
my $i = 0;
my ($high, $low) = ("#cccccc", "#9999ff");
my ($lowlc, $lowrc) = ( "/images/lc1.gif", "/images/rc1.gif" );
my ($highlc, $highrc) = ( "/images/lc2.gif", "/images/rc2.gif" );
foreach my $t (@{$self->get_tabs()}) {
	if ($i == $self->get_tab()) {
		# This is the selected tab
		$rv .= "<td valign=top bgcolor=$high>".
		       "<img src=$highlc alt=\"\"></td>";
		if ($self->get_link()) {
			# Link
			$rv .= "<td bgcolor=$high>&nbsp;".
			       "<a href=$t->[1]><b>$t->[0]</b></a>&nbsp;</td>";
			}
		else {
			# Don't link
			$rv .= "<td bgcolor=$high>&nbsp;<b>$t->[0]</b>&nbsp;</td>";
			}
		$rv .= "<td valign=top bgcolor=$high>".
		       "<img src=$highrc alt=\"\"></td>\n";
		}
	else {
		# Not selected
	    	$rv .= "<td valign=top bgcolor=$low>".
	    	       "<img src=$lowlc alt=\"\"></td>";
	    	$rv .= "<td bgcolor=$low>&nbsp;".
		       "<a href=$t->[1]><b>$t->[0]</b></a>&nbsp;</td>";
	    	$rv .= "<td valign=top bgcolor=$low>".
		       "<img src=$lowrc alt=\"\"></td>\n";
		}
	$i++;
	if ($self->{'wrap'} && $i%$self->{'wrap'} == 0) {
		# New row
		$rv .= "</tr><tr>";
		}
	}
$rv .= "</tr></table></td>\n";
$rv .= "</tr></table>\n";
$rv .= "<table border=1 cellpadding=10 cellspacing=0 width=100%><tr><td>\n";
return $rv;
}

=head2 bottom_html()
Returns the HTML for the bottom of the page
=cut
sub bottom_html
{
my ($self) = @_;
my $rv = "</td></tr></table>\n";
return $rv;
}

=head2 set_tab(number|link)
Sets the tab that is currently highlighted
=cut
sub set_tab
{
my ($self, $tab) = @_;
if ($tab =~ /^\d+$/) {
	$self->{'tab'} = $tab;
	}
else {
	for(my $i=0; $i<@{$self->{'tabs'}}; $i++) {
		if ($self->{'tabs'}->[$i]->[1] eq $tab) {
			$self->{'tab'} = $i;
			}
		}
	}
}

sub get_tab
{
my ($self) = @_;
return $self->{'tab'};
}

=head2 set_link(link)
If called with a non-zero parameter, even the highlighted tab will be a link
=cut
sub set_link
{
my ($self, $link) = @_;
$self->{'link'} = $link;
}

sub get_link
{
my ($self) = @_;
return $self->{'link'};
}

sub set_tabs
{
my ($self, $tabs) = @_;
$self->{'tabs'} = $tabs;
}

sub get_tabs
{
my ($self) = @_;
return $self->{'tabs'};
}

1;

