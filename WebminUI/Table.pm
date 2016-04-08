package WebminUI::Table;
use WebminUI::JavascriptButton;
use WebminCore;

=head2 new WebminUI::Table(&headings, [width], [name], [heading])
Create a multi-column table, with support for sorting, paging and so on
=cut
sub new
{
if (defined(&WebminUI::Theme::Table::new) &&
    caller() !~ /WebminUI::Theme::Table/) {
        return new WebminUI::Theme::Table(@_[1..$#_]);
        }
my ($self, $headings, $width, $name, $heading) = @_;
$self = { 'sorter' => [ map { \&default_sorter } @$headings ] };
bless($self);
$self->set_headings($headings);
$self->set_name($name) if (defined($name));
$self->set_width($width) if (defined($width));
$self->set_heading($heading) if (defined($heading));
$self->set_all_sortable(1);
$self->set_paging(1);
return $self;
}

=head2 add_row(&fields)
Adds a row to the table. Each element in the row can be either an input of some
kind, or a piece of text.
=cut
sub add_row
{
my ($self, $fields) = @_;
push(@{$self->{'rows'}}, $fields);
}

=head2 html()
Returns the HTML for this table. The actual ordering may depend upon sort headers
clicked by the user. The rows to display may be limited by the page size.
=cut
sub html
{
my ($self) = @_;
my @srows = @{$self->{'rows'}};
my $thisurl = $self->{'form'}->{'page'}->get_myurl();
my $name = $self->get_name();
my $rv;

# Add the heading
if ($self->get_heading()) {
	$rv .= &ui_subheading($self->get_heading())."\n";
	}

my $sm = $self->get_searchmax();
if (defined($sm) && @srows > $sm) {
	# Too many rows to show .. add a search form. This will need to close
	# the parent form, and then re-open it after the search form, as nested
	# forms aren't allowed!
	if ($self->get_searchmsg()) {
		$rv .= $self->get_searchmsg()."<br>\n";
		}

	my $form = new WebminUI::Form($thisurl, "get");
	$form->set_input($self->{'form'}->{'in'});
	my $section = new WebminUI::Section(undef, 2);
	$form->add_section($section);

	my $col = new WebminUI::Select("ui_searchcol_".$name, undef);
	my $i = 0;
	foreach my $h (@{$self->get_headings()}) {
		if ($self->{'sortable'}->[$i]) {
			$col->add_option($i, $h);
			}
		$i++;
		}
	$section->add_input($text{'ui_searchcol'}, $col);

	my $for = new WebminUI::Textbox("ui_searchfor_".$name, undef, 30);
	$section->add_input($text{'ui_searchfor'}, $for);

	$rv .= $section->html();
	my $url = $self->make_url(undef, undef, undef, undef, 1);
	my $jsb = new WebminUI::JavascriptButton($text{'ui_searchok'},
			"window.location = '$url'+'&'+'ui_searchfor_${name}'+'='+escape(form.ui_searchfor_${name}.value)+'&'+'ui_searchcol_${name}'+'='+escape(form.ui_searchcol_${name}.selectedIndex)");
	$rv .= $jsb->html();
	$rv .= "<br>\n";

	# Limit records to current search
	if (defined($col->get_value())) {
		my $sf = $for->get_value();
		@srows = grep { $_->[$col->get_value()] =~ /\Q$sf\E/i } @srows;
		}
	else {
		@srows = ( );
		}
	}

# Prepare the selector
my $selc = $self->{'selectcolumn'};
my $seli = $self->{'selectinput'};
my %selmap;
if (defined($selc)) {
	my $i = 0;
	foreach my $r (@srows) {
		$selmap{$r,$selc} = $seli->one_html($i);
		$i++;
		}
	}

# Sort the rows
my ($sortcol, $sortdir) = $self->get_sortcolumn();
if (defined($sortcol)) {
	my $func = $self->{'sorter'}->[$sortcol];
	@srows = sort { my $so = &$func($a->[$sortcol], $b->[$sortcol], $sortcol);
			$sortdir ? -$so : $so } @srows;
	}

# Build the td attributes
my @tds = map { "valign=top" } @{$self->{'headings'}};
if ($self->{'widths'}) {
	my $i = 0;
	foreach my $w (@{$self->{'widths'}}) {
		$tds[$i++] .= " width=$w";
		}
	}
if ($self->{'aligns'}) {
	my $i = 0;
	foreach my $a (@{$self->{'aligns'}}) {
		$tds[$i++] .= " align=$a";
		}
	}

# Find the page we want
my $page = $self->get_pagepos();
my ($start, $end, $origsize);
if ($self->get_paging() && $self->get_pagesize()) {
	# Restrict view to rows within some page
	$start = $self->get_pagesize()*$page;
	$end = $self->get_pagesize()*($page+1) - 1;
	if ($start >= @srows) {
		# Gone off end!
		$start = 0;
		$end = $self->get_pagesize()-1;
		}
	if ($end >= @srows) {
		# End is too far
		$end = @srows-1;
		}
	$origsize = scalar(@srows);
	@srows = @srows[$start..$end];
	}

# Generate the headings, with sorters
$thisurl .= $thisurl =~ /\?/ ? "&" : "?";
my @sheadings;
my $i = 0;
foreach my $h (@{$self->get_headings()}) {
	if ($self->{'sortable'}->[$i]) {
		# Column can be sorted!
		my $hh = "<table cellpadding=0 cellspacing=0 width=100%><tr>";
		$hh .= "<td><b>$h</b></td> <td align=right>";
		if (!defined($sortcol) || $sortcol != $i) {
			# Not sorting on this column .. show grey button
			my $url = $self->make_url($i, 0, undef, undef);
			$hh .= "<a href='$url'>".
			       "<img src=$gconfig{'webprefix'}/images/nosort.gif border=0></a>";
			}
		else {
			# Sorting .. show button to switch mode
			my $notsort = !$sortdir;
			my $url = $self->make_url($i, $sortdir ? 0 : 1, undef, undef);
			$hh .= "<a href='$url'>".
			       "<img src=$gconfig{'webprefix'}/images/sort.gif border=0></a>";
			}
		$hh .= "</td></tr></table>";
		push(@sheadings, $hh);
		}
	else {
		push(@sheadings, $h);
		}
	$i++;
	}

# Get any errors for inputs
my @errs = map { $_->get_errors() } $self->list_inputs();
if (@errs) {
	foreach my $e (@errs) {
		$rv .= "<font color=#ff0000>$e</font><br>\n";
		}
	}

# Build links for top and bottom
my $links;
if (ref($seli) =~ /Checkboxes/) {
	# Add select all/none links
	my $formno = $self->{'form'}->get_formno();
	$links .= &select_all_link($seli->get_name(), $formno,
					 $text{'ui_selall'})."\n";
	$links .= &select_invert_link($seli->get_name(), $formno,
					    $text{'ui_selinv'})."\n";
	$links .= "&nbsp;\n";
	}
foreach my $l (@{$self->{'links'}}) {
	$links .= "<a href='$l->[0]'>$l->[1]</a>\n";
	}
$links .= "<br>" if ($links);

# Build list of inputs for bottom
my $inputs;
foreach my $i (@{$self->{'inputs'}}) {
	$inputs .= $i->html()."\n";
	}
$inputs .= "<br>" if ($inputs);

# Create the pager
if ($self->get_paging() && $origsize) {
	my $lastpage = int(($origsize-1)/$self->get_pagesize());
	$rv .= "<center>";
	if ($page != 0) {
		# Add start and left arrows
		my $surl = $self->make_url(undef, undef, undef, 0);
		$rv .= "<a href='$surl'><img src=$gconfig{'webprefix'}/images/first.gif border=0 align=middle></a>\n";
		my $lurl = $self->make_url(undef, undef, undef, $page-1);
		$rv .= "<a href='$lurl'><img src=$gconfig{'webprefix'}/images/left.gif border=0 align=middle></a>\n";
		}
	else {
		# Start and left are disabled
		$rv .= "<img src=$gconfig{'webprefix'}/images/first-grey.gif border=0 align=middle>\n";
		$rv .= "<img src=$gconfig{'webprefix'}/images/left-grey.gif border=0 align=middle>\n";
		}
	$rv .= &text('ui_paging', $start+1, $end+1, $origsize);
	if ($end < $origsize-1) {
		# Add right and end arrows
		my $rurl = $self->make_url(undef, undef, undef, $page+1);
		$rv .= "<a href='$rurl'><img src=$gconfig{'webprefix'}/images/right.gif border=0 align=middle></a>\n";
		my $eurl = $self->make_url(undef, undef, undef, $lastpage);
		$rv .= "<a href='$eurl'><img src=$gconfig{'webprefix'}/images/last.gif border=0 align=middle></a>\n";
		}
	else {
		# Right and end are disabled
		$rv .= "<img src=$gconfig{'webprefix'}/images/right-grey.gif border=0 align=middle>\n";
		$rv .= "<img src=$gconfig{'webprefix'}/images/last-grey.gif border=0 align=middle>\n";
		}
	$rv .= "</center>\n";
	}

# Create actual table
if (@srows) {
	$rv .= $links;
	$rv .= &ui_columns_start(\@sheadings, $self->{'width'}, 0, \@tds);
	foreach my $r (@srows) {
		my @row;
		for(my $i=0; $i<@$r || $i<@sheadings; $i++) {
			if (ref($r->[$i]) eq "ARRAY") {
				my $j = $r->[$i]->[0] &&
					$r->[$i]->[0]->isa("WebminUI::TableAction")
					? "&nbsp;|&nbsp;" : "&nbsp;";
				$row[$i] = $selmap{$r,$i}.
				  join($j, map { ref($_) ? $_->html() : $_ }
						     @{$r->[$i]});
				}
			elsif (ref($r->[$i])) {
				$row[$i] = $selmap{$r,$i}.$r->[$i]->html();
				}
			else {
				$row[$i] = $selmap{$r,$i}.$r->[$i];
				}
			}
		$rv .= &ui_columns_row(\@row, \@tds);
		}
	$rv .= &ui_columns_end();
	}
elsif ($self->{'emptymsg'}) {
	$rv .= $self->{'emptymsg'}."<p>\n";
	}
$rv .= $links;
$rv .= $inputs;
return $rv;
}

=head2 set_form(form)
Called by the WebminUI::Form object when this table is added to it
=cut
sub set_form
{
my ($self, $form) = @_;
$self->{'form'} = $form;
foreach my $i ($self->list_inputs()) {
	$i->set_form($form);
	}
}

=head2 set_sorter(function, [column])
Sets a function used for sorting fields. Will be called with two field values to
compare, and a column number.
=cut
sub set_sorter
{
my ($self, $func, $col) = @_;
if (defined($col)) {
	$self->{'sorter'}->[$col] = $func;
	}
else {
	$self->{'sorter'} = [ map { $func } @{$self->{'headings'}} ];
	}
}

=head2 default_sorter(value1, value2, col)
=cut
sub default_sorter
{
my ($value1, $value2, $col) = @_;
if (ref($value1) && $value1->isa("WebminUI::TableAction")) {
	$value1 = $value1->get_value();
	$value2 = $value2->get_value();
	}
return lc($value1) cmp lc($value2);
}

=head2 numeric_sorter(value1, value2, col)
=cut
sub numeric_sorter
{
my ($value1, $value2, $col) = @_;
return $value1 <=> $value2;
}

=head2 set_sortable(column, sortable?)
Tells the table if some column should allow sorting or not. By default, all are.
=cut
sub set_sortable
{
my ($self, $col, $sortable) = @_;
$self->{'sortable'}->[$col] = $sortable;
}

=head2 set_all_sortable(sortable?)
Enabled or disables sorting for all columns
=cut
sub set_all_sortable
{
my ($self, $sortable) = @_;
$self->{'sortable'} = [ map { $sortable } @{$self->{'headings'}} ];
}

=head2 get_sortcolumn()
Returns the column to sort on and the order (1 for descending), or undef for none
=cut
sub get_sortcolumn
{
my ($self) = @_;
my $in = $self->{'form'} ? $self->{'form'}->{'in'} : undef;
my $name = $self->get_name();
if ($in && defined($in->{"ui_sortcolumn_".$name})) {
	return ( $in->{"ui_sortcolumn_".$name},
		 $in->{"ui_sortdir_".$name} );
	}
else {
	return ( $self->{'sortcolumn'}, $self->{'sortdir'} );
	}
}

=head2 set_sortcolumn(num, descending?)
Sets the default column on which sorting will be done, unless overridden by
the user.
=cut
sub set_sortcolumn
{
my ($self, $col, $desc) = @_;
$self->{'sortcolumn'} = $col;
$self->{'sortdir'} = $desc;
}

=head2 get_paging()
Returns 1 if page-by-page display should be used
=cut
sub get_paging
{
my ($self) = @_;
my $in = $self->{'form'} ? $self->{'form'}->{'in'} : undef;
my $name = $self->get_name();
if ($in && defined($in->{"ui_paging_".$name})) {
	return ( $in->{"ui_paging_".$name} );
	}
else {
	return ( $self->{'paging'} );
	}
}

=head2 set_paging(paging?)
Turns page-by-page display of the table on or off
=cut
sub set_paging
{
my ($self, $paging) = @_;
$self->{'paging'} = $paging;
}

sub set_name
{
my ($self, $name) = @_;
$self->{'name'} = $name;
}

=head2 get_name()
Returns the name for indentifying this table in HTML
=cut
sub get_name
{
my ($self) = @_;
if (defined($self->{'name'})) {
	return $self->{'name'};
	}
elsif ($self->{'form'}) {
	my $secs = $self->{'form'}->{'sections'};
	for(my $i=0; $i<@$secs; $i++) {
		return "table".$i if ($secs->[$i] eq $self);
		}
	}
return "table";
}

sub set_headings
{
my ($self, $headings) = @_;
$self->{'headings'} = $headings;
}

sub get_headings
{
my ($self) = @_;
return $self->{'headings'};
}

=head2 set_selector(column, input)
Takes a WebminUI::Checkboxes or WebminUI::Radios object, and uses it to add checkboxes
in the specified column.
=cut
sub set_selector
{
my ($self, $col, $input) = @_;
$self->{'selectcolumn'} = $col;
$self->{'selectinput'} = $input;
$input->set_form($form);
}

=head2 get_selector()
Returns the UI element used for selecting rows
=cut
sub get_selector
{
my ($self) = @_;
return wantarray ? ( $self->{'selectinput'}, $self->{'selectcolumn'} )
		 : $self->{'selectinput'};
}

=head2 set_widths(&widths)
Given an array reference of widths (like 50 or 20%), uses them for the columns
in the table.
=cut
sub set_widths
{
my ($self, $widths) = @_;
$self->{'widths'} = $widths;
}

=head2 set_width([number|number%])
Sets the width of this entire table. Can be called with 100%, 500 or undef to use
the minimum possible width.
=cut
sub set_width
{
my ($self, $width) = @_;
$self->{'width'} = $width;
}

=head2 set_aligns(&aligns)
Given an array reference of horizontal alignments (like left or right), uses them
for the columns in the table.
=cut
sub set_aligns
{
my ($self, $aligns) = @_;
$self->{'aligns'} = $aligns;
}

=head2 validate()
Validates all inputs, and returns a list of error messages
=cut
sub validate
{
my ($self) = @_;
my $seli = $self->{'selectinput'};
my @errs;
if ($seli) {
	push(@errs, map { [ $seli->get_name(), $_ ] } $seli->validate());
	}
foreach my $i ($self->list_inputs()) {
	foreach my $e ($i->validate()) {
		push(@errs, [ $i->get_name(), $e ]);
		}
	}
return @errs;
}

=head2 get_value(input-name)
Returns the value of the input with the given name.
=cut
sub get_value
{
my ($self, $name) = @_;
if ($self->{'selectinput'} && $self->{'selectinput'}->get_name() eq $name) {
	return $self->{'selectinput'}->get_value();
	}
foreach my $i ($self->list_inputs()) {
	if ($i->get_name() eq $name) {
		return $i->get_value();
		}
	}
return undef;
}

=head2 list_inputs()
Returns all inputs in all form sections
=cut
sub list_inputs
{
my ($self) = @_;
my @rv = @{$self->{'inputs'}};
push(@rv, $self->{'selectinput'}) if ($self->{'selectinput'});
return @rv;
}

=head2 set_searchmax(num, [message])
Sets the maximum number of table rows to display before showing a search form
=cut
sub set_searchmax
{
my ($self, $searchmax, $searchmsg) = @_;
$self->{'searchmax'} = $searchmax;
$self->{'searchmsg'} = $searchmsg;
}

sub get_searchmax
{
my ($self) = @_;
return $self->{'searchmax'};
}

sub get_searchmsg
{
my ($self) = @_;
return $self->{'searchmsg'};
}

=head2 add_link(link, message)
Adds a link to the table, for example for adding a new entry
=cut
sub add_link
{
my ($self, $link, $msg) = @_;
push(@{$self->{'links'}}, [ $link, $msg ]);
}

=head2 add_input(input)
Adds some input to be displayed at the bottom of the table
=cut
sub add_input
{
my ($self, $input) = @_;
push(@{$self->{'inputs'}}, $input);
$input->set_form($self->{'form'});
}

=head2 set_emptymsg(message)
Sets the message to display when the table is empty
=cut
sub set_emptymsg
{
my ($self, $emptymsg) = @_;
$self->{'emptymsg'} = $emptymsg;
}

=head2 set_heading(text)
Sets the heading text to appear above the table
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

=head2 set_pagesize(pagesize)
Sets the size of a page. Set to 0 to turn off completely.
=cut
sub set_pagesize
{
my ($self, $pagesize) = @_;
$self->{'pagesize'} = $pagesize;
}

=head2 get_pagesize()
Returns the size of a page, or 0 if paging is turned off totally
=cut
sub get_pagesize
{
my ($self) = @_;
return $self->{'pagesize'};
}

sub get_pagepos
{
my ($self) = @_;
my $in = $self->{'form'} ? $self->{'form'}->{'in'} : undef;
my $name = $self->get_name();
if ($in && defined($in->{"ui_pagepos_".$name})) {
	return ( $in->{"ui_pagepos_".$name} );
	}
else {
	return ( $self->{'pagepos'} );
	}
}

=head2 make_url(sortcol, sortdir, paging, page, [no-searchargs], [no-pagearg])
Returns a link to this table's page, with the defaults for the various state
fields overriden by the parameters (where defined)
=cut
sub make_url
{
my ($self, $newsortcol, $newsortdir, $newpaging, $newpagepos,
    $nosearch, $nopage) = @_;
my ($sortcol, $sortdir) = $self->get_sortcolumn();
$sortcol = $newsortcol if (defined($newsortcol));
$sortdir = $newsortdir if (defined($newsortdir));
my $paging = $self->get_paging();
$paging = $newpaging if (defined($newpaging));
my $pagepos = $self->get_pagepos();
$pagepos = $newpagepos if (defined($newpagepos));

my $thisurl = $self->{'form'}->{'page'}->get_myurl();
my $name = $self->get_name();
$thisurl .= $thisurl =~ /\?/ ? "&" : "?";
my $in = $self->{'form'}->{'in'};
return "${thisurl}ui_sortcolumn_${name}=$sortcol".
       "&ui_sortdir_${name}=$sortdir".
       "&ui_paging_${name}=$paging".
       ($nopage ? "" : "&ui_pagepos_${name}=$pagepos").
       ($nosearch ? "" : "&ui_searchfor_${name}=".
			 &urlize($in->{"ui_searchfor_${name}"}).
			 "&ui_searchcol_${name}=".
			 &urlize($in->{"ui_searchcol_${name}"}));
}

1;

