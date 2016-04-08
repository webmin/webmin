package WebminUI::DynamicWait;
use WebminCore;

=head2 new WebminUI::DynamicWait(&start-function, [&args])
A page element indicating that something is happening.
=cut
sub new
{
my ($self, $func, $args) = @_;
$self = { 'func' => $func,
	  'args' => $args,
	  'name' => "dynamic".++$dynamic_count,
	  'width' => 80,
	  'delay' => 20 };
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
Returns the HTML for the text field used to indicate progress
=cut
sub html
{
my ($self) = @_;
my $rv;
if ($self->get_message()) {
	$rv .= $self->get_message()."<p>\n";
	}
$rv .= "<form name=form_$self->{'name'}>";
$rv .= "<input name=$self->{'name'} size=$self->{'width'} disabled=true style='font-family: courier'>";
$rv .= "</form>";
return $rv;
}

=head2 start()
Called by the page to begin the progress. Also starts a process to update the
Javascript text box
=cut
sub start
{
my ($self) = @_;
$self->{'pid'} = fork();
if (!$self->{'pid'}) {
	my $pos = 0;
	while(1) {
		select(undef, undef, undef, $self->{'delay'}/1000.0);
		my $str = (" " x $pos) . ("x" x 10);
		print "<script>window.document.forms[\"form_$self->{'name'}\"].$self->{'name'}.value = \"$str\";</script>\n";
		$pos++;
		$pos = 0 if ($pos == $self->{'width'});
		}
	exit;
	}
&{$self->{'func'}}($self, @{$self->{'args'}});
}

=head2 stop()
Called back by the function when whatever we were waiting for is done
=cut
sub stop
{
my ($self) = @_;
if ($self->{'pid'}) {
	kill('TERM', $self->{'pid'});
	}
my $str = (" " x ($self->{'width'}/2 - 2)) . "DONE";
print "<script>window.document.forms[\"form_$self->{'name'}\"].$self->{'name'}.value = \"$str\";</script>\n";
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

