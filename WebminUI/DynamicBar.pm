package WebminUI::DynamicBar;
use WebminCore;

=head2 new WebminUI::DynamicBar(&start-function, max)
A page element for displaying progress towards some goal, like the download of
a file.
=cut
sub new
{
my ($self, $func, $max) = @_;
$self = { 'func' => $func,
	  'name' => "dynamic".++$dynamic_count,
	  'width' => 80,
	  'max' => $max };
bless($self);
return $self;
}

=head2 set_message(text)
Sets the text describing what we are waiting for
=cut
sub set_message
{
my ($self, $message) = @_;
$self->{'message'} = $message;
}

sub get_message
{
my ($self) = @_;
return $self->{'message'};
}

=head2 html()
Returns the HTML for the text field
=cut
sub html
{
my ($self) = @_;
my $rv;
if ($self->get_message()) {
	$rv .= $self->get_message()."<p>\n";
	}
$rv .= "<form name=form_$self->{'name'}>";
$rv .= "<input name=bar_$self->{'name'} size=$self->{'width'} disabled=true style='font-family: courier'>";
$rv .= "&nbsp;";
$rv .= "<input name=pc_$self->{'name'} size=3 disabled=true style='font-family: courier'>%";
$rv .= "</form>";
return $rv;
}

=head2 start()
Called by the page to begin the progress
=cut
sub start
{
my ($self) = @_;
&{$self->{'func'}}($self);
}

=head2 update(pos)
Called by the function to update the position of the bar.
=cut
sub update
{
my ($self, $pos) = @_;
my $pc = int(100*$pos/$self->{'max'});
if ($pc != $self->{'lastpc'}) {
	my $xn = int($self->{'width'}*$pos/$self->{'max'});
	my $xes = "X" x $xn;
	print "<script>window.document.forms[\"form_$self->{'name'}\"].pc_$self->{'name'}.value = \"$pc\";</script>\n";
	print "<script>window.document.forms[\"form_$self->{'name'}\"].bar_$self->{'name'}.value = \"$xes\";</script>\n";
	$self->{'lastpc'} = $pc;
	}
}

=head2 set_wait(wait)
If called with a non-zero arg, generation of the page should wait until this
the progress is complete. Otherwise, the page will be generated completely before
the start function is called
=cut
sub set_wait
{
my ($self, $wait) = @_;
$self->{'wait'} = $wait;
}

sub get_wait
{
my ($self) = @_;
return $self->{'wait'};
}

=head2 set_page(WebminUI::Page)
Called when this dynamic text box is added to a page
=cut
sub set_page
{
my ($self, $page) = @_;
$self->{'page'} = $page;
}

sub set_width
{
my ($self, $width) = @_;
$self->{'width'} = $width;
}

=head2 needs_unbuffered()
Must return 1 if the page needs to be in un-buffered and no-table mode
=cut
sub needs_unbuffered
{
return 0;
}


1;

