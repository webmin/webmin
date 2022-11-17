package WebminUI::DynamicHTML;
use WebminCore;

=head2 new WebminUI::DynamicHTML(&function, &args, [before])
When the page is being rendered, executes the given function and prints any
text that it returns.
=cut
sub new
{
my ($self, $func, $args, $before) = @_;
$self = { 'func' => $func,
	  'args' => $args,
	  'before' => $before };
bless($self);
return $self;
}

=head2 set_before(text)
Sets the text describing what we are waiting for
=cut
sub set_before
{
my ($self, $before) = @_;
$self->{'before'} = $before;
}

sub get_before
{
my ($self) = @_;
return $self->{'before'};
}

sub html
{
my ($self) = @_;
my $rv;
if ($self->get_before()) {
	$rv .= $self->get_before()."<p>\n";
	}
return $rv;
}

=head2 start()
Called by the page to begin the dynamic output.
=cut
sub start
{
my ($self) = @_;
&{$self->{'func'}}($self, @$args);
}

sub get_wait
{
my ($self) = @_;
return 1;
}

=head2 needs_unbuffered()
Must return 1 if the page needs to be in un-buffered and no-table mode
=cut
sub needs_unbuffered
{
return 1;
}

=head2 set_page(WebminUI::Page)
Called when this dynamic HTML element is added to a page
=cut
sub set_page
{
my ($self, $page) = @_;
$self->{'page'} = $page;
}

1;

