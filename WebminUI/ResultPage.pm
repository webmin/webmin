package Webmin::ResultPage;
use WebminCore;

=head2 new Webmin::ResultPage(subheading, title, message, [help-name])
Create a new page object for showing some success message.
=cut
sub new
{
if (defined(&Webmin::Theme::ResultPage::new) &&
    caller() !~ /Webmin::Theme::ResultPage/) {
	return new Webmin::Theme::ResultPage(@_[1..$#_]);
	}
my ($self, $subheading, $title, $message, $help) = @_;
$self = new Webmin::Page($subheading, $title, $help);
$self->add_message("<b>$message</b>");
return $self;
}

1;

