# XXX should support non-Javascript mode?
package WebminUI::DynamicText;
use WebminCore;

=head2 new WebminUI::DynamicText(&start-function, &args)
A page element for displaying text that takes time to generate, such as from
a long-running script. Uses a non-editable text box, updated via Javascript.
The function will be called when it is time to start producing output, with this
object as a parameter. It must call the add_line function on the object for each
new line to be added.
=cut
sub new
{
my ($self, $func, $args) = @_;
$self = { 'func' => $func,
	  'args' => $args,
	  'name' => "dynamic".++$dynamic_count,
	  'rows' => 20,
	  'cols' => 80 };
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
Returns the HTML for the text box
=cut
sub html
{
my ($self) = @_;
my $rv;
if ($self->get_message()) {
	$rv .= $self->get_message()."<p>\n";
	}
$rv .= "<form name=form_$self->{'name'}>";
$rv .= "<textarea name=$self->{'name'} rows=$self->{'rows'} cols=$self->{'cols'} wrap=off disabled=true>";
$rv .= "</textarea>\n";
$rv .= "</form>";
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

=head2 add_line(line)
Called by the function to add a line of text to this output
=cut
sub add_line
{
my ($self, $line) = @_;
$line =~ s/\r|\n//g;
$line = &quote_escape($line);
print "<script>window.document.forms[\"form_$self->{'name'}\"].$self->{'name'}.value += \"$line\"+\"\\n\";</script>\n";
}

=head2 set_wait(wait)
If called with a non-zero arg, generation of the page should wait until this
text box is complete. Otherwise, the page will be generated completely before the
start function is called
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

sub set_rows
{
my ($self, $rows) = @_;
$self->{'rows'} = $rows;
}

sub set_cols
{
my ($self, $cols) = @_;
$self->{'cols'} = $cols;
}

=head2 needs_unbuffered()
Must return 1 if the page needs to be in un-buffered and no-table mode
=cut
sub needs_unbuffered
{
return 0;
}

1;

