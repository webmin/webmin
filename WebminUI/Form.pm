package WebminUI::Form;
use WebminCore;

=head2 new WebminUI::Form(cgi, [method])
Creates a new form, which submits to the given CGI
=cut
sub new
{
if (defined(&WebminUI::Theme::Form::new)) {
        return new WebminUI::Theme::Form(@_[1..$#_]);
        }
my ($self, $program, $method) = @_;
$self = { 'method' => 'get',
	  'name' => "form".++$form_count };
bless($self);
$self->set_program($program);
$self->set_method($method) if ($method);
return $self;
}

=head2 html()
Returns the HTML that makes up this form
=cut
sub html
{
my ($self) = @_;
my $rv;
if ($self->get_align()) {
	$rv .= "<div align=".$self->get_align().">\n";
	}
$rv .= $self->form_start();
if ($self->get_heading()) {
	if (defined(&ui_subheading)) {
		$rv .= &ui_subheading($self->get_heading());
		}
	else {
		$rv .= "<h3>".$self->get_heading()."</h3>\n";
		}
	}

# Add the sections
foreach my $h (@{$self->{'hiddens'}}) {
	$rv .= &ui_hidden($h->[0], $h->[1])."\n";
	}
foreach my $s (@{$self->{'sections'}}) {
	$rv .= $s->html();
	}

# Check if we have any inputs that need disabling
my @dis = $self->list_disable_inputs();
if (@dis) {
	# Yes .. generate a function for them
	$rv .= "<script>\n";
	$rv .= "function ui_disable_".$self->{'name'}."(form) {\n";
	foreach my $i (@dis) {
		foreach my $n ($i->get_input_names()) {
			$rv .= "    form.".$n.".disabled = (".
				      $i->get_disable_code().");\n";
			}
		}
	$rv .= "}\n";
	$rv .= "</script>\n";
	}

# Add the buttons at the end of the form
my @buttonargs;
foreach my $b (@{$self->{'buttons'}}) {
	if (ref($b)) {
		# An array of inputs
		my $ihtml = join(" ", map { $_->html() } @$b);
		push(@buttonargs, $ihtml);
		}
	else {
		# A spacer
		push(@buttonargs, "");
		}
	}
$rv .= &ui_form_end(\@buttonargs);

if ($self->get_align()) {
	$rv .= "</div>\n";
	}

# Call the Javascript disable function
if (@dis) {
	$rv .= "<script>\n";
	$rv .= "ui_disable_".$self->{'name'}."(window.document.forms[\"$self->{'name'}\"]);\n";
	$rv .= "</script>\n";
	}

return $rv;
}

sub form_start
{
my ($self) = @_;
return "<form action='$self->{'program'}' ".
		($self->{'method'} eq "post" ? "method=post" :
		 $self->{'method'} eq "form-data" ?
			"method=post enctype=multipart/form-data" :
			"method=get")." name=$self->{'name'}>\n";
}

=head2 add_section(section)
Adds a WebminUI::Section object to this form
=cut
sub add_section
{
my ($self, $section) = @_;
push(@{$self->{'sections'}}, $section);
$section->set_form($self);
}

=head2 get_section(idx)
=cut
sub get_section
{
my ($self, $idx) = @_;
return $self->{'sections'}->[$idx];
}

=head2 add_button(button, [beside, ...])
Adds a WebminUI::Submit object to this form, for display at the bottom
=cut
sub add_button
{
my ($self, $button, @beside) = @_;
push(@{$self->{'buttons'}}, [ $button, @beside ]);
}

=head2 add_button_spacer()
Adds a gap between buttons, for grouping
=cut
sub add_button_spacer
{
my ($self, $spacer) = @_;
push(@{$self->{'buttons'}}, $spacer);
}

=head2 add_hidden(name, value)
Adds some hidden input to this form, for passing to the CGI
=cut
sub add_hidden
{
my ($self, $name, $value) = @_;
push(@{$self->{'hiddens'}}, [ $name, $value ]);
}

=head2 validate()
Validates all form inputs, based on the current CGI input hash. Returns a list
of errors, each of which is field name and error message.
=cut
sub validate
{
my ($self) = @_;
my @errs;
foreach my $s (@{$self->{'sections'}}) {
	push(@errs, $s->validate($self->{'in'}));
	}
return @errs;
}

=head2 validate_redirect(page, [&extra-errors])
Validates the form, and if any errors are found re-directs to the given page
with the errors, so that they can be displayed.
=cut
sub validate_redirect
{
my ($self, $page, $extras) = @_;
if ($self->{'in'}->{'ui_redirecting'}) {
	# If this page is displayed as part of a redirect, no need to validate!
	return;
	}
my @errs = $self->validate();
push(@errs, @$extras);
if (@errs) {
	my (@errlist, @vallist);
	foreach my $e (@errs) {
		push(@errlist, &urlize("ui_error_".$e->[0])."=".
			       &urlize($e->[1]));
		}
	foreach my $i ($self->list_inputs()) {
		my $v = $i->get_value();
		my @vals = ref($v) ? @$v : ( $v );
		@vals = ( undef ) if (!@vals);
		foreach $v (@vals) {
			push(@vallist,
			    &urlize("ui_value_".$i->get_name())."=".
			    &urlize($v));
			}
		}
	foreach my $h (@{$self->{'hiddens'}}) {
		push(@vallist,
		    &urlize($h->[0])."=".&urlize($h->[1]));
		}
	if ($page =~ /\?/) { $page .= "&"; }
	else { $page .= "?"; }
	&redirect($page.join("&", "ui_redirecting=1", @errlist, @vallist));
	exit(0);
	}
}

=head2 validate_error(whatfailed)
Validates the form, and if any errors are found displays an error page.
=cut
sub validate_error
{
my ($self, $whatfailed) = @_;
my @errs = $self->validate();
&error_setup($whatfailed);
if (@errs == 1) {
	&error($errs[0]->[2] ? "$errs[0]->[2] : $errs[0]->[1]"
				   : $errs[0]->[1]);
	}
elsif (@errs > 1) {
	my $msg = $text{'ui_errors'}."<br>";
	foreach my $e (@errs) {
		$msg .= $e->[2] ? "$e->[2] : $e->[1]<br>\n"
				: "$e->[1]<br>\n";
		}
	&error($msg);
	}
}

=head2 field_errors(name)
Returns a list of error messages associated with the field of some name, from
the input passed to set_input
=cut
sub field_errors
{
my ($self, $name) = @_;
my @errs;
my $in = $self->{'in'};
foreach my $i (keys %$in) {
	if ($i eq "ui_error_".$name) {
		push(@errs, split(/\0/, $in->{$i}));
		}
	}
return @errs;
}

=head2 set_input(&input)
Passes the form input hash to this form object, for use by the validate
functions and for displaying errors next to fields.
=cut
sub set_input
{
my ($self, $in) = @_;
$self->{'in'} = $in;
}

=head2 get_value(input-name)
Returns the value of the input with the given name.
=cut
sub get_value
{
my ($self, $name) = @_;
foreach my $s (@{$self->{'sections'}}) {
	my $rv = $s->get_value($name);
	return $rv if (defined($rv));
	}
return $self->{'in'}->{$name};
}

=head2 get_input(name)
Returns the input with the given name
=cut
sub get_input
{
my ($self, $name) = @_;
foreach my $i ($self->list_inputs()) {
	return $i if ($i->get_name() eq $name);
	}
return undef;
}

sub set_program
{
my ($self, $program) = @_;
$self->{'program'} = $program;
}

sub set_method
{
my ($self, $method) = @_;
$self->{'method'} = $method;
}

=head2 list_inputs()
Returns all inputs in all form sections
=cut
sub list_inputs
{
my ($self) = @_;
my @rv;
foreach my $s (@{$self->{'sections'}}) {
	push(@rv, $s->list_inputs());
	}
return @rv;
}

=head2 list_disable_inputs()
Returns a list of inputs that have disable functions
=cut
sub list_disable_inputs
{
my ($self) = @_;
my @dis;
foreach my $i ($self->list_inputs()) {
	push(@dis, $i) if ($i->get_disable_code());
	}
return @dis;
}

=head2 set_page(WebminUI::Page)
Called when this form is added to a page
=cut
sub set_page
{
my ($self, $page) = @_;
$self->{'page'} = $page;
}

=head2 get_changefunc(&input)
Called by some input, to return the Javascript that should be called when this
input changes it's value.
=cut
sub get_changefunc
{
my ($self, $input) = @_;
my @dis = $self->list_disable_inputs();
if (@dis) {
	return "ui_disable_".$self->{'name'}."(form)";
	}
return undef;
}

=head2 set_heading(text)
Sets the heading to be displayed above the form
=cut
sub set_heading
{
my ($self, $heading) = @_;
$self->{'heading'} = $heading;
}

sub get_heading
{
my ($self) = @_;
return $self->{'heading'};
}

=head2 get_formno()
Returns the index of this form on the page
=cut
sub get_formno
{
my ($self) = @_;
my $n = 0;
foreach my $f (@{$self->{'page'}->{'contents'}}) {
	if ($f eq $self) {
		return $n;
		}
	elsif (ref($f) =~ /Form/) {
		$n++;
		}
	}
return undef;
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

=head2 set_align(align)
Sets the alignment on the page (left, center, right)
=cut
sub set_align
{
my ($self, $align) = @_;
$self->{'align'} = $align;
}

sub get_align
{
my ($self) = @_;
return $self->{'align'};
}

1;

