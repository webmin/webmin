package WebminUI::Page;
use WebminCore;
use WebminCore;

=head2 new WebminUI::Page(subheading, title, [help-name], [show-config],
		      [no-module-index], [no-webmin-index], [rightside],
		      [header], [body-tags], [below-text])
Create a new page object, with the given heading and other details
=cut
sub new
{
if (defined(&WebminUI::Theme::Page::new) && caller() !~ /WebminUI::Theme::Page/) {
        return new WebminUI::Theme::Page(@_[1..$#_]);
        }
my ($self, $subheading, $title, $help, $config, $noindex, $nowebmin, $right,
    $header, $body, $below) = @_;
$self = { 'index' => 1, 'webmin' => 1, 'image' => "" };
bless($self);
$self->set_subheading($subheading);
$self->set_title($title);
$self->set_help($help);
$self->set_config($config);
$self->set_index(!$noindex);
$self->set_webmin(!$nowebmin);
$self->set_right($right);
$self->set_header($header);
$self->set_body($body);
$self->set_below($below);
return $self;
}

=head2 print()
Actually outputs this page
=cut
sub print
{
my ($self) = @_;
my $rv;

# Work out if we need buffering/table
foreach my $c (@{$self->{'contents'}}) {
	if (ref($c) =~ /Dynamic/) {
		$| = 1;
		if ($c->needs_unbuffered()) {
			$self->{'unbuffered'} = 1;
			}
		}
	}

# Show the page header
my $func = $self->{'unbuffered'} ? \&ui_print_unbuffered_header
				 : \&ui_print_header;
my $scripts;
foreach my $s (@{$self->{'scripts'}},
	       (map { @{$_->{'scripts'}} } @{$self->{'contents'}})) {
	$scripts .= "<script>\n".$s."\n</script>\n";
	}
my $onload;
my @onloads = ( @{$self->{'onloads'}},
		map { @{$_->{'onloads'}} } @{$self->{'contents'}} );
if (@onloads) {
	$onload = "onLoad='".join(" ", @onloads)."'";
	}
my @args =  ( $self->{'subheading'}, $self->{'title'}, $self->{'image'},
	      $self->{'help'}, $self->{'config'}, $self->{'index'} ? undef : 1,
	      $self->{'webmin'} ? undef : 1, $self->{'right'},
	      $self->{'header'}.$scripts, $self->{'body'}.$onload,
	      $self->{'below'} );
while(!defined($args[$#args])) {
	pop(@args);
	}
if ($self->get_refresh()) {
	print "Refresh: ",$self->get_refresh(),"\r\n";
	}
&ui_print_header(@args);

# Add the tab top
if ($self->{'tabs'}) {
	print $self->{'tabs'}->top_html();
	}

# Add any pre-content stuff
print $self->pre_content();

if ($self->{'errormsg'}) {
	# Show the error only
	print $self->get_errormsg_html();
	}
else {
	# Generate the forms and other stuff
	foreach my $c (@{$self->{'contents'}}) {
		if (!ref($c)) {
			# Just a message
			print "$c<p>\n";
			}
		else {
			# Convert to HTML
			eval { print $c->html(); };
			if ($@) {
				print "<pre>$@</pre>";
				}
			if (ref($c) =~ /Dynamic/ && $c->get_wait()) {
				# Dynamic object .. execute now
				$c->start();
				}
			}
		}

	# Generate buttons row
	if ($self->{'buttons'}) {
		print "<hr>\n";
		print &ui_buttons_start();
		foreach my $b (@{$self->{'buttons'}}) {
			print &ui_buttons_row(@$b);
			}
		print &ui_buttons_end();
		}
	}

# Add any post-content stuff
print $self->post_content();

# End of the tabs
if ($self->{'tabs'}) {
	print $self->{'tabs'}->bottom_html();
	}

# Print the footer
my @footerargs;
foreach my $f (@{$self->{'footers'}}) {
	push(@footerargs, $f->[0], $f->[1]);
	}
&ui_print_footer(@footerargs);

# Start any dynamic objects
foreach my $c (@{$self->{'contents'}}) {
	if (ref($c) =~ /Dynamic/ && !$c->get_wait()) {
		$c->start();
		}
	}
}

=head2 add_footer(link, title)
Adds a return link, typically for display at the end of the page.
=cut
sub add_footer
{
my ($self, $link, $title) = @_;
push(@{$self->{'footers'}}, [ $link, $title ]);
}

=head2 get_footer(index)
Returns the link for the numbered footer
=cut
sub get_footer
{
my ($self, $num) = @_;
return $self->{'footers'}->[$num]->[0];
}

=head2 add_message(text, ...)
Adds a text message, to appear at this point on the page
=cut
sub add_message
{
my ($self, @message) = @_;
push(@{$self->{'contents'}}, join("", @message));
}

=head2 add_error(text, [command-output])
Adds a an error message, possible accompanied by the command output
=cut
sub add_error
{
my ($self, $message, $out) = @_;
$message = "<font color=#ff0000>$message</font>";
if ($out) {
	$message .= "<pre>$out</pre>";
	}
push(@{$self->{'contents'}}, $message);
}

=head2 add_message_after(&object, text, ...)
Adds a message after some existing object
=cut
sub add_message_after
{
my ($self, $object, @message) = @_;
splice(@{$self->{'contents'}}, $self->position_of($object)+1, 0,
	join("", @message));
}

=head2 add_error_after(&object, text, [command-output])
Adds an error message after some existing object
=cut
sub add_error_after
{
my ($self, $object, $message, $out) = @_;
$message = "<font color=#ff0000>$message</font>";
if ($out) {
	$message .= "<pre>$out</pre>";
	}
splice(@{$self->{'contents'}}, $self->position_of($object)+1, 0,
       $message);
}

sub position_of
{
my ($self, $object) = @_;
for(my $i=0; $i<@{$self->{'contents'}}; $i++) {
	if ($self->{'contents'}->[$i] eq $object) {
		return $i;
		}
	}
print STDERR "Could not find $object in ",join(" ",@{$self->{'contents'}}),"\n";
return scalar(@{$self->{'contents'}});
}

=head2 add_form(WebminUI::Form)
Adds a form to be displayed on this page
=cut
sub add_form
{
my ($self, $form) = @_;
push(@{$self->{'contents'}}, $form);
$form->set_page($self);
}

=head2 add_separator()
Adds some kind of separation between parts of this page, like an <hr>
=cut
sub add_separator
{
my ($self, $message) = @_;
push(@{$self->{'contents'}}, "<hr>");
}

=head2 add_button(cgi, label, description, [&hiddens], [before-button],
		  [after-button])
Adds an action button associated with this page, typically for display at the end
=cut
sub add_button
{
my ($self, $cgi, $label, $desc, $hiddens, $before, $after) = @_;
push(@{$self->{'buttons'}}, [ $cgi, $label, $desc, join(" ", @$hiddens),
			      $before, $after ]);
}

=head2 add_tabs(WebminUI::Tags)
Tells the page to display the given set of tabs at the top
=cut
sub add_tabs
{
my ($self, $tabs) = @_;
$self->{'tabs'} = $tabs;
}

=head2 add_dynamic(WebminUI::DynamicText|WebminUI::DynamicProgress)
Adds an object that is dynamically generated, such as a text box or progress bar.
=cut
sub add_dynamic
{
my ($self, $dyn) = @_;
push(@{$self->{'contents'}}, $dyn);
$dyn->set_page($self);
}

sub set_subheading
{
my ($self, $subheading) = @_;
$self->{'subheading'} = $subheading;
}

sub set_title
{
my ($self, $title) = @_;
$self->{'title'} = $title;
}

sub set_help
{
my ($self, $help) = @_;
$self->{'help'} = $help;
}

sub set_config
{
my ($self, $config) = @_;
$self->{'config'} = $config;
}

sub set_index
{
my ($self, $index) = @_;
$self->{'index'} = $index;
}

sub set_webmin
{
my ($self, $webmin) = @_;
$self->{'webmin'} = $webmin;
}

sub set_right
{
my ($self, $right) = @_;
$self->{'right'} = $right;
}

sub set_header
{
my ($self, $header) = @_;
$self->{'header'} = $header;
}

sub set_body
{
my ($self, $body) = @_;
$self->{'body'} = $body;
}

sub set_below
{
my ($self, $below) = @_;
$self->{'below'} = $below;
}

sub set_unbuffered
{
my ($self, $unbuffered) = @_;
$self->{'unbuffered'} = $unbuffered;
}

=head2 set_popup(popup?)
If set to 1, then this is a popup window
=cut
sub set_popup
{
my ($self, $popup) = @_;
$self->{'popup'} = $popup;
}

=head2 get_myurl()
Returns the path part of the URL for this page, like /foo/bar.cgi
=cut
sub get_myurl
{
my @args;
if ($ENV{'QUERY_STRING'} && $ENV{'REQUEST_METHOD'} ne 'POST') {
	my %in;
	&ReadParse(\%in);
	foreach my $i (keys %in) {
		if ($i !~ /^ui_/) {
			foreach my $v (split(/\0/, $in{$i})) {
				push(@args, &urlize($i)."=".
					    &urlize($v));
				}
			}
		}
	}
return @args ? $ENV{'SCRIPT_NAME'}."?".join("&", @args)
	     : $ENV{'SCRIPT_NAME'};
}

=head2 set_refresh(seconds)
Sets the number of seconds between automatic page refreshes
=cut
sub set_refresh
{
my ($self, $refresh) = @_;
$self->{'refresh'} = $refresh;
}

sub get_refresh
{
my ($self) = @_;
return $self->{'refresh'};
}

=head2 add_onload(code)
Adds some Javascript code for inclusion in the onLoad tag
=cut
sub add_onload
{
my ($self, $code) = @_;
push(@{$self->{'onloads'}}, $code);
}

=head2 add_script(code)
Adds some Javascript code for putting in the <head> section
=cut
sub add_script
{
my ($self, $script) = @_;
push(@{$self->{'scripts'}}, $script);
}

sub pre_content
{
my ($self) = @_;
return undef;
}

sub post_content
{
my ($self) = @_;
return undef;
}

=head2 set_errormsg(message)
Sets an error message to be displayed instead of the page contents
=cut
sub set_errormsg
{
my ($self, $errormsg) = @_;
$self->{'errormsg'} = $errormsg;
}

sub get_errormsg_html
{
my ($self) = @_;
return $self->{'errormsg'}."<p>\n";
}

1;

