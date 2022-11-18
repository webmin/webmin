package WebminUI::ResultPage;
use WebminCore;

=head2 new WebminUI::ResultPage(subheading, title, message, [help-name])
Create a new page object for showing some success message.
=cut
sub new
{
if (defined(&WebminUI::Theme::ResultPage::new) &&
    caller() !~ /WebminUI::Theme::ResultPage/) {
	return new WebminUI::Theme::ResultPage(@_[1..$#_]);
	}
my ($self, $subheading, $title, $message, $help) = @_;
$self = new WebminUI::Page($subheading, $title, $help);
$self->add_message("<b>$message</b>");
return $self;
}

1;

