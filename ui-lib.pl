use vars qw($theme_no_table $ui_radio_selector_donejs $module_name
	    $ui_multi_select_donejs, $ui_formcount,
	    $ui_form_end_side_by_side_donecss,
	    $ui_form_grouped_buttons_donecss);

=head1 ui-lib.pl

Common functions for generating HTML for Webmin user interface elements.
Some example code :

 use WebminCore;
 init_config();
 ui_print_header(undef, 'My Module', '');

 print ui_form_start('save.cgi');
 print ui_table_start('My form', undef, 2);

 print ui_table_row('Enter your name',
	ui_textbox('name', undef, 40));

 print ui_table_end();
 print ui_form_end([ [ undef, 'Save' ] ]);

 ui_print_footer('/', 'Webmin index');

=cut

####################### utility functions

=head2 ui_link(href, text, [class], [tags])

Returns HTML for an <a href>.

=item href - Link

=item text - Text to display for link

=item class - Optional additional CSS classes to include

=item tags - Additional HTML attributes for the <a> tag.

=cut

sub ui_link
{
return &theme_ui_link(@_) if (defined(&theme_ui_link));
my ($href, $text, $class, $tags) = @_;
return ("<a class='ui_link".($class ? " ".$class : "")."' href='$href'".($tags ? " ".$tags : "").">$text</a>");
}

=head2 ui_help(title)

Returns HTML for help tooltip bubble

=item title - help tooltip title

=cut

sub ui_help
{
return &theme_ui_help(@_) if (defined(&theme_ui_help));
my ($title) = @_;
$title = &html_escape(&html_strip($title));
return ("<sup class=\"ui_help\" aria-label=\"$title\" data-tooltip><samp>?</samp></sup>");
}

=head2 ui_img(src, alt, title, [class], [tags])

Returns HTML for an <img src>.

=item src - Image path and filename

=item alt - Alt text for screen readers, etc.

=item title - Element title, and tooltip when user hovers over image

=item class - Optional additional CSS classes to include

=item tags - Additional HTML attributes for the <img> tag

=cut

sub ui_img
{
return &theme_ui_img(@_) if (defined(&theme_ui_img));
my ($src, $alt, $title, $class, $tags) = @_;
my $esrc   = &quote_escape($src);
my $ealt   = &quote_escape($alt);
my $etitle = &quote_escape($title);
return ("<img src='".$esrc."' class='ui_img".($class ? " ".$class : "")."' alt='$ealt' ".($title ne '' ? "title='$etitle'" : "").($tags ? " ".$tags : "").">");
}

=head2 ui_link_button(href, text, [target], [tags])

Returns HTML for a button, which opens a URL when clicked. The parameters are :

=item href - Link URL

=item text - Text to display on the button

=item target - Window name to open the link in

=item tags - Additional HTML attributes for the <input> tag.

=cut

sub ui_link_button
{
return &theme_ui_link_button(@_) if (defined(&theme_ui_link_button));
my ($href, $label, $target, $tags) = @_;
$target ||= "_self";
return &ui_button($label, undef, 0,
	"onClick='window.open(\"".&quote_javascript($href)."\", \"$target\")' ".
	$tags);
}

####################### table generation functions

=head2 ui_table_start(heading, [tabletags], [cols], [&default-tds], [right-heading])

Returns HTML for the start of a form block into which labelled inputs can
be placed. By default this is implemented as a table with another table inside
it, but themes may override this with their own layout.

The parameters are :

=item heading - Text to show at the top of the form.

=item tabletags - HTML attributes to put in the outer <table>, typically something like width=100%.

=item cols - Desired number of columns for labels and fields. Defaults to 4, but can be 2 for forms with lots of wide inputs.

=item default-tds - An optional array reference of HTML attributes for the <td> tags in each row of the table.

=item right-heading - HTML to appear in the heading, aligned to the right.

=cut
sub ui_table_start
{
return &theme_ui_table_start(@_) if (defined(&theme_ui_table_start));
my ($heading, $tabletags, $cols, $tds, $rightheading) = @_;
if (defined($main::ui_table_cols)) {
	# Push on stack, for nested call
	push(@main::ui_table_cols_stack, $main::ui_table_cols);
	push(@main::ui_table_pos_stack, $main::ui_table_pos);
	push(@main::ui_table_default_tds_stack, $main::ui_table_default_tds);
	}
my $colspan = 1;
my $rv;
$rv .= "<table class='ui_table' border $tabletags>\n";
if (defined($heading) || defined($rightheading)) {
	$rv .= "<tr".($tb ? " ".$tb : "")." class='ui_table_head'>";
	if (defined($heading)) {
		$rv .= "<td><b>$heading</b></td>"
		}
	if (defined($rightheading)) {
		$rv .= "<td align='right'>$rightheading</td>";
		$colspan++;
		}
	$rv .= "</tr>\n";
	}
$rv .= "<tr".($cb ? " ".$cb : "")." class='ui_table_body'> <td colspan='$colspan'>".
       "<table width='100%'>\n";
$main::ui_table_cols = $cols || 4;
$main::ui_table_pos = 0;
$main::ui_table_default_tds = $tds;
return $rv;
}

=head2 ui_table_end

Returns HTML for the end of a block started by ui_table_start.

=cut
sub ui_table_end
{
return &theme_ui_table_end(@_) if (defined(&theme_ui_table_end));
my $rv;
if ($main::ui_table_cols == 4 && $main::ui_table_pos) {
	# Add an empty block to balance the table
	$rv .= &ui_table_row(" ", " ");
	}
if (@main::ui_table_cols_stack) {
	$main::ui_table_cols = pop(@main::ui_table_cols_stack);
	$main::ui_table_pos = pop(@main::ui_table_pos_stack);
	$main::ui_table_default_tds = pop(@main::ui_table_default_tds_stack);
	}
else {
	$main::ui_table_cols = undef;
	$main::ui_table_pos = undef;
	$main::ui_table_default_tds = undef;
	}
$rv .= "</table></td></tr></table>\n";
return $rv;
}

=head2 ui_table_row(label, value, [cols], [&td-tags], [&tr-tags])

Returns HTML for a row in a table started by ui_table_start, with a 1-column
label and 1+ column value. The parameters are :

=item label - Label for the input field. If this is undef, no label is displayed.

=item value - HTML for the input part of the row.

=item cols - Number of columns the value should take up, defaulting to 1.

=item td-tags - Array reference of HTML attributes for the <td> tags in this row.

=item tr-tags - Array reference of HTML attributes and class names for the <tr> tag.

=cut
sub ui_table_row
{
return &theme_ui_table_row(@_) if (defined(&theme_ui_table_row));
my ($label, $value, $cols, $tds, $trs) = @_;
$cols ||= 1;
$tds ||= $main::ui_table_default_tds;
my $rv;
if ($main::ui_table_pos+$cols+1 > $main::ui_table_cols &&
    $main::ui_table_pos != 0) {
	# If the requested number of cols won't fit in the number
	# remaining, start a new row
	my $leftover = $main::ui_table_cols - $main::ui_table_pos;
	$rv .= "<td colspan='$leftover'></td>\n";
	$rv .= "</tr>\n";
	$main::ui_table_pos = 0;
	}
my $trtags_attrs = ref($trs) eq 'ARRAY' && $trs->[0] ? " $trs->[0]" : "";
my $trtags_class = ref($trs) eq 'ARRAY' && $trs->[1] ? " $trs->[1]" : "";
$rv .= "<tr class='ui_table_row$trtags_class'$trtags_attrs>\n"
	if ($main::ui_table_pos%$main::ui_table_cols == 0);
if (defined($label) &&
    ($value =~ /id="([^"]+)"/ || $value =~ /id='([^']+)'/ ||
     $value =~ /id=([^>\s]+)/)) {
	# Value contains an input with an ID
	my $id = $1;
	$label = "<label for=\"".&quote_escape($id)."\">$label</label>";
	}
$rv .= "<td valign='top' $tds->[0] class='ui_label'><b>$label</b></td>\n"
	if (defined($label));
$rv .= "<td valign='top' colspan='$cols' $tds->[1] class='ui_value'>$value</td>\n";
$main::ui_table_pos += $cols+(defined($label) ? 1 : 0);
if ($main::ui_table_pos%$main::ui_table_cols == 0) {
	$rv .= "</tr>\n";
	$main::ui_table_pos = 0;
	}
return $rv;
}

=head2 ui_table_hr

Returns HTML for a row in a block started by ui_table_row, with a horizontal
line inside it to separate sections.

=cut
sub ui_table_hr
{
return &theme_ui_table_hr(@_) if (defined(&theme_ui_table_hr));
my $rv;
if ($ui_table_pos) {
	$rv .= "</tr>\n";
	$ui_table_pos = 0;
	}
$rv .= "<tr class='ui_table_hr'> ".
       "<td colspan='$main::ui_table_cols'><hr></td> </tr>\n";
return $rv;
}

=head2 ui_table_span(text)

Outputs a table row that spans the whole table, and contains the given text.

=cut
sub ui_table_span
{
my ($text) = @_;
return &theme_ui_table_span(@_) if (defined(&theme_ui_table_span));
my $rv;
if ($ui_table_pos) {
	$rv .= "</tr>\n";
	$ui_table_pos = 0;
	}
$rv .= "<tr class='ui_table_span'> ".
       "<td colspan='$main::ui_table_cols'>$text</td> </tr>\n";
return $rv;
}

=head2 ui_columns_start(&headings, [width-percent], [noborder], [&tdtags], [heading], [sortable])

Returns HTML for the start of a multi-column table, with the given headings.
The parameters are :

=item headings - An array reference of headers for the table's columns.

=item width-percent - Desired width as a percentage, or undef to let the browser decide.

=item noborder - Set to 1 if the table should not have a border.

=item tdtags - An optional reference to an array of HTML attributes for the table's <td> tags.

=item heading - An optional heading to put above the table.

=item sortable - Set to 1 to ask the theme for client-side sorting and searching of this table, such as with DataTables in the Authentic theme. The table is marked with a data-sortable attribute. A module can instead request this for all tables on its pages with sortable=1 in module.info.

=cut
sub ui_columns_start
{
return &theme_ui_columns_start(@_) if (defined(&theme_ui_columns_start));
my ($heads, $width, $noborder, $tdtags, $title, $sortable) = @_;
my $rv;
$rv .= "<table".($noborder ? "" : " border").
		(defined($width) ? " width='$width%'" : "")." class='ui_columns'".
		($sortable ? " data-sortable='1'" : "").">\n";
if ($title) {
	$rv .= "<tr".($tb ? " ".$tb : "")." class='ui_columns_heading'>".
	       "<td colspan='".scalar(@$heads)."'><b>$title</b></td></tr>\n";
	}
$rv .= "<tr".($tb ? " ".$tb : "")." class='ui_columns_heads'>\n";
my $i;
for($i=0; $i<@$heads; $i++) {
	$rv .= "<td ".$tdtags->[$i]."><b>".
	       ($heads->[$i] eq "" ? "<br>" : $heads->[$i])."</b></td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

=head2 ui_columns_row(&columns, &tdtags)

Returns HTML for a row in a multi-column table. The parameters are :

=item columns - Reference to an array containing the HTML to show in the columns for this row.

=item tdtags - An optional array reference containing HTML attributes for the row's <td> tags.

=cut
sub ui_columns_row
{
return &theme_ui_columns_row(@_) if (defined(&theme_ui_columns_row));
my ($cols, $tdtags) = @_;
my $rv;
$rv .= "<tr".($cb ? " ".$cb : "")." class='ui_columns_row'>\n";
my $i;
for($i=0; $i<@$cols; $i++) {
	$rv .= "<td ".$tdtags->[$i].">".
	       ($cols->[$i] !~ /\S/ ? "<br>" : $cols->[$i])."</td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

=head2 ui_columns_header(&columns, &tdtags)

Returns HTML for a row in a multi-column table, styled as a header. Parameters
are the same as ui_columns_row.

=cut
sub ui_columns_header
{
return &theme_ui_columns_header(@_) if (defined(&theme_ui_columns_header));
my ($cols, $tdtags) = @_;
my $rv;
$rv .= "<tr".($tb ? " ".$tb : "")." class='ui_columns_header'>\n";
my $i;
for($i=0; $i<@$cols; $i++) {
	$rv .= "<td ".$tdtags->[$i]."><b>".
	       ($cols->[$i] eq "" ? "<br>" : $cols->[$i])."</b></td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

=head2 ui_checked_columns_row(&columns, &tdtags, checkname, checkvalue, [checked?], [disabled], [tags])

Returns HTML for a row in a multi-column table, in which the first column
contains a checkbox. The parameters are :

=item columns - Reference to an array containing the HTML to show in the columns for this row.

=item tdtags - An optional array reference containing HTML attributes for the row's <td> tags.

=item checkname - Name for the checkbox input. Should be the same for all rows.

=item checkvalue - Value for this checkbox input.

=item checked - Set to 1 if it should be checked by default.

=item disabled - Set to 1 if the checkbox should be disabled and thus un-clickable.

=item tags - Extra HTML tags to include in the radio button.

=cut
sub ui_checked_columns_row
{
return &theme_ui_checked_columns_row(@_) if (defined(&theme_ui_checked_columns_row));
my ($cols, $tdtags, $checkname, $checkvalue, $checked, $disabled, $tags) = @_;
my $rv;
$rv .= "<tr".($cb ? " ".$cb : "")." class='ui_checked_columns'>\n";
$rv .= "<td class='ui_checked_checkbox' ".$tdtags->[0].">".
       &ui_checkbox($checkname, $checkvalue, undef, $checked, $tags, $disabled).
       "</td>\n";
my $i;
for($i=0; $i<@$cols; $i++) {
	$rv .= "<td ".$tdtags->[$i+1].">";
	if ($cols->[$i] !~ /<a\s+href|<input|<select|<textarea/) {
		$rv .= "<label for=\"".
			&quote_escape("${checkname}_${checkvalue}")."\">";
		}
	$rv .= ($cols->[$i] !~ /\S/ ? "<br>" : $cols->[$i]);
	if ($cols->[$i] !~ /<a\s+href|<input|<select|<textarea/) {
		$rv .= "</label>";
		}
	$rv .= "</td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

=head2 ui_radio_columns_row(&columns, &tdtags, checkname, checkvalue, [checked], [disabled], [tags])

Returns HTML for a row in a multi-column table, in which the first
column is a radio button. The parameters are :

=item columns - Reference to an array containing the HTML to show in the columns for this row.

=item tdtags - An optional array reference containing HTML attributes for the row's <td> tags.

=item checkname - Name for the radio button input. Should be the same for all rows.

=item checkvalue - Value for this radio button option.

=item checked - Set to 1 if it should be checked by default.

=item disabled - Set to 1 if the radio button should be disabled and thus un-clickable.

=item tags - Extra HTML tags to include in the radio button.

=cut
sub ui_radio_columns_row
{
return &theme_ui_radio_columns_row(@_) if (defined(&theme_ui_radio_columns_row));
my ($cols, $tdtags, $checkname, $checkvalue, $checked, $dis, $tags) = @_;
my $rv;
$rv .= "<tr".($cb ? " ".$cb : "")." class='ui_radio_columns'>\n";
$rv .= "<td class='ui_radio_radio' ".$tdtags->[0].">".
    &ui_oneradio($checkname, $checkvalue, "", $checked, undef, $dis)."</td>\n";
my $i;
for($i=0; $i<@$cols; $i++) {
	$rv .= "<td ".$tdtags->[$i+1].">";
	if ($cols->[$i] !~ /<a\s+href|<input|<select|<textarea/) {
		$rv .= "<label for=\"".
			&quote_escape("${checkname}_${checkvalue}")."\">";
		}
	$rv .= ($cols->[$i] !~ /\S/ ? "<br>" : $cols->[$i]);
	if ($cols->[$i] !~ /<a\s+href|<input|<select|<textarea/) {
		$rv .= "</label>";
		}
	$rv .= "</td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

=head2 ui_columns_end

Returns HTML to end a table started by ui_columns_start.

=cut
sub ui_columns_end
{
return &theme_ui_columns_end(@_) if (defined(&theme_ui_columns_end));
return "</table>\n";
}

=head2 ui_columns_table(&headings, width-percent, &data, &types, no-sort, title, empty-msg, [sortable])

Returns HTML for a complete table, typically generated internally by
ui_columns_start, ui_columns_row and ui_columns_end. The parameters are :

=item headings - An array ref of heading HTML.

=item width-percent - Preferred total width

=item data - A 2x2 array ref of table contents. Each can either be a simple string, or a hash ref like :

  { 'type' => 'group', 'desc' => 'Some section title' }
  { 'type' => 'string', 'value' => 'Foo', 'colums' => 3,
    'nowrap' => 1 }
  { 'type' => 'checkbox', 'name' => 'd', 'value' => 'foo',
    'label' => 'Yes', 'checked' => 1, 'disabled' => 1 }
  { 'type' => 'radio', 'name' => 'd', 'value' => 'foo', ... }

=item types - An array ref of data types, such as 'string', 'number', 'bytes' or 'date'

=item no-sort - Set to 1 to disable sorting by theme.

=item title - Text to appear above the table.

=item empty-msg - Message to display if no data.

=item sortable - Set to 1 to ask the theme for client-side sorting and searching, as for ui_columns_start.

=cut
sub ui_columns_table
{
return &theme_ui_columns_table(@_) if (defined(&theme_ui_columns_table));
my ($heads, $width, $data, $types, $nosort, $title, $emptymsg, $sortable) = @_;
my $rv;

# Just show empty message if no data
if ($emptymsg && !@$data) {
	$rv .= &ui_subheading($title) if ($title);
	$rv .= "<span class='ui_emptymsg'><b>$emptymsg</b></span><p>\n";
	return $rv;
	}

# Are there any checkboxes in each column? If so, make those columns narrow
my @tds = map { "valign='top'" } @$heads;
my $maxwidth = 0;
foreach my $r (@$data) {
	my $cc = 0;
	foreach my $c (@$r) {
		if (ref($c) &&
		    ($c->{'type'} eq 'checkbox' || $c->{'type'} eq 'radio')) {
			$tds[$cc] .= " width='5'" if ($tds[$cc] !~ /width=/);
			}
		$cc++;
		}
	$maxwidth = $cc if ($cc > $maxwidth);
	}
$rv .= &ui_columns_start($heads, $width, 0, \@tds, $title, $sortable);

# Add the data rows
foreach my $r (@$data) {
	my $c0;
	if (ref($r->[0]) && ($r->[0]->{'type'} eq 'checkbox' ||
			     $r->[0]->{'type'} eq 'radio')) {
		# First column is special
		$c0 = $r->[0];
		$r = [ @$r[1..(@$r-1)] ];
		}
	# Turn data into HTML
	my @rtds = @tds;
	my @cols;
	my $cn = 0;
	$cn++ if ($c0);
	foreach my $c (@$r) {
		if (!ref($c)) {
			# Plain old string
			push(@cols, $c);
			}
		elsif ($c->{'type'} eq 'checkbox') {
			# Checkbox in non-first column
			push(@cols, &ui_checkbox($c->{'name'}, $c->{'value'},
					         $c->{'label'}, $c->{'checked'},
						 $c->{'tags'},
						 $c->{'disabled'}));
			}
		elsif ($c->{'type'} eq 'radio') {
			# Radio button in non-first column
			push(@cols, &ui_oneradio($c->{'name'}, $c->{'value'},
					         $c->{'label'}, $c->{'checked'},
						 $c->{'tags'},
						 $c->{'disabled'}));
			}
		elsif ($c->{'type'} eq 'group') {
			# Header row that spans whole table
			$rv .= &ui_columns_header([ $c->{'desc'} ],
						  [ "colspan=$width" ]);
			next;
			}
		elsif ($c->{'type'} eq 'string') {
			# A string, which might be special
			push(@cols, $c->{'value'});
			if ($c->{'columns'} > 1) {
				splice(@rtds, $cn, $c->{'columns'},
				       "colspan=".$c->{'columns'});
				}
			if ($c->{'nowrap'}) {
				$rtds[$cn] .= " nowrap";
				}
			$rtds[$cn] .= " ".$c->{'td'} if ($c->{'td'});
			}
		$cn++;
		}
	# Add the row
	if (!$c0) {
		$rv .= &ui_columns_row(\@cols, \@rtds);
		}
	elsif ($c0->{'type'} eq 'checkbox') {
		$rv .= &ui_checked_columns_row(\@cols, \@rtds, $c0->{'name'},
					       $c0->{'value'}, $c0->{'checked'},
					       $c0->{'disabled'},
					       $c0->{'tags'});
		}
	elsif ($c0->{'type'} eq 'radio') {
		$rv .= &ui_radio_columns_row(\@cols, \@rtds, $c0->{'name'},
					     $c0->{'value'}, $c0->{'checked'},
					     $c0->{'disabled'},
					     $c0->{'tags'});
		}
	}

$rv .= &ui_columns_end();
return $rv;
}

=head2 ui_form_columns_table(cgi, &buttons, select-all, &otherlinks, &hiddens, &headings, width-percent, &data, &types, no-sort, title, empty-msg, form-no, [sortable])

Similar to ui_columns_table, but wrapped in a form. Parameters are :

=item cgi - URL to submit the form to.

=item buttons - An array ref of buttons at the end of the form, similar to that taken by ui_form_end.

=item select-all - If set to 1, include select all / invert links.

=item otherslinks - An array ref of other links to put at the top of the table, each of which is a 3-element hash ref of url, text and alignment (left or right).

=item hiddens - An array ref of hidden fields, each of which is a 2-element array ref containing the name and value.

=item formno - Index of this form on the page. Defaults to 0, but should be set if there is more than one form on the page.

=item sortable - If set to 1, the table is marked for client-side sorting and searching by themes that support it, as for ui_columns_table.

All other parameters are the same as ui_columns_table.

=cut
sub ui_form_columns_table
{
return &theme_ui_form_columns_table(@_)
	if (defined(&theme_ui_form_columns_table));
my ($cgi, $buttons, $selectall, $others, $hiddens,
       $heads, $width, $data, $types, $nosort, $title, $emptymsg, $formno,
       $sortable) = @_;
my $rv;

# Build links
my @leftlinks = map { "<a href='$_->[0]'>$_->[1]</a>" }
		       grep { $_->[2] ne 'right' } @$others;
my @rightlinks = map { "<a href='$_->[0]'>$_->[1]</a>" }
		       grep { $_->[2] eq 'right' } @$others;
my $links;

# Add select links
if (@$data) {
	if ($selectall) {
		my $cbname;
		foreach my $r (@$data) {
			foreach my $c (@$r) {
				if (ref($c) && $c->{'type'} eq 'checkbox') {
					$cbname = $c->{'name'};
					last;
					}
				}
			}
		if ($cbname) {
			unshift(@leftlinks, &select_all_link($cbname, $formno),
				    &select_invert_link($cbname, $formno));
			}
		}
	}

# Turn to HTML
if (@rightlinks) {
	$links = &ui_grid_table([ &ui_links_row(\@leftlinks),
				  &ui_links_row(\@rightlinks) ], 2, 100,
			        [ undef, "align='right'" ]);
	}
elsif (@leftlinks) {
	$links = &ui_links_row(\@leftlinks);
	}

# Start the form, if we need one
if (@$data) {
	$rv .= &ui_form_start($cgi, "post");
	foreach my $h (@$hiddens) {
		$rv .= &ui_hidden(@$h);
		}
	$rv .= $links;
	}

# Add the table
$rv .= &ui_columns_table($heads, $width, $data, $types, $nosort, $title,
			 $emptymsg, $sortable);

# Add the bottom links unless excluded
if ($selectall != 2) {
	$rv .= $links;
	}

# Add form end
if (@$data) {
	$rv .= &ui_form_end($buttons);
	}

return $rv;
}

####################### form generation functions

=head2 ui_form_elements_wrapper(formdata, formid, [class], [tags])

HTML5 allows to have form elements to be placed outside of an actual
form to provide support for nested forms. The requirement is to have
`id` attribute set on the form and `form` attribute to be set on each
element referencing the given form. This is the wrapper for such form
elements.

=cut
sub ui_form_elements_wrapper
{
return &theme_ui_form_elements_wrapper(@_) if (defined(&theme_ui_form_elements_wrapper));
my ($formdata, $formid, $class, $tags) = @_;
return "<div class='ui_form_elements_wrapper".
           ($class ? " $class" : "")."'".
           ($tags ? " ".$tags : "").">$formdata</div>"
}

=head2 ui_form_start(script, method, [target], [tags])

Returns HTML for the start of a a form that submits to some script. The
parameters are :

=item script - CGI script to submit to, like save.cgi.

=item method - HTTP method, which must be one of 'get', 'post' or 'form-data'. If form-data is used, the target CGI must call ReadParseMime to parse parameters.

=item target - Optional target window or frame for the form.

=item tags - Additional HTML attributes for the form tag.

=cut
sub ui_form_start
{
$ui_formcount ||= 0;
return &theme_ui_form_start(@_) if (defined(&theme_ui_form_start));
my ($script, $method, $target, $tags) = @_;
my $rv;
$rv .= "<form class='ui_form' action='".&html_escape($script)."' ".
	($method eq "post" ? "method='post'" :
	 $method eq "form-data" ?
		"method='post' enctype='multipart/form-data'" :
		"method='get'").
	($target ? " target='$target'" : "").
        ($tags ? " ".$tags : "").">\n";
return $rv;
}

=head2 ui_form_end([&buttons], [width], [nojs])

Returns HTML for the end of a form, optionally with a row of submit buttons.
These are specified by the buttons parameter, which is an array reference
of array refs, with the following elements :

=item HTML value for the submit input for the button, or undef for none.

=item Text to appear on the button.

=item HTML or other inputs to appear after the button.

=item Set to 1 if the button should be disabled.

=item Additional HTML attributes to appear inside the button's input tag.

=item Don't include generated javascript for ui_opt_textbox

=cut
sub ui_form_end
{
$ui_formcount++;
return &theme_ui_form_end(@_) if (defined(&theme_ui_form_end));
my ($buttons, $width, $nojs) = @_;
my $rv;
if ($buttons && @$buttons) {
	$rv .= &_ui_form_end_buttons_table($buttons, $width);
	}
$rv .= "</form>\n";
return $rv.&_ui_form_end_nojs($nojs);
}

=head2 ui_form_end_side_by_side(form-id, [&leftbuttons], [&rightbuttons], [width], [nojs])

Returns HTML for the end of a form with button groups aligned to the left
and right. The left buttons use the same format as ui_form_end and are linked
back to the main form by the HTML5 C<form> attribute, allowing the right side
to contain separate forms or custom HTML without invalid nesting.

=item form-id - HTML id of the form started by ui_form_start.

=item leftbuttons - Buttons for the left side, in the same format as ui_form_end.

=item rightbuttons - Optional buttons or HTML for the right side. Each element
may be either a ui_form_end button array ref or raw HTML.

=item width - Optional CSS width for the action bar. Defaults to 100%.

=item nojs - Set to 1 to suppress ui_opt_textbox re-enable JavaScript.

=cut
sub ui_form_end_side_by_side
{
$ui_formcount++;
return &theme_ui_form_end_side_by_side(@_)
	if (defined(&theme_ui_form_end_side_by_side));
my ($formid, $leftbuttons, $rightbuttons, $width, $nojs) = @_;
my $rv;
$rv .= "</form>\n";
if (($leftbuttons && @$leftbuttons) || ($rightbuttons && @$rightbuttons)) {
	$rv .= &_ui_form_end_side_by_side_css();
	$rv .= "<div class='ui_form_end_side_by_side'".
	       " style='width:".&quote_escape($width || "100%")."'>\n";
	if ($leftbuttons && @$leftbuttons) {
		$rv .= "<div class='ui_form_end_side ui_form_end_side_left'>\n".
		       &_ui_form_end_buttons_table($leftbuttons, undef, $formid,
						   "ui_form_end_buttons_left").
		       "</div>\n";
		}
	if ($rightbuttons && @$rightbuttons) {
		$rv .= "<div class='ui_form_end_side ui_form_end_side_right'>\n".
		       &_ui_form_end_buttons_table($rightbuttons, undef, undef,
						   "ui_form_end_buttons_right").
		       "</div>\n";
		}
	$rv .= "</div>\n";
	}
$rv .= &_ui_form_end_nojs($nojs);
return $rv;
}

=head2 ui_form_grouped_buttons(&groups, [width])

Returns HTML for a responsive row of submit buttons, without closing the form.
Each button uses the same array format as C<ui_form_end>.

Pass an array of button groups. A group can be a normal button list, or a list
of button lists when you want a visible gap between sets of buttons. Groups are
spread across the row when there is room, and wrap on narrow screens. Buttons
inside the same list stay visually joined.

Example :

  my @save_buttons = ([ undef, $text{'save'} ]);
  my @control_buttons = ([ 'start', $text{'start'} ],
                         [ 'stop', $text{'stop'} ]);
  my @delete_buttons = ([ 'delete', $text{'delete'} ]);

  print &ui_form_grouped_buttons([
    [ \@save_buttons, \@control_buttons ],
    \@delete_buttons,
    ]);

=cut
sub ui_form_grouped_buttons
{
return &theme_ui_form_grouped_buttons(@_) if (defined(&theme_ui_form_grouped_buttons));
my ($groups, $width) = @_;
$groups ||= [ ];
my @groups = grep { $_ && ref($_) eq 'ARRAY' && @$_ } @$groups;
return "" if (!@groups);

my %attrs = ( 'class' => 'ui_form_grouped_buttons' );
$attrs{'style'} = "width:$width" if ($width);
my $rv = &_ui_form_grouped_buttons_css();
$rv .= &ui_tag_start('div', \%attrs);
foreach my $group (@groups) {
	$rv .= &_ui_form_grouped_buttons_group($group);
	}
$rv .= &ui_tag_end('div');
return $rv;
}

sub _ui_form_end_buttons_table
{
my ($buttons, $width, $formid, $class) = @_;
return "" if (!$buttons || !@$buttons);
my $rv = "<table class='ui_form_end_buttons".
	 ($class ? " $class" : "")."' ".
	 ($width ? "width='$width'" : "")."><tr>\n";
my $b;
foreach $b (@$buttons) {
	if (ref($b)) {
		my $tags = $b->[4];
		if ($formid && (!$tags || $tags !~ /\bform\s*=/i)) {
			$tags .= ($tags ? " " : "").
				 "form=\"".&quote_escape($formid)."\"";
			}
		$rv .= "<td".(!$width ? "" :
			      $b eq $buttons->[0] ? " align='left'" :
			      $b eq $buttons->[@$buttons-1] ?
				" align='right'" : " align='center'").">".
		       &ui_submit($b->[1], $b->[0], $b->[3], $tags).
		       ($b->[2] ? " ".$b->[2] : "")."</td>\n";
		}
	elsif ($b) {
		$rv .= "<td>$b</td>\n";
		}
	else {
		$rv .= "<td>&nbsp;&nbsp;</td>\n";
		}
	}
$rv .= "</tr></table>\n";
return $rv;
}

sub _ui_form_grouped_buttons_group
{
my ($group) = @_;
my @clusters = &_ui_form_grouped_buttons_clusters($group);
return "" if (!@clusters);
my $rv = &ui_tag_start('div', { 'class' => 'ui_form_grouped_group' });
foreach my $cluster (@clusters) {
	$rv .= &_ui_form_grouped_buttons_cluster($cluster);
	}
$rv .= &ui_tag_end('div');
return $rv;
}

sub _ui_form_grouped_buttons_clusters
{
my ($group) = @_;
return ( ) if (!$group || ref($group) ne 'ARRAY' || !@$group);
foreach my $item (@$group) {
	next if (!defined($item));
	return ref($item) eq 'ARRAY' &&
	       (!@$item || ref($item->[0]) eq 'ARRAY') ?
		grep { $_ && ref($_) eq 'ARRAY' && @$_ } @$group :
		( $group );
	}
return ( );
}

sub _ui_form_grouped_buttons_cluster
{
my ($buttons) = @_;
return "" if (!$buttons || !@$buttons);
my $rv = &ui_tag_start('span', { 'class' => 'ui_form_grouped_cluster' });
foreach my $b (@$buttons) {
	next if (!defined($b));
	if (ref($b)) {
		my $submit = &ui_submit($b->[1], $b->[0], $b->[3], $b->[4]);
		chomp($submit);
		$rv .= $submit;
		$rv .= $b->[2] ? " ".$b->[2] : "";
		}
	elsif ($b) {
		$rv .= $b;
		}
	}
$rv .= &ui_tag_end('span');
return $rv;
}

sub _ui_form_end_side_by_side_css
{
return "" if ($ui_form_end_side_by_side_donecss++);
return <<'EOF';
<style type='text/css'>
.ui_form_end_side_by_side {
	display: flex;
	flex-wrap: wrap;
	align-items: flex-start;
	justify-content: space-between;
	gap: 0 5px;
}
.ui_form_end_side_by_side .ui_form_end_side_left {
	flex: 1 1 auto;
	min-width: 0;
}
.ui_form_end_side_by_side .ui_form_end_side_right {
	flex: 0 0 auto;
}
.ui_form_end_side_by_side .ui_form_end_buttons {
	width: auto;
}
</style>
EOF
}

sub _ui_form_grouped_buttons_css
{
return "" if ($ui_form_grouped_buttons_donecss++);
my $css = <<'EOF';
.ui_form_grouped_buttons {
	display: flex;
	flex-wrap: wrap;
	gap: 0.5em 0.45em;
	align-items: flex-start;
	justify-content: space-between;
	width: 100%;
}
.ui_form_grouped_group {
	display: flex;
	flex-wrap: wrap;
	flex: 0 0 auto;
	align-items: center;
	width: max-content;
	max-width: 100%;
	margin: 0 -0.45em -0.45em 0;
}
.ui_form_grouped_cluster {
	display: flex;
	flex-wrap: wrap;
	align-items: center;
	max-width: 100%;
	margin: 0 0.45em 0 0;
}
.ui_form_grouped_cluster .ui_submit {
	margin: 0 0 0.45em 0;
}
EOF
return &ui_tag('style', $css, { 'type' => 'text/css' });
}

sub _ui_form_end_nojs
{
my ($nojs) = @_;
if ( !$nojs ) {
    # When going back to a form, re-enable any text fields generated by
    # ui_opt_textbox that aren't in the default state.
    my $rv = "<script type='text/javascript'>\n";
    $rv .= "(function () {\n";
    $rv .= "const opts = document.getElementsByClassName('ui_opt_textbox');\n";
    $rv .= "for(let i=0; i<opts.length; i++) {\n";
    $rv .= "  opts[i].disabled = document.getElementsByName(opts[i].name+'_def')[0].checked;\n";
    $rv .= "}\n";
    $rv .= "})();\n";
    $rv .= "</script>\n";
    return $rv;
    }
return "";
}

=head2 ui_textbox(name, value, size, [disabled?], [maxlength], [tags], [class])

Returns HTML for a text input box. The parameters are :

=item name - Name for this input.

=item value - Initial contents for the text box.

=item size - Desired width in characters.

=item disabled - Set to 1 if this text box should be disabled by default.

=item maxlength - Maximum length of the string the user is allowed to input.

=item tags - Additional HTML attributes for the <input> tag.

=cut
sub ui_textbox
{
return &theme_ui_textbox(@_) if (defined(&theme_ui_textbox));
my ($name, $value, $size, $dis, $max, $tags, $cls) = @_;
$cls ||= "";
$cls = " $cls" if ($cls);
$size = &ui_max_text_width($size);
return "<input class='ui_textbox$cls' type='text' ".
       "name=\"".&html_escape($name)."\" ".
       "id=\"".&html_escape($name)."\" ".
       "value=\"".&html_escape($value)."\" ".
       "size='$size'".($dis ? " disabled='true'" : "").
       ($max ? " maxlength='$max'" : "").
       ($tags ? " ".$tags : "").">";
}

=head2 ui_filebox(name, value, size, [disabled?], [maxlength], [tags], [dir-only])

Returns HTML for a text box for choosing a file. Parameters are the same
as ui_textbox, except for the extra dir-only option which limits the chooser
to directories.

=cut
sub ui_filebox
{
return &theme_ui_filebox(@_) if (defined(&theme_ui_filebox));
my ($name, $value, $size, $dis, $max, $tags, $dironly) = @_;
return &ui_textbox($name, $value, $size, $dis, $max, $tags)."&nbsp;".
       &file_chooser_button($name, $dironly);
}

=head2 ui_bytesbox(name, bytes, [size], [disabled?])

Returns HTML for entering a number of bytes, but with friendly kB/MB/GB
options. May truncate values to 2 decimal points! The parameters are :

=item name - Name for this input.

=item bytes - Initial number of bytes to show.

=item size - Desired width of the text box part.

=item disabled - Set to 1 if this text box should be disabled by default.

=item tags - Additional HTML attributes for the <input> tag.

=item defaultunits - Units mode selected by default

=cut
sub ui_bytesbox
{
my ($name, $bytes, $size, $dis, $tags, $defaultunits) = @_;
my $units = 1;
my $omorfi_unit;

if ($bytes eq '' && $defaultunits) {
	$units = $defaultunits;
	}
else {
	for(my $i=1; $i<=4; $i++) {
		my $u = 1024**$i;
		if ($bytes >= $u) {
			$units = $u;
			$omorfi_unit = $units
				if ($bytes % $u == 0 && $bytes/$u <= $u);
			}
		}
	$units = $omorfi_unit
		if ($omorfi_unit && $bytes*4 % $units != 0);
	}
if ($bytes ne "") {
	$bytes = sprintf("%.2f", ($bytes*1.0)/$units);
	$bytes =~ s/\.00$//;
	# Remove trailing zeros in decimal part
	$bytes =~ s/(\.\d*?[1-9])0+$/$1/;
	}
$size = &ui_max_text_width($size || 8);
return &ui_textbox($name, $bytes, $size, $dis, undef, $tags)." ".
       &ui_select($name."_units", $units,
		 [ [ 1, $text{"nice_size_b"} ],
		   [ 1024, $text{"nice_size_kiB"} ],
		   [ 1024*1024, $text{"nice_size_MiB"} ],
		   [ 1024*1024*1024, $text{"nice_size_GiB"} ],
		   [ 1024*1024*1024*1024, $text{"nice_size_TiB"} ],
		   [ 1024*1024*1024*1024*1024, $text{"nice_size_PiB"} ] ], undef, undef, undef, $dis);
}

=head2 ui_upload(name, size, [disabled?], [tags])

Returns HTML for a file upload input, for use in a form with the form-data
method. The parameters are :

=item name - Name for this input.

=item size - Desired width in characters.

=item disabled - Set to 1 if this text box should be disabled by default.

=item tags - Additional HTML attributes for the <input> tag.

=item multiple - Set to 1 to allow uploading of multiple files

=cut
sub ui_upload
{
return &theme_ui_upload(@_) if (defined(&theme_ui_upload));
my ($name, $size, $dis, $tags, $multiple) = @_;
$size = &ui_max_text_width($size);
return "<input class='ui_upload' type='file' ".
       "name=\"".&quote_escape($name)."\" ".
       "id=\"".&quote_escape($name)."\" ".
       "size='$size'".
       ($dis ? " disabled='true'" : "").
       ($multiple ? " multiple" : "").
       ($tags ? " ".$tags : "").">";
}

=head2 ui_password(name, value, size, [disabled?], [maxlength], [tags])

Returns HTML for a password text input. Parameters are the same as ui_textbox,
and behaviour is identical except that the user's input is not visible.

=cut
sub ui_password
{
return &theme_ui_password(@_) if (defined(&theme_ui_password));
my ($name, $value, $size, $dis, $max, $tags) = @_;
$size = &ui_max_text_width($size);
return "<input class='ui_password' type='password' ".
       "name=\"".&quote_escape($name)."\" ".
       "id=\"".&quote_escape($name)."\" ".
       ($value ne "" ? "value=\"".&quote_escape($value)."\" " : "").
       "size='$size'".($dis ? " disabled='true'" : "").
       ($max ? " maxlength='$max'" : "").
       ($tags ? " ".$tags : "").">";
}

=head2 ui_hidden(name, value, [formid])

Returns HTML for a hidden field with the given name and value.

=cut
sub ui_hidden
{
return &theme_ui_hidden(@_) if (defined(&theme_ui_hidden));
my ($name, $value, $formid) = @_;
return "<input class='ui_hidden' type='hidden' ".
       "name=\"".&quote_escape($name)."\" ".
       "id=\"".&quote_escape($name)."\" ".
       "value=\"".&quote_escape($value)."\"".
       ($formid ? " form=\"$formid\"" : "").">\n";
}

=head2 ui_select(name, value|&values, &options, [size], [multiple], [add-if-missing], [disabled?], [tags])

Returns HTML for a drop-down menu or multiple selection list. The parameters
are :

=item name - Name for this input.

=item value - Either a single initial value, or an array reference of values if this is a multi-select list.

=item options - An array reference of possible options. Each element can either be a scalar, or a two-element array ref containing a submitted value and displayed text.

=item size - Desired vertical size in rows, which defaults to 1. For multi-select lists, this must be set to something larger.

=item multiple - Set to 1 for a multi-select list, 0 for single.

=item add-if-missing - If set to 1, any value that is not in the list of options will be automatically added (and selected).

=item disabled - Set to 1 to disable this input.

=item tags - Additional HTML attributes for the <select> input.

=cut
sub ui_select
{
return &theme_ui_select(@_) if (defined(&theme_ui_select));
my ($name, $value, $opts, $size, $multiple, $missing, $dis, $tags) = @_;
my $rv;
$rv .= "<select class='ui_select' ".
       "name=\"".&quote_escape($name)."\" ".
       "id=\"".&quote_escape($name)."\" ".
       ($size ? " size='$size'" : "").
       ($multiple ? " multiple" : "").
       ($dis ? " disabled=true" : "").($tags ? " ".$tags : "").">\n";
my ($o, %opt, $s);
my %sel = ref($value) ? ( map { $_, 1 } @$value ) : ( $value, 1 );
foreach $o (@$opts) {
	$o = [ $o ] if (!ref($o));
	$rv .= "<option value=\"".&quote_escape($o->[0])."\"".
	       ($sel{$o->[0]} ? " selected" : "").($o->[2] ne '' ? " ".$o->[2] : "").">".
	       &html_escape($o->[1] || $o->[0], 1)."</option>\n";
	$opt{$o->[0]}++;
	}
foreach $s (keys %sel) {
	if (!$opt{$s} && $missing) {
		$rv .= "<option value=\"".&quote_escape($s)."\"".
		       " selected>".($s eq "" ? "&nbsp;" : &html_escape($s, 1))."</option>\n";
		}
	}
$rv .= "</select>\n";
return $rv;
}

=head2 ui_multi_select(name, &values, &options, size, [add-if-missing], [disabled?], [options-title, values-title], [width])

Returns HTML for selecting many of many from a list. By default, this is
implemented using two <select> lists and Javascript buttons to move elements
between them. The resulting input value is \n separated.

Parameters are :

=item name - HTML name for this input.

=item values - An array reference of two-element array refs, containing the submitted values and descriptions of items that are selected by default.

=item options - An array reference of two-element array refs, containing the submitted values and descriptions of items that the user can select from.

=item size - Vertical size in rows.

=item add-if-missing - If set to 1, any entries that are in values but not in options will be added automatically.

=item disabled - Set to 1 to disable this input by default.

=item options-title - Optional text to appear above the list of options.

=item values-title - Optional text to appear above the list of selected values.

=item width - Optional width of the two lists in pixels.

=cut
sub ui_multi_select
{
return &theme_ui_multi_select(@_) if (defined(&theme_ui_multi_select));
my ($name, $values, $opts, $size, $missing, $dis,
       $opts_title, $vals_title, $width) = @_;
my $rv;
my %already = map { $_->[0], $_ } @$values;
my $leftover = [ grep { !$already{$_->[0]} } @$opts ];
if ($missing) {
	my %optsalready = map { $_->[0], $_ } @$opts;
	push(@$opts, grep { !$optsalready{$_->[0]} } @$values);
	}
if (!defined($width)) {
	$width = "200";
	}
$width .= "px" if ($width =~ /^\d+$/);
my $wstyle = $width ? "style='min-width:$width'" : "";

if (!$main::ui_multi_select_donejs++) {
	$rv .= &ui_multi_select_javascript();
	}
$rv .= "<table cellpadding=0 cellspacing=0 class='ui_multi_select'>";
if (defined($opts_title)) {
	$rv .= "<tr class='ui_multi_select_heads'>".
	       "<td><b>$opts_title</b></td> ".
	       "<td></td><td><b>$vals_title</b></td></tr>";
	}
$rv .= "<tr class='ui_multi_select_row'>";
$rv .= "<td>".&ui_select($name."_opts", [ ], $leftover,
			 $size, 1, 0, $dis, $wstyle)."</td>\n";
$rv .= "<td>".&ui_button("&#x25B6;", $name."_add", $dis,
		 "onClick='multi_select_move(\"$name\", form, 1)'")."<br>".
	      &ui_button("&#x25C0;", $name."_remove", $dis,
		 "onClick='multi_select_move(\"$name\", form, 0)'")."</td>\n";
$rv .= "<td>".&ui_select($name."_vals", [ ], $values,
			 $size, 1, 0, $dis, $wstyle)."</td>\n";
$rv .= "</tr></table>\n";
$rv .= &ui_hidden($name, join("\n", map { $_->[0] } @$values));
return $rv;
}

=head2 ui_multi_select_javascript

Returns <script> section for left/right select boxes. For internal use only.

=cut
sub ui_multi_select_javascript
{
return &theme_ui_multiselect_javascript()
	if (defined(&theme_ui_multiselect_javascript));
return <<EOF;
<script type='text/javascript'>
// Move an element from the options list to the values list, or vice-versa
function multi_select_move(name, f, dir)
{
var opts = f.elements[name+"_opts"];
var vals = f.elements[name+"_vals"];
var opts_idx = opts.selectedIndex;
var vals_idx = vals.selectedIndex;
if (dir == 1 && opts_idx >= 0) {
	// Moving from options to selected list
	for(var i=0; i<opts.options.length; i++) {
		var o = opts.options[i];
		if (o.selected) {
			o.selected = false;
			vals.add(o, 0);
			i--;
			}
		}
	}
else if (dir == 0 && vals_idx >= 0) {
	// Moving the other way
	for(var i=0; i<vals.options.length; i++) {
		var o = vals.options[i];
		if (o.selected) {
			o.selected = false;
			opts.add(o, 0);
			i--;
			}
		}
	}
// Fill in hidden field
var hid = f.elements[name];
if (hid) {
	var hv = new Array();
	for(var i=0; i<vals.options.length; i++) {
		hv.push(vals.options[i].value);
		}
	hid.value = hv.join("\\n");
	}
}
</script>
EOF
}

=head2 ui_radio(name, value, &options, [disabled?])

Returns HTML for a series of radio buttons, of which one can be selected. The
parameters are :

=item name - HTML name for the radio buttons.

=item value - Value of the button that is selected by default.

=item options - Array ref of radio button options, each of which is an array ref containing the submitted value and description for each button.

=item disabled - Set to 1 to disable all radio buttons by default.

=cut
sub ui_radio
{
return &theme_ui_radio(@_) if (defined(&theme_ui_radio));
my ($name, $value, $opts, $dis) = @_;
my $rv;
my $o;
foreach $o (@$opts) {
	my $id = &quote_escape($name."_".$o->[0]);
	my $label = $o->[1] || $o->[0];
	my $after;
	if ($label =~ /^([\000-\377]*?)((<a\s+href|<input|<select|<textarea|<span|<br|<p)[\000-\377]*)$/i) {
		$label = $1;
		$after = $2;
		}
	$rv .= "<input class='ui_radio' type='radio' ".
	       "name=\"".&quote_escape($name)."\" ".
               "value=\"".&quote_escape($o->[0])."\"".
	       ($o->[0] eq $value ? " checked" : "").
	       ($dis ? " disabled='true'" : "").
	       " id=\"$id\"".
	       ($o->[2] ? " ".$o->[2] : "")."> <label for=\"$id\">".
	       $label."</label>".$after."\n";
	}
return $rv;
}

=head2 ui_yesno_radio(name, value, [yes], [no], [disabled?])

Like ui_radio, but always displays just two inputs (yes and no). The parameters
are :

=item name - HTML name of the inputs.

=item value - Option selected by default, typically 1 or 0.

=item yes - The value for the yes option, defaulting to 1.

=item no - The value for the no option, defaulting to 0.

=item disabled - Set to 1 to disable all radio buttons by default.

=cut
sub ui_yesno_radio
{
my ($name, $value, $yes, $no, $dis) = @_;
return &theme_ui_yesno_radio(@_) if (defined(&theme_ui_yesno_radio));
$yes = 1 if (!defined($yes));
$no = 0 if (!defined($no));
if ( $value =~ /^[0-9,.E]+$/ || !$value) {
        $value = int($value);
}
return &ui_radio($name, $value, [ [ $yes, $text{'yes'} ],
				  [ $no, $text{'no'} ] ], $dis);
}

=head2 ui_radio_row(name, value, &arrref, [new-line])

Radio buttons, with a HTML elements places after each one, and
dependent HTML elements disabled if the radio button is not selected.

=item name - HTML name of the inputs.

=item value - Option selected by default, typically 1 or 0.

=item array reference of elements, each containing a submited value and displayed HTML.

Array reference of elements, each containing:

  1. The value for the radio button
  2. An array reference of HTML elements to be displayed after the radio button
    2.1. A label for the radio button
    2.2. A list (array) of HTML elements to be displayed after the radio button

=item newline - Set to 1 to start a new line after each radio button.

=cut
sub ui_radio_row
{
return &theme_ui_radio_row(@_) if (defined(&theme_ui_radio_row));
my ($name, $value, $arrref, $newline) = @_;
$newline = "<br>" if ($newline == 1);
my $id = &substitute_pattern('[a-f0-9]{20}');
my $rv = "<span class='ui_radio_row_wrap ui_radio_row_wrap_${id}'>";
for (my $i = 0; $i < @$arrref; $i++) {
	$rv .= &ui_radio($name, $value, [ [ $arrref->[$i]->[0], $arrref->[$i]->[1]->[0] ] ], $dis);
	shift @{$arrref->[$i]->[1]};
	my $arrref_html = join('', map { "<span class='ui_radio_row_inner_${i}'>$_</span>" }
		@{$arrref->[$i]->[1]});
	$rv .= "<span class='ui_radio_row ui_radio_row_$arrref->[$i]->[0]'>".
	 		$arrref_html.
	 	"</span>" if ($arrref->[$i]->[1]->[0]);
	$rv .= $newline;
	}
$rv .= "</span>";
my $js = <<EOF;
<script type='text/javascript'>
!function(){const e="ui_radio_row",t='[type="radio"]',n=document.querySelector("."+e+"_wrap_$id"),c=n.querySelectorAll("input"+t),o=n.querySelector("input"+t+":checked"),i=new Event("input");c.forEach((function(c){c.addEventListener("input",(function(){n.querySelectorAll("select, input:not("+t+")").forEach((function(e){e.disabled=!1})),c.checked&&n.querySelectorAll("."+e+":not(."+e+"_"+this.value+") select, ."+e+":not(."+e+"_"+this.value+") input:not("+t+")").forEach((function(e){e.disabled=!0}))}))})),o.dispatchEvent(i)}();
</script>
EOF
return $rv.$js;
}

=head2 ui_checkbox(name, value, label, selected?, [tags], [disabled?])

Returns HTML for a single checkbox. Parameters are :

=item name - HTML name of the checkbox.

=item value - Value that will be submitted if it is checked.

=item label - Text to appear next to the checkbox.

=item selected - Set to 1 for it to be checked by default.

=item tags - Additional HTML attributes for the <input> tag.

=item disabled - Set to 1 to disable the checkbox by default.

=cut
sub ui_checkbox
{
return &theme_ui_checkbox(@_) if (defined(&theme_ui_checkbox));
my ($name, $value, $label, $sel, $tags, $dis) = @_;
my $after;
if ($label =~ /^([^<]*)(<[\000-\377]*)$/) {
	$label = $1;
	$after = $2;
	}
return "<input class='ui_checkbox' type='checkbox' ".
       "name=\"".&quote_escape($name)."\" ".
       "value=\"".&quote_escape($value)."\" ".
       ($sel ? " checked" : "").($dis ? " disabled='true'" : "").
       " id=\"".&quote_escape("${name}_${value}")."\"".
       ($tags ? " ".$tags : "")."> ".
       ($label eq "" ? $after :
	 "<label for=\"".&quote_escape("${name}_${value}").
	 "\">$label</label>$after")."\n";
}

=head2 ui_oneradio(name, value, label, selected?, [tags], [disabled?])

Returns HTML for a single radio button. The parameters are :

=item name - HTML name of the radio button.

=item value - Value that will be submitted if it is selected.

=item label - Text to appear next to the button.

=item selected - Set to 1 for it to be selected by default.

=item tags - Additional HTML attributes for the <input> tag.

=item disabled - Set to 1 to disable the radio button by default.

=cut
sub ui_oneradio
{
return &theme_ui_oneradio(@_) if (defined(&theme_ui_oneradio));
my ($name, $value, $label, $sel, $tags, $dis) = @_;
my $id = &quote_escape("${name}_${value}");
my $after;
if ($label =~ /^([^<]*)(<[\000-\377]*)$/) {
	$label = $1;
	$after = $2;
	}
my $ret = "<input class='ui_radio' type='radio' name=\"".&quote_escape($name)."\" ".
       "value=\"".&quote_escape($value)."\" ".
       ($sel ? " checked" : "").($dis ? " disabled='true'" : "").
       " id=\"$id\"".
       ($tags ? " ".$tags : "").">";
    $ret .= " <label for=\"$id\">$label</label>" if ($label ne '');
    $ret .= "$after\n";
    return $ret;
}

=head2 ui_textarea(name, value, rows, cols, [wrap], [disabled?], [tags])

Returns HTML for a multi-line text input. The function parameters are :

=item name - Name for this HTML <textarea>.

=item value - Default value. Multiple lines must be separated by \n.

=item rows - Number of rows, in lines.

=item cols - Number of columns, in characters.

=item wrap - Wrapping mode. Can be one of soft, hard or off.

=item disabled - Set to 1 to disable this text area by default.

=item tags - Additional HTML attributes for the <textarea> tag.

=cut
sub ui_textarea
{
return &theme_ui_textarea(@_) if (defined(&theme_ui_textarea));
my ($name, $value, $rows, $cols, $wrap, $dis, $tags) = @_;
$cols = &ui_max_text_width($cols, 1);
return "<textarea class='ui_textarea' ".
       "name=\"".&quote_escape($name)."\" ".
       "id=\"".&quote_escape($name)."\" ".
       "rows='$rows' cols='$cols'".($wrap ? " wrap='$wrap'" : "").
       ($dis ? " disabled='true'" : "").
       ($tags ? " $tags" : "").">".
       &html_escape($value).
       "</textarea>";
}

=head2 ui_user_textbox(name, value, [form], [disabled?], [tags])

Returns HTML for an input for selecting a Unix user. Parameters are the
same as ui_textbox.

=cut
sub ui_user_textbox
{
my ($name, $value, $form, $dis, $tags) = @_;
return &theme_ui_user_textbox(@_) if (defined(&theme_ui_user_textbox));
return &ui_textbox($name, $value, 13, $dis, undef, $tags)." ".
       &user_chooser_button($name, 0, $form);
}

=head2 ui_users_textbox(name, value, [form], [disabled?], [tags])

Returns HTML for an input for selecting multiple Unix users. Parameters are the
same as ui_textbox.

=cut
sub ui_users_textbox
{
my ($name, $value, $form, $dis, $tags) = @_;
return &theme_ui_users_textbox(@_) if (defined(&theme_ui_users_textbox));
return &ui_textbox($name, $value, 60, $dis, undef, $tags)." ".
       &user_chooser_button($name, 1, $form);
}

=head2 ui_group_textbox(name, value, [form], [disabled?], [tags])

Returns HTML for an input for selecting a Unix group. Parameters are the
same as ui_textbox.

=cut
sub ui_group_textbox
{
my ($name, $value, $form, $dis, $tags) = @_;
return &theme_ui_group_textbox(@_) if (defined(&theme_ui_group_textbox));
return &ui_textbox($name, $value, 13, $dis, undef, $tags)." ".
       &group_chooser_button($name, 0, $form);
}

=head2 ui_groups_textbox(name, value, [form], [disabled?], [tags])

Returns HTML for an input for selecting Unix groups. Parameters are the
same as ui_textbox.

=cut
sub ui_groups_textbox
{
my ($name, $value, $form, $dis, $tags) = @_;
return &theme_ui_groups_textbox(@_) if (defined(&theme_ui_groups_textbox));
return &ui_textbox($name, $value, 60, $dis, undef, $tags)." ".
       &group_chooser_button($name, 1, $form);
}

=head2 ui_opt_textbox(name, value, size, option1, [option2], [disabled?], [&extra-fields], [max])

Returns HTML for a text field that is optional, implemented by default as
a field with radio buttons next to it. The parameters are :

=item name - HTML name for the text box. The radio buttons will have the same name, but with _def appended.

=item value - Initial value, or undef if you want the default radio button selected initially.

=item size - Width of the text box in characters.

=item option1 - Text for the radio button for selecting that no input is being given, such as 'Default'.

=item option2 - Text for the radio button for selecting that you will provide input.

=item disabled - Set to 1 to disable this input by default.

=item extra-fields - An optional array ref of field names that should be disabled by Javascript when this field is disabled.

=item max - Optional maximum allowed input length, in characters.

=item tags - Additional HTML attributes for the text box

=item type - HTML input type, which defaults to "text"

=cut
sub ui_opt_textbox
{
return &theme_ui_opt_textbox(@_) if (defined(&theme_ui_opt_textbox));
my ($name, $value, $size, $opt1, $opt2, $dis, $extra, $max, $tags, $type) = @_;
$type ||= "text";
my $dis1 = &js_disable_inputs([ $name, @$extra ], [ ]);
my $dis2 = &js_disable_inputs([ ], [ $name, @$extra ]);
my $rv;
$size = &ui_max_text_width($size);
$rv .= &ui_radio($name."_def", $value eq '' ? 1 : 0,
		 [ [ 1, $opt1, "onClick='$dis1'" ],
		   [ 0, $opt2 || " ", "onClick='$dis2'" ] ], $dis)."\n";
$rv .= "<input class='ui_opt_textbox' type='$type' ".
       "name=\"".&quote_escape($name)."\" ".
       "id=\"".&quote_escape($name)."\" ".
       "size=$size value=\"".&quote_escape($value)."\"".
       ($dis ? " disabled='true'" : "").
       ($max ? " maxlength='$max'" : "").
       ($tags ? " ".$tags : "").">";
return $rv;
}

=head2 ui_submit(label, [name], [disabled?], [tags])

Returns HTML for a form submit button. Parameters are :

=item label - Text to appear on the button.

=item name - Optional HTML name for the button. Useful if the CGI it submits to needs to know which of several buttons was clicked.

=item disabled - Set to 1 if this button should be disabled by default.

=item tags - Additional HTML attributes for the <input> tag.

=cut
sub ui_submit
{
return &theme_ui_submit(@_) if (defined(&theme_ui_submit));
my ($label, $name, $dis, $tags) = @_;
return "<input class='ui_submit' type='submit'".
       ($name ne '' ? " name=\"".&quote_escape($name)."\"" : "").
       ($name ne '' ? " id=\"".&quote_escape($name)."\"" : "").
       " value=\"".&quote_escape($label)."\"".
       ($dis ? " disabled='true'" : "").
       ($tags ? " ".$tags : "").">\n";
}

=head2 ui_reset(label, [disabled?], [tags])

Returns HTML for a form reset button, which clears all fields when clicked.
Parameters are :

=item label - Text to appear on the button.

=item disabled - Set to 1 if this button should be disabled by default.

=item tags - Additional HTML attributes for the <input> tag.

=cut
sub ui_reset
{
return &theme_ui_reset(@_) if (defined(&theme_ui_reset));
my ($label, $dis, $tags) = @_;
return "<input class='ui_reset' type='reset' value=\"".&quote_escape($label)."\"".
       ($dis ? " disabled='true'" : "").
       ($tags ? " ".$tags : "").">\n";
}

=head2 ui_button(label, [name], [disabled?], [tags])

Returns HTML for a form button, which doesn't do anything when clicked unless
you add some Javascript to it. The parameters are :

=item label - Text to appear on the button.

=item name - HTML name for this input.

=item disabled - Set to 1 if this button should be disabled by default.

=item tags - Additional HTML attributes for the <input> tag, typically Javascript inside an onClick attribute.

=cut
sub ui_button
{
return &theme_ui_button(@_) if (defined(&theme_ui_button));
my ($label, $name, $dis, $tags) = @_;
return "<input class='ui_button' type='button'".
       ($name ne '' ? " name=\"".&quote_escape($name)."\"" : "").
       ($name ne '' ? " id=\"".&quote_escape($name)."\"" : "").
       " value=\"".&quote_escape($label)."\"".
       ($dis ? " disabled='true'" : "").
       ($tags ? " ".$tags : "").">\n";
}

=head2 ui_date_input(day, month, year, day-name, month-name, year-name, [disabled?])

Returns HTML for a date-selection field, with day, month and year inputs.
The parameters are :

=item day - Initial day of the month.

=item month - Initial month of the year, indexed from 1.

=item year - Initial year, four-digit.

=item day-name - Name of the day input field.

=item month-name - Name of the month select field.

=item year-name - Name of the year input field.

=item disabled - Set to 1 to disable all fields by default.

=cut
sub ui_date_input
{
return &theme_ui_date_input(@_) if (defined(&theme_ui_date_input));
my ($day, $month, $year, $dayname, $monthname, $yearname, $dis) = @_;
my $rv;
$rv .= "<span class='ui_data'>";
$rv .= &ui_textbox($dayname, $day, 3, $dis);
$rv .= "/";
$rv .= &ui_select($monthname, $month,
		  [ map { [ $_, $text{"smonth_$_"} ] } (1 .. 12) ],
		  1, 0, 0, $dis);
$rv .= "/";
$rv .= &ui_textbox($yearname, $year, 5, $dis);
$rv .= "</span>";
return $rv;
}

=head2 ui_buttons_start

Returns HTML for the start of a block of action buttons with descriptions, as
generated by ui_buttons_row. Some example code :

  print ui_buttons_start();
  print ui_buttons_row('start.cgi', 'Start server',
                       'Click this button to start the server process');
  print ui_buttons_row('stop.cgi', 'Stop server',
                       'Click this button to stop the server process');
  print ui_buttons_end();

=cut
sub ui_buttons_start
{
return &theme_ui_buttons_start(@_) if (defined(&theme_ui_buttons_start));
return "<table width='100%' class='ui_buttons_table'>\n";
}

=head2 ui_buttons_end

Returns HTML for the end of a block started by ui_buttons_start.

=cut
sub ui_buttons_end
{
return &theme_ui_buttons_end(@_) if (defined(&theme_ui_buttons_end));
return "</table>\n";
}

=head2 ui_buttons_row(script, button-label, description, [hiddens], [after-submit], [before-submit], [postmethod], [single-cell], [disabled])

Returns HTML for a button with a description next to it, and perhaps other
inputs. The parameters are :

=item script - CGI script that this button submits to, like start.cgi.

=item button-label - Text to appear on the button.

=item description - Text to appear next to the button, describing in more detail what it does.

=item hiddens - HTML for hidden fields to include in the form this function generates.

=item after-submit - HTML for text or inputs to appear after the submit button.

=item before-submit - HTML for text or inputs to appear before the submit button.

=item postmethod - Defines the method used to submit the form. Defaults to 'post'.

=item single-cell - If set to 1, omits the description cell and spans the button cell across both columns.

=item disabled - If set to 1, disables the submit button.

=cut
sub ui_buttons_row
{
return &theme_ui_buttons_row(@_) if (defined(&theme_ui_buttons_row));
my ($script, $label, $desc, $hiddens, $after, $before, $postmethod,
    $singlecell, $disabled) = @_;
$postmethod ||= 'post';
if (ref($hiddens)) {
	$hiddens = join("\n", map { &ui_hidden(@$_) } @$hiddens);
	}
return "<form action='$script' class='ui_buttons_form' method='$postmethod'>\n".
       $hiddens.
       "<tr class='ui_buttons_row".($disabled ? " disabled" : "")."'> ".
       "<td nowrap".($singlecell ? " colspan='2'" : " width='20%'").
       " valign='top' class='ui_buttons_label'>".
       ($before ? $before." " : "").
       &ui_submit($label, '', $disabled).
       ($after ? " ".$after : "")."</td>\n".
       ($singlecell ? "" :
        "<td width='80%' valign='top' class='ui_buttons_value'>".
        $desc."</td>\n").
       "</tr>\n".
       "</form>\n";
}

=head2 ui_buttons_hr([title])

Returns HTML for a separator row, for use inside a ui_buttons_start block.

=cut
sub ui_buttons_hr
{
my ($title) = @_;
return &theme_ui_buttons_hr(@_) if (defined(&theme_ui_buttons_hr));
if ($title) {
	return "<tr class='ui_buttons_hr'><td colspan='2'><table cellpadding='0' cellspacing='0' width='100%'><tr><td width='50%'><hr></td><td nowrap>$title</td><td width='50%'><hr></td></tr></table></td></tr>\n";
	}
else {
	return "<tr class='ui_buttons_hr'><td colspan='2'><hr></td></tr>\n";
	}
}

####################### header and footer functions

=head2 ui_post_header([subtext])

Returns HTML to appear directly after a standard header() call. This is never
called directly - instead, ui_print_header calls it. But it can be overridden
by themes.

=cut
sub ui_post_header
{
return &theme_ui_post_header(@_) if (defined(&theme_ui_post_header));
my ($text) = @_;
my $rv;
$rv .= "<center class='ui_post_header'><font size='+1'>$text</font></center>\n" if (defined($text));
if (!$tconfig{'nohr'} && !$tconfig{'notophr'}) {
	$rv .= "<hr id='post_header_hr'>\n";
	}
return $rv;
}

=head2 ui_pre_footer

Returns HTML to appear directly before a standard footer() call. This is never
called directly - instead, ui_print_footer calls it. But it can be overridden
by themes.

=cut
sub ui_pre_footer
{
return &theme_ui_pre_footer(@_) if (defined(&theme_ui_pre_footer));
my $rv;
if (!$tconfig{'nohr'} && !$tconfig{'nobottomhr'}) {
	$rv .= "<hr id='pre_footer_hr'>\n";
	}
return $rv;
}

=head2 ui_print_header(subtext, title, image, [help], [config], [nomodule], [nowebmin], [rightside], [head-stuff], [body-stuff], [below])

Print HTML for a header with the post-header line. The args are the same
as those passed to header(), defined in web-lib-funcs.pl, with the addition
of the subtext parameter :

=item subtext - Text to display below the title

=item title - The text to show at the top of the page

=item image - An image to show instead of the title text. This is typically left blank.

=item help - If set, this is the name of a help page that will be linked to in the title.

=item config - If set to 1, the title will contain a link to the module's config page.

=item nomodule - If set to 1, there will be no link in the title section to the module's index.

=item nowebmin - If set to 1, there will be no link in the title section to the Webmin index.

=item rightside - HTML to be shown on the right-hand side of the title. Can contain multiple lines, separated by <br>. Typically this is used for links to stop, start or restart servers.

=item head-stuff - HTML to be included in the <head> section of the page.

=item body-stuff - HTML attributes to be include in the <body> tag.

=item below - HTML to be displayed below the title. Typically this is used for application or server version information.

=cut
sub ui_print_header
{
&load_theme_library();
return &theme_ui_print_header(@_) if (defined(&theme_ui_print_header));
my ($text, @args) = @_;
&header(@args);
print &ui_post_header($text);
}

=head2 ui_print_unbuffered_header(subtext, args...)

Like ui_print_header, but ensures that output for this page is not buffered
or contained in a table. This should be called by scripts that are producing
output while performing some long-running process.

=cut
sub ui_print_unbuffered_header
{
my @args = @_;
&load_theme_library();
return &theme_ui_print_unbuffered_header(@args)
	if (defined(&theme_ui_print_unbuffered_header));
$| = 1;
$theme_no_table = 1;
$args[9] .= " " if ($args[9]);
$args[9] .= " data-pagescroll=true";
&ui_print_header(@args);
}

=head2 ui_print_footer(args...)

Print HTML for a footer with the pre-footer line. Args are the same as those
passed to footer().

=cut
sub ui_print_footer
{
return &theme_ui_print_footer(@_) if (defined(&theme_ui_print_footer));
my @args = @_;
print &ui_pre_footer();
&footer(@args);
}

=head2 ui_config_link(text, &subs)

Returns HTML for a module config link. The first non-null sub will be
replaced with the appropriate URL for the module's config page.

=cut
sub ui_config_link
{
return &theme_ui_config_link(@_) if (defined(&theme_ui_config_link));
my ($text, $subs) = @_;
my $m = &get_module_name();
my @subs = map { $_ || "../config.cgi?$m" }
		  ($subs ? @$subs : ( undef ));
return "<p>".&text($text, @subs)."<p>\n";
}

=head2 ui_print_endpage(text)

Prints HTML for an error message followed by a page footer with a link to
/, then exits. Good for main page error messages.

=cut
sub ui_print_endpage
{
return &theme_ui_print_endpage(@_) if (defined(&theme_ui_print_endpage));
my ($text) = @_;
print $text,"<p class='ui_footer'>\n";
print "</p>\n";
&ui_print_footer("/", $text{'index'});
exit;
}

=head2 ui_subheading(text, ...)

Returns HTML for a section heading whose message is the given text strings.

=cut
sub ui_subheading
{
return &theme_ui_subheading(@_) if (defined(&theme_ui_subheading));
return "<h3 class='ui_subheading'>".join("", @_)."</h3>\n";
}

=head2 ui_links_row(&links)

Returns HTML for a row of links, like select all / invert selection / add..
Each element of the links array ref should be an HTML fragment like :

  <a href='user_form.cgi'>Create new user</a>

=cut
sub ui_links_row
{
return &theme_ui_links_row(@_) if (defined(&theme_ui_links_row));
my ($links) = @_;
return @$links ? join("\n|\n", @$links)."<br>\n"
	       : "";
}

########################### collapsible section / tab functions

=head2 ui_hidden_javascript

Returns <script> and <style> sections for hiding functions and CSS. For
internal use only.

=cut
sub ui_hidden_javascript
{
return &theme_ui_hidden_javascript(@_)
	if (defined(&theme_ui_hidden_javascript));
my $rv;
my $imgdir = "@{[&get_webprefix()]}/images";
my ($jscb, $jstb) = ($cb, $tb);
$jscb =~ s/'/\\'/g;
$jstb =~ s/'/\\'/g;

return <<EOF;
<style type='text/css'>
.opener_shown {display:inline}
.opener_hidden {display:none}
</style>
<script type='text/javascript'>
// Open or close a hidden section
function hidden_opener(divid, openerid)
{
var divobj = document.getElementById(divid);
var openerobj = document.getElementById(openerid);
if (divobj.className == 'opener_shown') {
  divobj.className = 'opener_hidden';
  openerobj.innerHTML = '<img border=0 src=$imgdir/closed.gif>';
  }
else {
  divobj.className = 'opener_shown';
  openerobj.innerHTML = '<img border=0 src=$imgdir/open.gif>';
  }
}

// Show a tab
function select_tab(name, tabname, form)
{
var tabnames = document[name+'_tabnames'];
var tabtitles = document[name+'_tabtitles'];
for(var i=0; i<tabnames.length; i++) {
  var tabobj = document.getElementById('tab_'+tabnames[i]);
  var divobj = document.getElementById('div_'+tabnames[i]);
  var title = tabtitles[i];
  if (tabnames[i] == tabname) {
    // Selected table
    tabobj.innerHTML = '<table cellpadding="0" cellspacing="0"><tr>'+
		       '<td valign=top $jscb>'+
		       '<img src=$imgdir/lc2.gif alt=""></td>'+
		       '<td $jscb nowrap>'+
		       '&nbsp;<b>'+title+'</b>&nbsp;</td>'+
	               '<td valign=top $jscb>'+
		       '<img src=$imgdir/rc2.gif alt=""></td>'+
		       '</tr></table>';
    divobj.className = 'opener_shown';
    }
  else {
    // Non-selected tab
    tabobj.innerHTML = '<table cellpadding="0" cellspacing="0"><tr>'+
		       '<td valign="top" $jstb>'+
		       '<img src="$imgdir/lc1.gif" alt=""></td>'+
		       '<td $jstb nowrap>'+
                       '&nbsp;<a href=\\'\\' onClick=\\'return select_tab("'+
		       name+'", "'+tabnames[i]+'")\\'>'+title+'</a>&nbsp;</td>'+
		       '<td valign="top" $jstb>'+
    		       '<img src="$imgdir/rc1.gif" alt=""></td>'+
		       '</tr></table>';
    divobj.className = 'opener_hidden';
    }
  }
if (document.forms[0] && document.forms[0][name]) {
  document.forms[0][name].value = tabname;
  }
return false;
}
</script>
EOF
}

=head2 ui_hidden_start(title, name, status, thisurl)

Returns HTML for the start of a collapsible hidden section, such as for
advanced options. When clicked on, the section header will expand to display
whatever is between this function and ui_hidden_end. The parameters are :

=item title - Text for the start of this hidden section.

=item name - A unique name for this section.

=item status - 1 if it should be initially open, 0 if not.

=item thisurl - URL of the current page. This is used by themes on devices that don't support Javascript to implement the opening and closing.

=cut
sub ui_hidden_start
{
return &theme_ui_hidden_start(@_) if (defined(&theme_ui_hidden_start));
my ($title, $name, $status, $url) = @_;
my $rv;
if (!$main::ui_hidden_start_donejs++) {
	$rv .= &ui_hidden_javascript();
	}
my $divid = "hiddendiv_$name";
my $openerid = "hiddenopener_$name";
my $defimg = $status ? "open.gif" : "closed.gif";
my $defclass = $status ? 'opener_shown' : 'opener_hidden';
$rv .= "<a href=\"javascript:hidden_opener('$divid', '$openerid')\" id='$openerid'><img border=0 src='@{[&get_webprefix()]}/images/$defimg' alt='*'></a>\n";
$rv .= "<a href=\"javascript:hidden_opener('$divid', '$openerid')\">$title</a><br>\n";
$rv .= "<div class='$defclass' id='$divid'>\n";
return $rv;
}

=head2 ui_hidden_end(name)

Returns HTML for the end of a hidden section, started by ui_hidden_start.

=cut
sub ui_hidden_end
{
return &theme_ui_hidden_end(@_) if (defined(&theme_ui_hidden_end));
my ($name) = @_;
return "</div>\n";
}

=head2 ui_hidden_table_row_start(title, name, status, thisurl)

Similar to ui_hidden_start, but for use within a table started with
ui_table_start. I recommend against using this where possible, as it can
be difficult for some themes to implement.

=cut
sub ui_hidden_table_row_start
{
return &theme_ui_hidden_table_row_start(@_)
	if (defined(&theme_ui_hidden_table_row_start));
my ($title, $name, $status, $url) = @_;
my ($rv, $rrv);
if (!$main::ui_hidden_start_donejs++) {
	$rv .= &ui_hidden_javascript();
	}
my $divid = "hiddendiv_$name";
my $openerid = "hiddenopener_$name";
my $defimg = $status ? "open.gif" : "closed.gif";
my $defclass = $status ? 'opener_shown' : 'opener_hidden';
if ($title) {
	$rrv .= "<a href=\"javascript:hidden_opener('$divid', '$openerid')\" id='$openerid'><img border=0 src='@{[&get_webprefix()]}/images/$defimg'></a>\n";
	$rrv .= "<a href=\"javascript:hidden_opener('$divid', '$openerid')\">$title</a><br>\n";
	$rv .= &ui_table_row(undef, $rrv, $main::ui_table_cols);
	}
$rv .= "</table>\n";
$rv .= "<div class='$defclass' id='$divid'>\n";
$rv .= "<table width='100%'>\n";
return $rv;
}

=head2 ui_hidden_table_row_end(name)

Returns HTML to end a block started by ui_hidden_table_start.

=cut
sub ui_hidden_table_row_end
{
return &theme_ui_hidden_table_row_end(@_)
	if (defined(&theme_ui_hidden_table_row_end));
my ($name) = @_;
return "</table></div><table width='100%'>\n";
}

=head2 ui_hidden_table_start(heading, [tabletags], [cols], name, status, [&default-tds], [rightheading])

Returns HTML for the start of a form block into which labelled inputs can
be placed, which is collapsible by clicking on the header. Basically the same
as ui_table_start, and must contain HTML generated by ui_table_row.

The parameters are :

=item heading - Text to show at the top of the form.

=item tabletags - HTML attributes to put in the outer <table>, typically something like width=100%.

=item cols - Desired number of columns for labels and fields. Defaults to 4, but can be 2 for forms with lots of wide inputs.

=item name - A unique name for this table.

=item status - Set to 1 if initially open, 0 if initially closed.

=item default-tds - An optional array reference of HTML attributes for the <td> tags in each row of the table.

=item right-heading - HTML to appear in the heading, aligned to the right.

=cut
sub ui_hidden_table_start
{
return &theme_ui_hidden_table_start(@_)
	if (defined(&theme_ui_hidden_table_start));
my ($heading, $tabletags, $cols, $name, $status, $tds, $rightheading) = @_;
my $rv;
if (!$main::ui_hidden_start_donejs++) {
	$rv .= &ui_hidden_javascript();
	}
my $divid = "hiddendiv_$name";
my $openerid = "hiddenopener_$name";
my $defimg = $status ? "open.gif" : "closed.gif";
my $defclass = $status ? 'opener_shown' : 'opener_hidden';
my $text = defined($tconfig{'cs_text'}) ? $tconfig{'cs_text'} :
	      defined($gconfig{'cs_text'}) ? $gconfig{'cs_text'} : "000000";
$rv .= "<table class='ui_table' border $tabletags>\n";
my $colspan = 1;
if (defined($heading) || defined($rightheading)) {
	$rv .= "<tr".($tb ? " ".$tb : "")."><td>";
	if (defined($heading)) {
		$rv .= "<a href=\"javascript:hidden_opener('$divid', '$openerid')\" id='$openerid'><img border=0 src='@{[&get_webprefix()]}/images/$defimg'></a> <a href=\"javascript:hidden_opener('$divid', '$openerid')\"><b><font color='#$text'>$heading</font></b></a>";
		}
	$rv .= "</td>";
	if (defined($rightheading)) {
                $rv .= "<td align='right'>$rightheading</td>";
                $colspan++;
                }
	$rv .= " </tr>\n";
	}
$rv .= "<tr".($cb ? " ".$cb : "")."><td colspan='$colspan'><div class='$defclass' id='$divid'><table width='100%'>\n";
$main::ui_table_cols = $cols || 4;
$main::ui_table_pos = 0;
$main::ui_table_default_tds = $tds;
return $rv;
}

=head2 ui_hidden_table_end(name)

Returns HTML for the end of a form block with hiding, as started by
ui_hidden_table_start.

=cut
sub ui_hidden_table_end
{
my ($name) = @_;
return &theme_ui_hidden_table_end(@_) if (defined(&theme_ui_hidden_table_end));
return "</table></div></td></tr></table>\n";
}

=head2 ui_tabs_start(&tabs, name, selected, show-border)

Returns a row of tabs from which one can be selected, displaying HTML
associated with that tab. The parameters are :

=item tabs - An array reference of array refs, each of which contains the value and user-visible text for a tab.

=item name - Name of the HTML field into which the selected tab will be placed.

=item selected - Value for the tab selected by default.

=item show-border - Set to 1 if there should be a border around the contents of the tabs.

Example code :

  @tabs = ( [ 'list', 'List services' ],
            [ 'install', 'Install new service' ] );
  print ui_tabs_start(\@tabs, 'mode', 'list');

  print ui_tabs_start_tab('mode', 'list');
  generate_service_list();
  print ui_tabs_end_tab('mode', 'list');

  print ui_tabs_start_tab('mode', 'install');
  generate_install_form();
  print ui_tabs_end_tab('mode', 'install);

  print ui_tabs_end();

=cut
sub ui_tabs_start
{
return &theme_ui_tabs_start(@_) if (defined(&theme_ui_tabs_start));
my ($tabs, $name, $sel, $border) = @_;
my $rv;
if (!$main::ui_hidden_start_donejs++) {
	$rv .= &ui_hidden_javascript();
	}

# Build list of tab titles and names
my $tabnames = &convert_to_json([map { $_->[0] } @$tabs]);
my $tabtitles = &convert_to_json([map { $_->[1] } @$tabs]);
$rv .= "<script type='text/javascript'>\n";
$rv .= "document.${name}_tabnames = $tabnames;\n";
$rv .= "document.${name}_tabtitles = $tabtitles;\n";
$rv .= "</script>\n";

# Output the tabs
my $imgdir = "@{[&get_webprefix()]}/images";
$rv .= &ui_hidden($name, $sel)."\n";
$rv .= "<table border='0' cellpadding='0' cellspacing='0' class='ui_tabs'>\n";
$rv .= "<tr><td bgcolor='#ffffff' colspan='".(scalar(@$tabs)*2+1)."'>";
if ($ENV{'HTTP_USER_AGENT'} !~ /msie/i) {
	# For some reason, the 1-pixel space above the tabs appears huge on IE!
	$rv .= "<img src='$imgdir/1x1.gif'>";
	}
$rv .= "</td></tr>\n";
$rv .= "<tr>\n";
$rv .= "<td bgcolor='#ffffff' width='1'><img src='$imgdir/1x1.gif'></td>\n";
foreach my $t (@$tabs) {
	if ($t ne $$tabs[0]) {
		# Spacer
		$rv .= "<td width='2' bgcolor='#ffffff' class='ui_tab_spacer'>".
		       "<img src='$imgdir/1x1.gif'></td>\n";
		}
	my $tabid = "tab_".$t->[0];
	$rv .= "<td id='${tabid}' class='ui_tab'>";
	$rv .= "<table cellpadding='0' cellspacing='0' border='0'><tr>";
	if ($t->[0] eq $sel) {
		# Selected tab
		$rv .= "<td valign='top'".($cb ? " ".$cb : "")." class='selectedTabLeft'>".
		       "<img src='$imgdir/lc2.gif' alt=\"\"></td>";
		$rv .= "<td".($cb ? " ".$cb : "")." nowrap class='selectedTabMiddle'>".
		       "&nbsp;<b>$t->[1]</b>&nbsp;</td>";
		$rv .= "<td valign=top".($cb ? " ".$cb : "")." class='selectedTabRight'>".
		       "<img src=$imgdir/rc2.gif alt=\"\"></td>";
		}
	else {
		# Other tab (which has a link)
		$rv .= "<td valign='top'".($tb ? " ".$tb : "").">".
		       "<img src='$imgdir/lc1.gif' alt=\"\"></td>";
		$rv .= "<td".($tb ? " ".$tb : "")." nowrap>".
		       "&nbsp;<a href='$t->[2]' ".
		       "onClick='return select_tab(\"$name\", \"$t->[0]\")'>".
		       "$t->[1]</a>&nbsp;</td>";
		$rv .= "<td valign='top'".($tb ? " ".$tb : "")." >".
		       "<img src='$imgdir/rc1.gif' ".
		       "alt=\"\"></td>";
		$rv .= "</td>\n";
		}
	$rv .= "</tr></table>";
	$rv .= "</td>\n";
	}
$rv .= "<td bgcolor='#ffffff' width='1'><img src='$imgdir/1x1.gif'></td>\n";
$rv .= "</table>\n";

if ($border) {
	# All tabs are within a grey box
	$rv .= "<table width='100%' cellpadding='0' cellspacing='0' border='0' ".
	       "class='ui_tabs_box'>\n";
	$rv .= "<tr> <td bgcolor='#ffffff' rowspan='3' width='1'><img src='$imgdir/1x1.gif'></td>\n";
	$rv .= "<td".($cb ? " ".$cb : "")." colspan='3' height='2'><img src='$imgdir/1x1.gif'></td> </tr>\n";
	$rv .= "<tr> <td".($cb ? " ".$cb : "")." width='2'><img src='$imgdir/1x1.gif'></td>\n";
	$rv .= "<td valign='top'>";
	}
$main::ui_tabs_selected = $sel;
return $rv;
}

=head2 ui_tabs_end(show-border)

Returns HTML to end a block started by ui_tabs_start. The show-border parameter
must match the parameter with the same name in the start function.

=cut
sub ui_tabs_end
{
return &theme_ui_tabs_end(@_) if (defined(&theme_ui_tabs_end));
my ($border) = @_;
my $rv;
my $imgdir = "@{[&get_webprefix()]}/images";
if ($border) {
	$rv .= "</td>\n";
	$rv .= "<td".($cb ? " ".$cb : "")." width='2'><img src='$imgdir/1x1.gif'></td>\n";
	$rv .= "</tr>\n";
	$rv .= "<tr> <td".($cb ? " ".$cb : "")." colspan='3' height='2'><img src='$imgdir/1x1.gif'></td> </tr>\n";
	$rv .= "</table>\n";
	}
return $rv;
}

=head2 ui_tabs_start_tab(name, tab)

Must be called before outputting the HTML for the named tab, and returns HTML
for the required <div> block.

=cut
sub ui_tabs_start_tab
{
return &theme_ui_tabs_start_tab(@_) if (defined(&theme_ui_tabs_start_tab));
my ($name, $tab) = @_;
my $defclass = $tab eq $main::ui_tabs_selected ?
			'opener_shown' : 'opener_hidden';
my $rv = "<div id='div_$tab' class='$defclass ui_tabs_start'>\n";
return $rv;
}

=head2 ui_tabs_start_tabletab(name, tab)

Behaves like ui_tabs_start_tab, but for use within a ui_table_start block.
I recommend against using this where possible, as it is difficult for themes
to implement.

=cut
sub ui_tabs_start_tabletab
{
return &theme_ui_tabs_start_tabletab(@_)
	if (defined(&theme_ui_tabs_start_tabletab));
my $div = &ui_tabs_start_tab(@_);
return "</table>\n".$div."<table width='100%'>\n";
}

=head2 ui_tabs_end_tab

Returns HTML for the end of a block started by ui_tabs_start_tab.

=cut
sub ui_tabs_end_tab
{
return &theme_ui_tabs_end_tab(@_) if (defined(&theme_ui_tabs_end_tab));
return "</div>\n";
}

=head2 ui_tabs_end_tabletab

Returns HTML for the end of a block started by ui_tabs_start_tabletab.

=cut
sub ui_tabs_end_tabletab
{
return &theme_ui_tabs_end_tabletab(@_)
	if (defined(&theme_ui_tabs_end_tabletab));
return "</table></div><table width='100%'>\n";
}

=head2 ui_max_text_width(width, [text-area?])

Returns a new width for a text field, based on theme settings. For internal
use only.

=cut
sub ui_max_text_width
{
my ($w, $ta) = @_;
my $max = $ta ? $tconfig{'maxareawidth'} : $tconfig{'maxboxwidth'};
return $max && $w > $max ? $max : $w;
}

####################### radio hidden functions

=head2 ui_radio_selector(&opts, name, selected, [dropdown-mode])

Returns HTML for a set of radio buttons, each of which shows a different
block of HTML when selected. The parameters are :

=item opts - An array ref to arrays containing [ value, label, html ]

=item name - HTML name for the radio buttons

=item selected - Value for the initially selected button.

=item dropdown - Use a <select> dropdown menu instead of radio buttons

=cut
sub ui_radio_selector
{
return &theme_ui_radio_selector(@_) if (defined(&theme_ui_radio_selector));
my ($opts, $name, $sel, $dropdown) = @_;
my $rv;
if (!$main::ui_radio_selector_donejs++) {
	$rv .= &ui_radio_selector_javascript();
	}
my $optnames =
	"[".join(",", map { "\"".&html_escape($_->[0])."\"" } @$opts)."]";
if ($dropdown) {
	$rv .= &ui_select($name, $sel,
		[ map { [ $_->[0], $_->[1] ] } @$opts ],
		1, 0, 0, 0,
		"onChange='selector_show(\"$name\", $name.value, $optnames)'");
	}
else {
	foreach my $o (@$opts) {
		$rv .= &ui_oneradio($name, $o->[0], $o->[1], $sel eq $o->[0],
		    "onClick='selector_show(\"$name\", \"$o->[0]\", $optnames)'");
		}
	}
$rv .= "<br>\n";
foreach my $o (@$opts) {
	my $cls = $o->[0] eq $sel ? "selector_shown" : "selector_hidden";
	$rv .= "<div id='sel_${name}_$o->[0]' class='$cls'>".$o->[2]."</div>\n";
	}
return $rv;
}

sub ui_radio_selector_javascript
{
return <<EOF;
<style type='text/css'>
.selector_shown {display:inline}
.selector_hidden {display:none}
</style>
<script type='text/javascript'>
function selector_show(name, value, values)
{
for(var i=0; i<values.length; i++) {
	var divobj = document.getElementById('sel_'+name+'_'+values[i]);
	divobj.className = value == values[i] ? 'selector_shown'
					      : 'selector_hidden';
	}
}
</script>
EOF
}

=head2 ui_switch_theme_javascript()

The subroutine is designed to load JavaScript
for switching themes using hotkeys.

Hotkeys are:
	To activate theme switch mode:
	Use: `Ctrl+Alt+T` (or `Control+Option+T` on Mac).

	Immediately after, within 1 second, select your desired theme by pressing:
	- `Shift + A`: Authentic theme
	- `Shift + G`: Gray theme
	- `Shift + L`: Legacy theme.

=cut

sub ui_switch_theme_javascript
{
return &theme_ui_switch_theme_javascript(@_) if (defined(&theme_ui_switch_theme_javascript));
my $webprefix = &get_webprefix();
my $switch_script .= <<EOF;
<script type="text/javascript">
(function () {
    let firstCombinationPressed = false;
    document.addEventListener("keydown", function (event) {
        // Check for Ctrl+Alt+T or Control+Option+T
        if (event.ctrlKey && event.altKey && event.keyCode === 84) {
            firstCombinationPressed = true;

            // Set a timeout to reset the state after a short period (e.g., 1 seconds)
            setTimeout(() => {
                firstCombinationPressed = false;
            }, 1000);
        }
        if (firstCombinationPressed && event.shiftKey &&
            (event.keyCode === 65 ||
             event.keyCode === 70 || event.keyCode === 71 ||
             event.keyCode === 76)) {
            const theme =
                // Shift + A : Authentic theme
                event.keyCode === 65 ? 1 :
                // Shift + F / Shift + G : Framed theme / Gray theme
                (event.keyCode === 70 || event.keyCode === 71) ? 2 :
                // Shift + L : Legacy theme
                event.keyCode === 76 ? 3 : null;
            firstCombinationPressed = false;
            try {
                top.document.documentElement.style.filter = 'grayscale(100%) blur(0.5px) brightness(0.75) opacity(0.5)';
                top.document.documentElement.style.cursor = 'wait';
                top.document.documentElement.style.pointerEvents = 'none';
            } catch (error) {}
            top.location.href = "$webprefix/switch_theme.cgi?theme=" + theme + "";
        }
    });
})();
document.currentScript.remove();
</script>
EOF
return $switch_script;
}

####################### grid layout functions

=head2 ui_grid_table(&elements, columns, [width-percent], [&tds], [tabletags], [title])

Given a list of HTML elements, formats them into a table with the given
number of columns. However, themes are free to override this to use fewer
columns where space is limited. Parameters are :

=item elements - An array reference of table elements, each of which can be any HTML you like.

=item columns - Desired number of columns in the grid.

=item width-percent - Optional desired width as a percentage.

=item tds - Array ref of HTML attributes for <td> tags in the tables.

=item tabletags - HTML attributes for the <table> tag.

=item title - Optional title to add to the top of the grid.

=cut
sub ui_grid_table
{
return &theme_ui_grid_table(@_) if (defined(&theme_ui_grid_table));
my ($elements, $cols, $width, $tds, $tabletags, $title) = @_;
return "" if (!@$elements);
my $rv = "<table class='ui_grid_table'".
	    ($width ? " width='$width%'" : "").
	    ($tabletags ? " ".$tabletags : "").
	    ">\n";
my $i;
for($i=0; $i<@$elements; $i++) {
	$rv .= "<tr class='ui_grid_row'>" if ($i%$cols == 0);
	$rv .= "<td ".$tds->[$i%$cols]." valign='top' class='ui_grid_cell'>".
	       $elements->[$i]."</td>\n";
	$rv .= "</tr>" if ($i%$cols == $cols-1);
	}
if ($i%$cols) {
	while($i%$cols) {
		$rv .= "<td ".$tds->[$i%$cols]." class='ui_grid_cell'>".
		       "<br></td>\n";
		$i++;
		}
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
if (defined($title)) {
	$rv = "<table class='ui_table border' ".
	      ($width ? " width=$width%" : "").">\n".
	      ($title ? "<tr".($tb ? " ".$tb : "")."><td><b>$title</b></td></tr>\n" : "").
              "<tr".($cb ? " ".$cb : "")."><td>$rv</td></tr>\n".
	      "</table>";
	}
return $rv;
}

=head2 ui_radio_table(name, selected, &rows, [no-bold])

Returns HTML for a table of radio buttons, each of which has a label and
some associated inputs to the right. The parameters are :

=item name - Unique name for this table, which is also the radio buttons' name.

=item selected - Value for the initially selected radio button.

=item rows - Array ref of array refs, one per button. The elements of each are the value for this option, a label, and option additional HTML to appear next to it.

=item no-bold - When set to 1, labels in the table will not be bolded

=cut
sub ui_radio_table
{
return &theme_ui_radio_table(@_) if (defined(&theme_ui_radio_table));
my ($name, $sel, $rows, $nobold) = @_;
return "" if (!@$rows);
my $rv = "<table class='ui_radio_table'>\n";
foreach my $r (@$rows) {
	$rv .= "<tr>\n";
	$rv .= "<td valign='top'".(defined($r->[2]) ? "" : " colspan='2'").">".
	       ($nobold ? "" : "<b>").
	       &ui_oneradio($name, $r->[0], $r->[1], $r->[0] eq $sel, $r->[3]).
	       ($nobold ? "" : "</b>").
	       "</td>\n";
	if (defined($r->[2])) {
		$rv .= "<td valign='top'>".$r->[2]."</td>\n";
		}
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return $rv;
}

=head2 ui_up_down_arrows(uplink, downlink, up-show, down-show)

Returns HTML for moving some objects in a table up or down. The parameters are :

=item uplink - URL for the up-arrow link.

=item downlink - URL for the down-arrow link.

=item up-show - Set to 1 if the up-arrow should be shown, 0 if not.

=item down-show - Set to 1 if the down-arrow should be shown, 0 if not.

=item up-icon - Optional path to icon for up link

=item down-icon - Optional path to icon for down link

=cut
sub ui_up_down_arrows
{
return &theme_ui_up_down_arrows(@_) if (defined(&theme_ui_up_down_arrows));
my ($uplink, $downlink, $upshow, $downshow, $upicon, $downicon) = @_;
my $mover;
my $imgdir = "@{[&get_webprefix()]}/images";
$upicon ||= "$imgdir/moveup.gif";
$downicon ||= "$imgdir/movedown.gif";
if ($downshow) {
	$mover .= "<a class='ui_up_down_arrows_down' href='$downlink'>".
	  "<img class='ui_up_down_arrows_down' src='$downicon' border='0'></a>";
	}
else {
	$mover .= "<img class='ui_up_down_arrows_gap' src='$imgdir/movegap.gif'>";
	}
if ($upshow) {
	$mover .= "<a class='ui_up_down_arrows_up' href='$uplink'>".
	  "<img class='ui_up_down_arrows_up' src='$upicon' border='0'></a>";
	}
else {
	$mover .= "<img class='ui_up_down_arrows_gap' src='$imgdir/movegap.gif'>";
	}
return $mover;
}

=head2 ui_hr

Returns a horizontal row tag, typically just an <hr>

=item tags - Additional HTML attributes for the <hr> tag.

=cut
sub ui_hr
{
return &theme_ui_hr(@_) if (defined(&theme_ui_hr));
my ($tags) = @_;
return "<hr class='ui_hr'".($tags ? " ".$tags : "").">\n";
}

=head2 ui_nav_link(direction, url, disabled)

Returns an arrow icon linking to the provided url.

=cut
sub ui_nav_link
{
return &theme_ui_nav_link(@_) if (defined(&theme_ui_nav_link));
my ($direction, $url, $disabled) = @_;
my $alt = $direction eq "left" ? '<-' : '->';
if ($disabled) {
	return "<img class='ui_nav_link' alt=\"$alt\" align=\"middle\""
	     . "src=\"@{[&get_webprefix()]}/images/$direction-grey.gif\">\n";
	}
else {
	return "<a class='ui_nav_link' href=\"$url\"><img class='ui_nav_link' alt=\"$alt\" align=\"middle\""
	     . "src=\"@{[&get_webprefix()]}/images/$direction.gif\"></a>\n";
	}
}

=head2 ui_confirmation_form(cgi, message, &hiddens, [&buttons], [otherinputs], [extra-warning])

Returns HTML for a form asking for confirmation before performing some
action, such as deleting a user. The parameters are :

=item cgi - Script to which the confirmation form submits, like delete.cgi.

=item message - Warning message for the user to see.

=item hiddens - Array ref of two-element array refs, containing hidden form field names and values.

=item buttons - Array ref of two-element array refs, containing form button names and labels.

=item otheirinputs - HTML for extra inputs to include in their form.

=item extra-warning - An additional separate warning message to show.

=cut
sub ui_confirmation_form
{
my ($cgi, $message, $hiddens, $buttons, $others, $warning) = @_;
my $rv;
$rv .= "<center class='ui_confirmation'>\n";
$rv .= &ui_form_start($cgi, "post");
foreach my $h (@$hiddens) {
	$rv .= &ui_hidden(@$h);
	}
$rv .= "<b>$message</b><p>\n";
if ($warning) {
	$rv .= "<b><font color='#ff0000'>$warning</font></b><p>\n";
	}
if ($others) {
	$rv .= $others."<p>\n";
	}
$rv .= &ui_form_end($buttons);
$rv .= "</center>\n";
return $rv;
}

=head2 ui_text_color(text, type)

Returns HTML for a text string, with its color determined by $type.

=item text - contains any text string

=item type - returned text color

=cut

sub ui_text_color
{
my ($text, $type) = @_;
my ($color, $class_type);

if (defined (&theme_ui_text_color)) {
    return &theme_ui_text_color(@_);
    }
$class_type = $type eq "warn" ? "warning" : $type;
if ($type eq "success") { $color = "var(--text-color-success, #3c763d)"; }
elsif ($type eq "info") { $color = "var(--text-color-info, #31708f)"; }
elsif ($type eq "warn") { $color = "var(--text-color-warning, #8a6d3b)"; }
elsif ($type eq "danger") { $color = "var(--text-color-danger, #a94442)"; }
return "<span class=\"ui_text_color text_type_$type text-$class_type\" style=\"color: $color\">$text</span>";
}

=head2 ui_alert_box(msg, type)

Returns HTML for an alert box, with background color determined by $type.

$msg contains any text or HTML to be contained within the alert box, and
can include forms.

Type of alert:

=item success - green

=item info - blue

=item warn - yellow

=item danger - red

=cut

sub ui_alert_box
{
my ($msg, $type) = @_;
my ($rv, $color);

if (defined (&theme_ui_alert_box)) {
    return &theme_ui_alert_box(@_);
    }

if ($type eq "success") { $color = "DFF0D8"; }
elsif ($type eq "info") { $color = "D9EDF7"; }
elsif ($type eq "warn") { $color = "FCF8E3"; }
elsif ($type eq "danger") { $color = "F2DEDE"; }

$rv .= "<table class='ui_alert_box' width='100%'><tr bgcolor='#$color'><td align='center'><p>\n";
$rv .= "$msg\n";
$rv .= "<p></td></tr></table><p>\n";

return $rv;
}

####################### javascript functions

=head2 js_disable_inputs(&disable-inputs, &enable-inputs, [tag])

Returns Javascript to disable some form elements and enable others. Mainly
for internal use.

=cut
sub js_disable_inputs
{
my $rv;
my $f;
foreach $f (@{$_[0]}) {
	$rv .= "e = form.elements[\"$f\"]; e.disabled = true; ";
	$rv .= "for(i=0; i<e.length; i++) { e[i].disabled = true; } ";
	}
foreach $f (@{$_[1]}) {
	$rv .= "e = form.elements[\"$f\"]; e.disabled = false; ";
	$rv .= "for(i=0; i<e.length; i++) { e[i].disabled = false; } ";
	}
foreach $f (@{$_[1]}) {
	if ($f =~ /^(.*)_def$/ && &indexof($1, @{$_[1]}) >= 0) {
		# When enabling both a _def field and its associated text field,
		# disable the text if the _def is set to 1
		my $tf = $1;
		$rv .= "e = form.elements[\"$f\"]; for(i=0; i<e.length; i++) { if (e[i].checked && e[i].value == \"1\") { form.elements[\"$tf\"].disabled = true } } ";
		}
	}
return $_[2] ? "$_[2]='$rv'" : $rv;
}

=head2 ui_page_flipper(message, [inputs, cgi], left-link, right-link, [far-left-link], [far-right-link], [below])

Returns HTML for moving left and right in some large list, such as an inbox
or database table. If only 5 parameters are given, no far links are included.
If any link is undef, that array will be greyed out. The parameters are :

=item message - Text or display between arrows.

=item inputs - Additional HTML inputs to show after message.

=item cgi - Optional CGI for form wrapping arrows to submit to.

=item left-link - Link for left-facing arrow.

=item right-link - Link for right-facing arrow.

=item far-left-link - Link for far left-facing arrow, optional.

=item far-right-link - Link for far right-facing arrow, optional.

=item below - HTML to display below the arrows.

=cut
sub ui_page_flipper
{
return &theme_ui_page_flipper(@_) if (defined(&theme_ui_page_flipper));
my ($msg, $inputs, $cgi, $left, $right, $farleft, $farright, $below) = @_;
my $rv = "<center class='ui_page_flipper'>";
$rv .= &ui_form_start($cgi) if ($cgi);

# Far left link, if needed
if (@_ > 5) {
	if ($farleft) {
		$rv .= "<a href='$farleft'>".
		       "<img src='@{[&get_webprefix()]}/images/first.gif' ".
		       "border='0' align='middle'></a>\n";
		}
	else {
		$rv .= "<img src='@{[&get_webprefix()]}/images/first-grey.gif' ".
		       "border='0' align='middle'></a>\n";
		}
	}

# Left link
if ($left) {
	$rv .= "<a href='$left'>".
	       "<img src=@{[&get_webprefix()]}/images/left.gif ".
	       "border='0' align='middle'></a>\n";
	}
else {
	$rv .= "<img src=@{[&get_webprefix()]}/images/left-grey.gif ".
	       "border='0' align='middle'></a>\n";
	}

# Message and inputs
$rv .= $msg;
$rv .= " ".$inputs if ($inputs);

# Right link
if ($right) {
	$rv .= "<a href='$right'>".
	       "<img src='@{[&get_webprefix()]}/images/right.gif' ".
	       "border='0' align='middle'></a>\n";
	}
else {
	$rv .= "<img src='@{[&get_webprefix()]}/images/right-grey.gif' ".
	       "border='0' align='middle'></a>\n";
	}

# Far right link, if needed
if (@_ > 5) {
	if ($farright) {
		$rv .= "<a href='$farright'>".
		       "<img src='@{[&get_webprefix()]}/images/last.gif' ".
		       "border='0' align='middle'></a>\n";
		}
	else {
		$rv .= "<img src='@{[&get_webprefix()]}/images/last-grey.gif' ".
		       "border='0' align='middle'></a>\n";
		}
	}

$rv .= "<br>".$below if ($below);
$rv .= &ui_form_end() if ($cgi);
$rv .= "</center>\n";
return $rv;
}

=head2 js_checkbox_disable(name, &checked-disable, &checked-enable, [tag])

For internal use only.

=cut
sub js_checkbox_disable
{
my $rv;
my $f;
foreach $f (@{$_[1]}) {
	$rv .= "form.elements[\"$f\"].disabled = $_[0].checked; ";
	}
foreach $f (@{$_[2]}) {
	$rv .= "form.elements[\"$f\"].disabled = !$_[0].checked; ";
	}
return $_[3] ? "$_[3]='$rv'" : $rv;
}

=head2 ui_form_field_state_javascript(control-name, &active-values, &element-ids, &field-names, [&reset-values])

Returns a <script> block that keeps page elements and form fields in sync with
another form control. When the control's current value is one of active-values,
the element IDs are shown and field names are enabled. Otherwise the elements
are hidden, the fields are disabled, and any reset-values are applied.

=item control-name - Name of the controlling form field.

=item active-values - Array ref of values for which dependents are active.

=item element-ids - Array ref of element IDs to show or hide.

=item field-names - Array ref of form field names to enable or disable.

=item reset-values - Optional hash ref of field name to value to set when disabled.

=cut
sub ui_form_field_state_javascript
{
return &theme_ui_form_field_state_javascript(@_)
	if (defined(&theme_ui_form_field_state_javascript));
my ($control, $values, $ids, $fields, $resets) = @_;
$values ||= [ ];
$ids ||= [ ];
$fields ||= [ ];
$resets ||= { };
my $js_quote = sub {
	my ($str) = @_;
	return "'".&quote_javascript($str)."'";
	};
my $js_array = sub {
	my ($arr) = @_;
	return "[".join(",", map { &$js_quote($_) } @$arr)."]";
	};
my $js_hash = sub {
	my ($hash) = @_;
	return "{".
	       join(",", map { &$js_quote($_).":".&$js_quote($hash->{$_}) }
			 sort { $a cmp $b } keys %$hash).
	       "}";
	};
my $jcontrol = &$js_quote($control);
my $jvalues = &$js_array($values);
my $jids = &$js_array($ids);
my $jfields = &$js_array($fields);
my $jresets = &$js_hash($resets);
return <<EOF;
<script type='text/javascript'>
(function() {
	var controlName = $jcontrol,
	    activeValues = $jvalues,
	    elementIds = $jids,
	    fieldNames = $jfields,
	    resetValues = $jresets;

	function currentControlValue() {
		var controls = document.getElementsByName(controlName), i, c;
		for (i = 0; i < controls.length; i++) {
			c = controls[i];
			if (c.type == 'radio' || c.type == 'checkbox') {
				if (c.checked) {
					return c.value;
				}
			}
			else {
				return c.value;
			}
		}
		return null;
	}

	function hasActiveValue(value) {
		var i;
		for (i = 0; i < activeValues.length; i++) {
			if (String(activeValues[i]) == String(value)) {
				return true;
			}
		}
		return false;
	}

	function setFieldValue(field, value) {
		if (field.type == 'radio' || field.type == 'checkbox') {
			field.checked = String(field.value) == String(value);
		}
		else {
			field.value = value;
		}
	}

	function syncDependentFields() {
		var active = hasActiveValue(currentControlValue()), i, j, elem,
		    fields, field, name;
		for (i = 0; i < elementIds.length; i++) {
			elem = document.getElementById(elementIds[i]);
			if (elem) {
				elem.style.display = active ? '' : 'none';
			}
		}
		for (i = 0; i < fieldNames.length; i++) {
			name = fieldNames[i];
			fields = document.getElementsByName(name);
			for (j = 0; j < fields.length; j++) {
				field = fields[j];
				field.disabled = !active;
				if (!active &&
				    Object.prototype.hasOwnProperty.call(resetValues, name)) {
					setFieldValue(field, resetValues[name]);
				}
			}
		}
	}

	var controls = document.getElementsByName(controlName), i;
	for (i = 0; i < controls.length; i++) {
		controls[i].addEventListener('change', syncDependentFields);
		controls[i].addEventListener('input', syncDependentFields);
	}
	if (document.readyState == 'loading') {
		document.addEventListener('DOMContentLoaded', syncDependentFields);
	}
	else {
		syncDependentFields();
	}
})();
</script>
EOF
}

=head2 js_redirect(url, [window-object], [timeout])

Returns HTML to trigger a redirect to some URL.

=cut
sub js_redirect
{
my ($url, $window, $timeout) = @_;
if (defined(&theme_js_redirect)) {
	return &theme_js_redirect(@_);
	}
$window = $window && $window =~ /^[\w.]+$/ ? $window : "window";
$timeout = int($timeout);
if ($url =~ /^\//) {
	# If the URL is like /foo , add webprefix
	$url = &get_webprefix().$url;
	}
$url = &quote_escape($url);
# Prevent the URL from terminating or destabilising the enclosing
# script element. Escaping every "<" stops the HTML parser from ever
# seeing </script (which would close it) or <!-- (which would enter
# script-data-escaped state). < evaluates back to "<" in JS, so
# the redirect target is preserved.
$url =~ s|<|\\u003C|g;
return "<script type='text/javascript'>
		setTimeout(function(){
			${window}.location = '$url';
		}, $timeout);
	</script>";
}

=head2 ui_webmin_link(module, page)

Returns the URL for a link to this Webmin instance that can be used in an email

=cut
sub ui_webmin_link
{
my ($mod, $page) = @_;
if (defined(&theme_ui_webmin_link)) {
	return &theme_ui_webmin_link(@_);
	}
my %miniserv;
&get_miniserv_config(\%miniserv);
my $proto = $miniserv{'ssl'} ? 'https' : 'http';
my $port = $miniserv{'port'};
my $host = $ENV{'HTTP_HOST'} || &get_display_hostname();
if ($host =~ /^([a-zA-Z0-9\-\_\.]+):(\d+)$/) {
	$host = $1;
	$port = $2;
	}
my $rv = $proto."://$host:$port";
if ($mod) {
	$rv .= "/$mod";
	}
if ($page) {
	$rv .= "/$page";
	}
return $rv;
}

=head2 ui_line_break_double()

Create double line break, with accessible second break

=cut
sub ui_line_break_double
{
if (defined(&theme_ui_line_break_double)) {
	return &theme_ui_line_break_double(@_);
	}
return "<br><br data-x-br>\n";
}

=head2 ui_page_refresh()

Returns theme based JavaScript function to refresh current page

=cut
sub ui_page_refresh
{
if (defined(&theme_ui_page_refresh)) {
	return &theme_ui_page_refresh(@_);
	}
return "window.location.reload()";
}

=head2 ui_details(Config, Opened)

Creates a disclosure widget in which information is visible only when
the widget is toggled into an "open" state.

=cut
sub ui_details
{
my ($c, $o) = @_;
if (defined(&theme_ui_details)) {
	return &theme_ui_details(@_);
	}

my $rv;
if (!$c->{'html'}) {
	$c->{'title'} = &html_escape($c->{'title'}, 1);
	$c->{'content'} = &html_escape($c->{'content'}, 1);
	}
$c->{'class'} = " class=\"@{[&quote_escape($c->{'class'})]}\"" if($c->{'class'});
$o = ' open' if ($o);
$rv = "<details$c->{'class'}$o>";
$rv .= "<summary>$c->{'title'}</summary>";
$rv .= "<span>$c->{'content'}</span>";
$rv .= "</details>";
return $rv;
}

=head2 ui_div(data)

Returns passed HTML as div element

=cut
sub ui_div
{
return &theme_ui_div(@_) if (defined(&theme_ui_div));
my ($data) = @_;
return &ui_tag('div', $data, { 'class' => 'ui_div' });
}

=head2 ui_div_row(label, content)

Prints a row without using a table and
places label and content in a way
ui_table_row does

=cut
sub ui_div_row
{
if (defined(&theme_ui_div_row)) {
	return &theme_ui_div_row(@_);
	}
my ($label, $content) = @_;
return "<div class='ui_div_row'><span>$label</span><span>$content</span></div>\n";
}

=head2 ui_space(number)

Prints no breakable space number of given times

=cut
sub ui_space
{
if (defined(&theme_ui_space)) {
	return &theme_ui_space(@_);
	}
my ($number) = @_;
$number ||= 1;
return "<span class='ui_space'>".("&nbsp;" x $number)."</span>\n";
}

=head2 ui_newline(number)

Prints new lines given number of times

=cut
sub ui_newline
{
if (defined(&theme_ui_newline)) {
	return &theme_ui_newline(@_);
	}
my ($number) = @_;
$number ||= 1;
return "<span class='ui_newline'>".("<br>" x $number)."</span>\n";
}

=head2 ui_text_wrap(text)

Wraps any text into span tags

=cut
sub ui_text_wrap
{
if (defined(&theme_ui_text_wrap)) {
	return &theme_ui_text_wrap(@_);
	}
my ($text) = @_;
return "<span class='ui_text_wrap'>$text</span>\n";
}

=head2 ui_element_inline(text)

Wraps any text into span tags

=cut
sub ui_element_inline
{
if (defined(&theme_ui_element_inline)) {
	return &theme_ui_element_inline(@_);
	}
my ($element, $type) = @_;
return "<span data-element='$type' class='ui_element_inline'>$element</span>\n";
}

=head2 ui_paginations(&array, &opts)

Given an array reference, slice it and return hash
reference with pagination buttons, search form
and other elements to be inserted on the page 

=cut
sub ui_paginations
{
return &theme_ui_paginations(@_)
	if (defined(&theme_ui_paginations));

my ($arr, $opts) = @_;
my %rv;
my $id                   = $main::ui_paginations++;
my @arr                  = @{$arr};
my ($script_name)        = $0 =~ /([^\/]*\.cgi)$/;
my $top_offset_px        = int($opts->{'paginations'}->{'offset'}->{'top'}) || 105;
my $bottom_offset_px     = int($opts->{'paginations'}->{'offset'}->{'bottom'}) || 90;
my $row_size_px          = int($opts->{'paginations'}->{'offset'}->{'row'}) || 24;
my $items_per_page       = int($tconfig{'paginate'}) || int($opts->{"paginate${id}"}) || 20;
my $curent_page          = int($opts->{"page${id}"}) || 1;
my $search_term          = &un_urlize($opts->{"search${id}"});
my $pagination_target    = $opts->{'paginations'}->{'paginator'}->{'target'} || $script_name;
my $paginator_wrap_class = $opts->{'paginations'}->{'paginator'}->{'class'}->{'wrap'} || "ui_form_elements_wrapper_paginator";
my $link_page_cls        = $opts->{'paginations'}->{'paginator'}->{'class'}->{'links'} || 'ui_link_pagination';
my $link_search_cls      = $opts->{'paginations'}->{'paginator'}->{'class'}->{'textbox'} || 'ui_textbox_pagination';
my $text_showing_cls     = $opts->{'paginations'}->{'paginator'}->{'class'}->{'text'} || 'ui_showing_items';
my $search_target        = $opts->{'paginations'}->{'search'}->{'target'} || $script_name;
my $search_wrap_class    = $opts->{'paginations'}->{'search'}->{'class'}->{'wrap'} || "ui_form_elements_wrapper_search";
my $search_placeholder   = $opts->{'paginations'}->{'search'}->{'placeholder'} || $text{'ui_searchok'};
my $exported_form        = $opts->{'paginations'}->{'form'};
my $ui_column_colspan    = int($exported_form->{'colspan'} || 4);

# If we have a search string filter existing content
if (ref($arr) eq 'ARRAY' && $arr->[0]) {
    if ($search_term) {
        my @sarr;
          map {
            if (ref($_) eq 'ARRAY') {
                arr: for (my $i = 0; $i <= $#$_; $i++) {
                  push(@sarr, $_), last arr
                        if(index(lc($_->[$i]), lc($search_term)) != -1);
                  }
                }
            if (ref($_) eq 'HASH') {
                hash: foreach my $__ (values %{$_}) {
                  push(@sarr, $_), last hash
                        if(index(lc($__), lc($search_term)) != -1);
                  }
                }
          } @arr;
          @arr = @sarr;
        }

    # Can pagination be done automatically
    # depending on the client screen height?
    my $items_per_page_client = int($opts->{'client_height'} || get_http_cookie('client_height'));
    my $items_per_page =
        $tconfig{'paginate'} ?
          $items_per_page :
            (int($ENV{'HTTP_X_CLIENT_PAGINATE'}) ||
              ($items_per_page_client ?
                ((int(($items_per_page_client -
                    $top_offset_px - $bottom_offset_px) / $row_size_px))) : $items_per_page));
    # If caller wants specific pagination number,
    # e.g. a module config, use that instead
    if ($exported_form && $exported_form->{'paginate'}) {
        $items_per_page = $exported_form->{'paginate'};
        }

    # Sanity check for minimum items per page
   	if ($items_per_page <= 0) {
   		$items_per_page = 2;
   		}

    # Pagination
    my $totals_items_original = scalar(@arr);
    my $total_pages           = ceil(($totals_items_original) / $items_per_page);
    my $total_pages_length    = length($total_pages);

    # Dynamically parse external form elements into query string
    my $exported_form_query  = "";
    if ($exported_form) {
        foreach (keys %{$exported_form}) {
            $exported_form_query .= "$_=@{[&urlize($exported_form->{$_})]}&";
            }
        $exported_form_query =~ s/\&$//;
        }

    # Return pagination jumper only
    # if there is more than one page
    if ($total_pages > 1) {
        my $totals_items_spliced = $totals_items_original;
        my $start_page_with      = $curent_page * $items_per_page;
        $curent_page = $total_pages
            if ($curent_page > $total_pages);
        $curent_page = 1
            if ($curent_page <= 0);

        my $curent_page_prev   = $curent_page - 1;
        my $page_prev_disabled = $curent_page_prev <= 0 ? " disabled" : "";
        my $curent_page_next   = $curent_page + 1;
        my $page_next_disabled = $curent_page_next > $total_pages ? " disabled" : "";
        my $splice_start       = $items_per_page * $curent_page_prev;
        my $splice_end         = $items_per_page;
        @arr                   = splice(@arr, $splice_start, $splice_end);
        $totals_items_spliced  = scalar(@arr);

        #
        # Pagination jumper
        #
        my $paginator_id = 'paginator-form';
        my $paginator_data = "$paginator_id-data";

        # Paginator form
        $rv{'paginator'}->{'form'} =
          &ui_form_start($pagination_target, 'get', undef, "id='$paginator_id${id}'");
        $rv{'paginator'}->{'form'} .= &ui_form_end();

        # Paginator form data
        $rv{'paginator'}->{'form-data'} = &ui_hidden("search${id}", $search_term, "$paginator_id${id}")
            if ($search_term);
        $rv{'paginator'}->{'form-data'} .= &ui_hidden("paginate${id}", $items_per_page, "$paginator_id${id}");

        # Calculate showing start and range numbers
        my $current_showing_start =
          $curent_page == 1 ? 1 : int(($items_per_page * $curent_page + 1) - $items_per_page);
        my $current_showing_range =
          int($current_showing_start + $items_per_page > $totals_items_original ?
            $totals_items_original : $current_showing_start + $items_per_page - 1);

        # Showing items range selector text
        $rv{'paginator'}->{'form-data'} .=
          "<span class='@{[&quote_escape($text_showing_cls)]}-1'>@{[
              &text('paginator_showing_start', $current_showing_start,
                  $current_showing_range, $totals_items_original) ]} </span>";
        #
        # Arrow links
        #
        my $search_term_urlize      = &urlize($search_term);
        my $curent_page_prev_urlize = &urlize($curent_page_prev);
        my $curent_page_next_urlize = &urlize($curent_page_next);
        my $items_per_page_urlize   = &urlize($items_per_page);
        my $total_pages_html_escape = &html_escape($total_pages);

        # Arrow link left
        $rv{'paginator'}->{'form-data'} .=
          &ui_link("$pagination_target?page${id}=$curent_page_prev_urlize".
          	"&search${id}=$search_term_urlize&paginate${id}=$items_per_page_urlize".'&'."$exported_form_query",
              '<span>&nbsp;&#x23F4;&nbsp;</span>',
                "@{[&html_escape($link_page_cls)]} @{[&html_escape($link_page_cls)]}_left$page_prev_disabled",
                "data-formid='$id'");

        # Page number input selector
        $rv{'paginator'}->{'form-data'} .=
          &ui_textbox("page${id}", $curent_page, $total_pages_length, undef, $total_pages_length,
                      "data-class='@{[&quote_escape($link_search_cls)]}' form='$paginator_id${id}'");

        # Out of pages text
        $rv{'paginator'}->{'form-data'} .=
          " <span class='@{[&quote_escape($text_showing_cls)]}-2'>@{[&text('paginator_showing_end',
              $total_pages_html_escape)]}</span>";

        # Arrow link right
        $rv{'paginator'}->{'form-data'} .=
          &ui_link("$pagination_target?page${id}=$curent_page_next_urlize".
            "&search${id}=$search_term_urlize&paginate${id}=$items_per_page_urlize".'&'."$exported_form_query",
              '<span>&nbsp;&#x23F5;&nbsp;</span>',
                "@{[&html_escape($link_page_cls)]} @{[&html_escape($link_page_cls)]}_right$page_next_disabled",
                "data-formid='$id'");

        # Allow listing pages using "Alt + left/right" hotkeys
        if (!$ENV{'HTTP_X_CLIENT_PAGINATE_NO_SCRIPT'}) {
            $rv{'paginator'}->{'form-scripts'} .=
              "<script>\n".
              "  document.addEventListener('keydown', function(a) {\n".
              "      if (a.altKey) {\n".
              "          if (a.which === 37 || a.which === 39) {\n".
              "              let b = 'ui_link_pagination',\n".
              "                  f = 'data-formid=\"$id\"',\n".
              "                  d = 'disabled',\n".
              "                  l = document.querySelector('.' + b + '_left[' + f + ']:not(.' + d + ')'),\n".
              "                  r = document.querySelector('.' + b + '_right[' + f + ']:not(.' + d + ')');\n".
              "              if (a.which === 37 && l && l.checkVisibility()) {\n".
              "                  l.click();\n".
              "              } else if (a.which === 39 && r && r.checkVisibility()) {\n".
              "                  r.click();\n".
              "              }\n".
              "          }\n".
              "      }\n".
              "  });\n".
              "</script>";
            }

        # Dynamically adding external form elements
        if ($exported_form) {
            foreach (keys %{$exported_form}) {
                $rv{'paginator'}->{'form-data'} .=
                    &ui_hidden($_, $exported_form->{$_}, "$paginator_id${id}");
                }
            }
        $rv{'paginator'}->{'form-data'} =
          &ui_form_elements_wrapper($rv{'paginator'}->{'form-data'}, "$paginator_id${id}",
                                    &quote_escape($paginator_wrap_class))
        }
    #
    # Search form
    #
    if ($total_pages > 1 || $search_term) {
        my $search_id   = 'search-form';
        my $search_data = "$search_id-data";

        # Paginator search form
        $rv{'search'}->{'form'} = 
            &ui_form_start($search_target, 'get', undef, "id='$search_id${id}'");
        $rv{'search'}->{'form'} .= &ui_form_end();

        # Paginator search form data
        $rv{'search'}->{'form-data'} .= &ui_hidden("paginate${id}", $items_per_page, "$search_id${id}");
        $rv{'search'}->{'form-data'} .= &ui_hidden("page${id}", 1, "$search_id${id}");
        my $search_placeholder_length = length($search_term) || length($search_placeholder);
        $search_placeholder_length = $search_placeholder_length < 8 ? 8 : $search_placeholder_length;
        $search_placeholder_length = 24 if ($search_placeholder_length >= 24);
        
        # Search box
        $rv{'search'}->{'form-data'} .=
          &ui_textbox("search${id}", $search_term, $search_placeholder_length, undef, undef,
            "data-class='@{[&quote_escape($link_search_cls)]}_search' ".
            "placeholder='@{[&quote_escape($search_placeholder)]}' form='$search_id${id}'");
        
        # Search reset using JS
        $rv{'search'}->{'form-data'} .=
          &ui_reset('&#x26CC;', undef,
            "onclick='document.getElementById(\"$search_id${id}\").search${id}.value = \"\";".
            "document.getElementById(\"$search_id${id}\").submit()'");
        
        # Dynamically adding external form elements
        if ($exported_form) {
            foreach (keys %{$exported_form}) {
                $rv{'search'}->{'form-data'} .=
                    &ui_hidden($_, $exported_form->{$_}, "$search_id${id}");
                }
            }
        $rv{'search'}->{'form-data'} =
            &ui_form_elements_wrapper($rv{'search'}->{'form-data'},
                "$search_id${id}", &quote_escape($search_wrap_class));
        
        # Search no results
        $rv{'search'}->{'no-results'} =
          &ui_columns_row([&text('paginator_nosearchrs', &html_escape($search_term))],
                          ['colspan="'.$ui_column_colspan.'" align="center"']);
        }

        # Elements for the parent form, so after submission to
        # make sure that we return to the right paginated page
        $rv{'form'} = &ui_hidden("page${id}", $curent_page).
                      &ui_hidden("paginate${id}", $items_per_page).
                      &ui_hidden("search${id}", $search_term);
    }
@$arr = @arr;
return \%rv;
}

=head2 ui_hide_outside_of_viewport(elem)

Prints element if not in viewport. Useful
when printing top and bottom controls as
printing bottom controls only if it's not
in view already

=cut
sub ui_hide_outside_of_viewport
{
my ($elem_sel) = @_;
$elem_sel ||= "[data-outside-of-viewport]";
if (defined(&theme_ui_hide_outside_of_viewport)) {
	return &theme_ui_hide_outside_of_viewport(@_);
	}
return <<EOF;
<script type='text/javascript'>
 try {
     (function() {
        var elems = document.querySelectorAll('$elem_sel'),
            i;
        for (i = 0; i < elems.length; i++) {
          if (elems[i].offsetTop < window.innerHeight) {
              elems[i].style.display = "none";
          }
        }
    })();
  } catch (e) {};
</script>
EOF
}

=head2 ui_read_file_contents_limit(\%data)

Reads file content with options and
returns head and/or tail separated with
chomped message

=cut
sub ui_read_file_contents_limit
{
if (defined(&theme_ui_read_file_contents_limit)) {
	return &theme_ui_read_file_contents_limit(@_);
	}
my ($opts)  = @_;
my $binary  = -s $opts->{'file'} >= 128 && -B $opts->{'file'};
my $data = &read_file_contents_limit($opts->{'file'}, $opts->{'limit'}, $opts);
my $error = $data->{'error'};
if ($error) {
    return $error;
	}
my $nonulls = sub {
    $_[0] =~ s/[^[:print:]\n\r\t]/\ /g;
    return $_[0];
	};
my $head     = $data->{'head'};
my $tail     = $data->{'tail'};
my $chomped  = $data->{'chomped'};
my $fsize    = $data->{'size'};
my $flimit   = $data->{'limit'};
my $msg_type = !$head &&  $tail ? '_tail' :
                $head && !$tail ? '_head' : undef;
my $nlines   = $nslines = $nelines = "\n" x 10;
$nslines     = undef if (!$head);
$nelines     = undef if (!$tail);
my $chomped_msg;
$chomped_msg =
"${nslines}[--- @{[&text(\"file_truncated_message$msg_type\", 
                         &nice_size($flimit), 
                         &nice_size($chomped),
                         &nice_size($fsize))]} ---]$nelines"
  if ($chomped);

# Trim nulls
$head = &$nonulls($head)
  if ($binary && $head);
$tail = &$nonulls($tail)
  if ($binary && $tail);

# Return data
if ($head && $tail) {
    return $head . $chomped_msg . $tail;
	}
if ($tail) {
    return $chomped_msg . $tail;
	}
if ($head) {
    return $head . $chomped_msg;
	}
}

=head2 ui_note(text, [whitespace-count])

Returns a note as a small font size text

=cut
sub ui_note
{
return &theme_ui_note(@_) if (defined(&theme_ui_note));
my ($text, $whitespace) = @_;
$whitespace //= 2;
my $whitespace_str = "&nbsp;" x $whitespace;
return "<font class='ui_note' style='font-size:92%;opacity:0.66'>".
	"${whitespace_str}ⓘ&nbsp;&nbsp;$text".
	"</font>";
}

=head2 ui_brh()

Returns a break line with ability to style height

=cut
sub ui_brh
{
return &theme_ui_brh() if (defined(&theme_ui_brh));
return "<br data-x-br>\n";
}

# ui_tag_start(tag, [attrs])
# Function to create an opening HTML tag with optional attributes.
# Attributes are passed as a hash reference and its values are quote escaped.
sub ui_tag_start
{
return theme_ui_tag_start(@_) if (defined(&theme_ui_tag_start));
my ($tag, $attrs) = @_;

# Ensure every tag gets a proper marker class
$attrs ||= {};
$attrs->{'class'} = defined($attrs->{class})
	? "ui--$tag $attrs->{class}"
	: "ui--$tag";

# Start building tag
my $rv = "<$tag";

# Add attributes if provided
if ($attrs && ref($attrs) eq 'HASH') {
	foreach my $key (keys %$attrs) {
		my $value = $attrs->{$key};
		if (defined($value)) {
			$value = &quote_escape($value, '"');
			$value =~ tr/\n\t//d;
			$value =~ s/\s+/ /g;
			$rv .= " $key=\"$value\"" ;
			}
		elsif ($key) {
			$rv .= " $key";
			}
		}
	}

# Close the opening tag
$rv .= ">";

# Handle special case for <html> tag
$rv = "<!DOCTYPE html>\n$rv" if ($tag eq 'html');

return $rv;
}

# ui_tag_content(content)
# Function to handle the content of an HTML tag.
sub ui_tag_content
{
return theme_ui_tag_content(@_) if (defined(&theme_ui_tag_content));
my ($content) = @_;
my $rv;
$rv = $content if (defined($content));
return $rv;
}

# ui_tag_end(tag)
# Function to create a closing HTML tag.
sub ui_tag_end
{
return theme_ui_tag_end(@_) if (defined(&theme_ui_tag_end));
my ($tag) = @_;
return "</$tag>\n";
}

# ui_tag(tag, [content], [attrs])
# Function to create a complete HTML tag with optional content and attributes.
sub ui_tag
{
return theme_ui_tag(@_) if (defined(&theme_ui_tag));
my ($tag, $content, $attrs) = @_;
my $rv = ui_tag_start($tag, $attrs);
$rv .= ui_tag_content($content) if (defined($content));
my %void_tags = map { $_ => 1 }
	qw(
		area base br col embed hr img input link
		meta param source track wbr
	);
$rv .= ui_tag_end($tag) if (!exists($void_tags{lc($tag)}));
return $rv;
}

# ui_alert(content, type, [icon], [attrs])
# Generates an HTML alert with the specified content, type, and optional icon
# and attributes.
#
# Parameters:
#   content - The main message/body of the alert
#   type    - Alert style: "success", "info", "warning", "danger", "danger-fatal"
#   icon    - Optional. Controls icon and title display:
#             - If undefined: uses default icon and title for the alert type
#             - If string: uses as icon class with default title
#             - If array ref [icon, title, no_break]:
#               - icon: Icon class
#               - title: Custom title (if undef, uses default for type)
#               - no_break: If 1, no line break after title (space instead)
#   attrs   - Optional hash ref of additional HTML attributes for the alert div
#
# Examples:
#   ui_alert("Operation completed", "success");
#   ui_alert("Access denied", "danger", "fa-lock");
#   ui_alert("Settings changed", "info", ["fa-info-circle", "", 1]);
#   ui_alert("Server offline", "warning", undef, {id => "server-status"});
sub ui_alert
{
return theme_ui_alert(@_) if (defined(&theme_ui_alert));
my ($content, $type, $icon, $attrs) = @_;

# Default alert type
$type ||= 'info';

# Default icons and titles based on type
my %type_defaults = (
	'success' => {
		'icon' => 'fa-check-circle',
		'title' => $text{'ui_success'}
	},
	'info' => {
		'icon' => 'fa-info-circle',
		'title' => $text{'ui_info'}
	},
	'warning' => {
		'icon' => 'fa-exclamation-triangle',
		'title' => $text{'ui_warning'}
	},
	'danger' => {
		'icon' => 'fa-bolt',
		'title' => $text{'ui_error'}
	},
	'danger-fatal' => {
		'icon' => 'fa-exclamation-triangle',
		'title' => $text{'ui_error_fatal'}
	}
);

my $use_icon = '';
my $use_title = '';
my $use_br = 1;  # Default to using line break

# Process icon parameter
if (!defined($icon)) {
	# Use defaults based on type
	if ($type_defaults{$type}) {
		$use_icon = $type_defaults{$type}{'icon'};
		$use_title = $type_defaults{$type}{'title'};
		}
	}
elsif (ref($icon)) {
	# Array format [icon_class, title, no_br]
	if (defined($icon->[0])) {
		$use_icon = $icon->[0];
		}
	else {
		$use_icon = $type_defaults{$type}{'icon'};
		}

	# Title: if provided use it, else use default for type
	if (defined($icon->[1])) {
		$use_title = $icon->[1];
		}
	elsif ($type_defaults{$type}) {
		$use_title = $type_defaults{$type}{'title'};
		}

	# Line break flag: 1 = no break, anything else = break
	$use_br = $icon->[2] ? 0 : 1 if (defined($icon->[2]));
	}
else {
	# String format: just the icon class
	$use_icon = $icon;
	$use_title = $type_defaults{$type} ? $type_defaults{$type}{'title'} : '';
	}

# Prepare attributes for the alert div
my $all_attrs = $attrs || {};

# Add alert class
my $class = 'alert';
$class .= ' alert-'.$type if ($type);

$all_attrs->{'class'} = $all_attrs->{'class'}
	? "$class $all_attrs->{'class'}"
	:  $class;

# Build alert
my $rv = '';

# Start alert container
$rv .= ui_tag_start('div', $all_attrs);

# Add icon and title if either is available
if ($use_icon || $use_title) {
	# Add icon if available
	if ($use_icon) {
		$rv .= ui_tag('i', undef, { 'class' => "fa fa-fw $use_icon" });
		$rv .= ' ';
		}

	# Add title if available
	if ($use_title) {
		$rv .= ui_tag('strong', $use_title);
		}

	# Add line break if needed
	if ($use_br) {
		$rv .= '<br>';
		}
	else {
		$rv .= ' ';
		}
	$rv .= "\n";
	}

# Add main content
$rv .= ui_tag_content(ui_tag('span', $content));

# Close alert container
$rv .= ui_tag_end('div');

return $rv;
}

# ui_button_icon(text, icon, [attrs])
# Creates a button with an icon and text
# Parameters:
#   text    - The text/label for the button
#   icon    - Icon class
#   attrs   - Optional hash ref of additional HTML attributes
#
# Examples:
#   ui_button_icon("Save", "save", {class => "primary"})
#   ui_button_icon("Delete", "trash", {type => "submit", name => "delete"})
sub ui_button_icon
{
return theme_ui_button_icon(@_) if (defined(&theme_ui_button_icon));
my ($text, $icon, $attrs) = @_;

# Default to button type if not specified
my $all_attrs = $attrs || {};
$all_attrs->{'type'} ||= 'button';

# Button class
my $btn_cls = $all_attrs->{'class'};
$all_attrs->{'class'} = "btn " . ($btn_cls 
	? ($btn_cls =~ /^btn-/ ? $btn_cls
	: "btn-$btn_cls") : 'btn-default');

# Build the button
my $rv = ui_tag_start('button', $all_attrs);

# Add icon if specified
if ($icon) {
	my $icon_class = "";

	# Check if icon specifies a specific bundle (fa2)
	if ($icon =~ /^fa2-/) {
		$icon_class = "fa2 $icon";
		}
	# Check if it already has fa- prefix
	elsif ($icon =~ /^fa-/) {
		$icon_class = "fa $icon";
		}
	# Otherwise add the default fa- prefix
	else {
		$icon_class = "fa fa-$icon";
		}
	$rv .= ui_tag('i', undef, {'class' => $icon_class});
	$rv .= "&nbsp;&nbsp;";
	}

# Add text
$rv .= ui_tag_content($text) if defined($text);

# Close the button
$rv .= ui_tag_end('button');

return $rv;
}

# ui_link_icon(href, text, [icon], [attrs])
# Creates a link with an icon and text
# Parameters:
#   href    - The URL for the link
#   text    - The text/label for the link
#   icon    - Icon class
#   attrs   - Optional hash ref of additional HTML attributes
#
# Examples:
#   ui_link_icon("view.cgi?id=1", "View Details", "eye", {class => "primary"})
#   ui_link_icon("docs.html", "Documentation", "book", {target => "_blank"})
sub ui_link_icon
{
return theme_ui_link_icon(@_) if (defined(&theme_ui_link_icon));
my ($href, $text, $icon, $attrs) = @_;

# Create attribute hash and set href
my $all_attrs = $attrs || {};
$all_attrs->{'href'} = $href if (defined($href));

# Button class
my $btn_cls = $all_attrs->{'class'};
$all_attrs->{'class'} = "btn " . ($btn_cls 
	? ($btn_cls =~ /^btn-/ ? $btn_cls
	: "btn-$btn_cls") : 'btn-default');

# Build the link
my $rv = ui_tag_start('a', $all_attrs);

# Add icon if specified
if ($icon) {
	my $icon_class = "";

	# Check if icon specifies a specific bundle (fa2)
	if ($icon =~ /^fa2-/) {
		$icon_class = "fa2 $icon";
		}
	# Check if it already has fa- prefix
	elsif ($icon =~ /^fa-/) {
		$icon_class = "fa $icon";
		}
	# Otherwise add the default fa- prefix
	else {
		$icon_class = "fa fa-$icon";
		}
	$rv .= ui_tag('i', undef, {'class' => $icon_class});
	$rv .= "&nbsp;&nbsp;";
	}

# Add text
$rv .= ui_tag_content($text) if (defined($text));

# Close the link
$rv .= ui_tag_end('a');

return $rv;
}

# ui_icon(icon, [attrs])
# Creates an icon element
# Parameters:
#   icon    - Icon class (with or without fa- prefix)
#   attrs   - Optional hash ref of additional HTML attributes
#
# Examples:
#   ui_icon("search")                  # Standard icon
#   ui_icon("fa2-warning")             # Extended icon set
sub ui_icon
{
return theme_ui_icon(@_) if (defined(&theme_ui_icon));
my ($icon, $attrs) = @_;

return "" if (!defined($icon)) || $icon eq '';

# Create attribute hash
my $all_attrs = $attrs || {};

# Process icon class
my $icon_class = "";

# Check if icon is in a specific bundle
if ($icon =~ /^fa2-/) {
	$icon_class = "fa2 $icon";
	}
elsif ($icon =~ /^fa-/) {
	$icon_class = "fa $icon";
	}
else {
	$icon_class = "fa fa-$icon";
	}

# Make icon always fixed width unless specified otherwise
$icon_class .= " fa-fw" if ($all_attrs->{'class'} !~ /fa-dw/);

# Add icon class to any existing classes
if ($all_attrs->{'class'}) {
	$all_attrs->{'class'} .= " $icon_class";
} else {
	$all_attrs->{'class'} = $icon_class;
	}

# Build the icon tag
return ui_tag('i', undef, $all_attrs);
}

# ui_br([attrs])
# Creates a line break element
sub ui_br
{
return theme_ui_br(@_) if (defined(&theme_ui_br));
my ($attrs) = @_;
return ui_tag('br', undef, $attrs);
}

# ui_p(content, [attrs])
# Creates a paragraph element with optional content
sub ui_p
{
return theme_ui_p(@_) if (defined(&theme_ui_p));
my ($content, $attrs) = @_;
return ui_tag('p', $content, $attrs);
}

=head2 ui_text_mask(text, [tag], [extra_class])

Returns an HTML string with the given text hidden inside a tag that only shows
on hover. If a second parameter is given, it is used as the outer tag that
triggers the hover (default is "td"). If a third parameter is provided,
it is added as an extra class to both the tag and its style.

=cut
sub ui_text_mask
{
return &theme_ui_text_mask(@_) if (defined(&theme_ui_text_mask));
my ($text, $tag, $extra_class) = @_;
my $class = 'hover-mask';
my $classcss = ".$class";
if ($extra_class) {
	$class .= " $extra_class";
	$classcss .= ".$extra_class";
	}
$tag ||= 'td';
my $style_content = <<"CSS";
x-ui-text-mask${classcss} {
	position: relative;
	display: inline-block;
	color: transparent;
	transition:color .25s ease;
}
x-ui-text-mask${classcss}::after{
	content: attr(data-mask);
	position: absolute;
	inset: 0;
	white-space: nowrap;
	color: var(--ui-password-mask-color, #000);
	pointer-events: none;
	transition: opacity .25s ease;
}
$tag:has(>*>x-ui-text-mask${classcss}):hover x-ui-text-mask${classcss},
$tag:has(>x-ui-text-mask${classcss}):hover x-ui-text-mask${classcss}{
	color: inherit;
}
$tag:has(>*>x-ui-text-mask${classcss}):hover x-ui-text-mask${classcss}::after,
$tag:has(>x-ui-text-mask${classcss}):hover x-ui-text-mask${classcss}::after{
	opacity: 0;
}
CSS
my $rv = '';
$rv .= &ui_tag('style', $style_content, { type => 'text/css' })
	if (!$main::ui_text_mask_donecss->{"$tag$class"}++);
$rv .= &ui_tag('x-ui-text-mask', $text,
	{ 'class' => $class, 'data-mask' => '••••••••' });
return $rv;
}

####################### widget functions

=head1 Widgets

The functions below add the UI elements that were missing from this
library — cards, layout grids, description lists, stat tiles, badges,
lists, activity feeds, empty states and progress bars — styled
by the widget stylesheet served from C<unauthenticated/css/ui-lib.css> with a
small behavior script in C<unauthenticated/js/ui-lib.js>.

They do not replace the existing functions. Inside a page area started by
ui_page_start, existing tabs, forms, tables and buttons retain their theme
styling. Modules keep using those functions and reach for the functions
below for the new kinds of content.

Example code :

 ui_print_header(undef, $text{'index_title'}, "");

 print ui_page_start({ 'desc' => $text{'index_desc'} });

 print ui_grid([
     ui_card({ 'title' => $text{'index_status'},
               'actions' => ui_badge($text{'index_running'}, 'success'),
               'body'  => ui_dl([
                   [ $text{'index_version'}, html_escape($version) ],
                   [ $text{'index_uptime'}, html_escape($uptime) ],
                   ]) }),
     ui_card({ 'title' => $text{'index_activity'},
               'body'  => ui_stats(\@stats) }),
     ]);

 print ui_page_end();
 ui_print_footer("/", $text{'index'});

Design principles :

=item * Options are named. Widget options are passed in a hash reference
after any positional content arguments, so new options can be added
without breaking callers.

=item * Functions return HTML strings, so widgets can be freely composed.

=item * Escaping is part of the contract. Text-valued options (C<title>,
C<desc>, C<label>, C<text>, C<help>, C<meta>, C<when>, C<value>) are
HTML-escaped by the library. HTML-valued options (C<body>, C<content>,
C<actions>, C<footer> and supported C<*_html> variants of text options) are
emitted as-is and are expected to be built from other ui functions.
Description-list values given in the array form are HTML for
composability.

=item * Layout is CSS, not markup. Widgets emit flat, semantic elements
built with ui_tag, carrying stable C<ui_*> classes, and the stylesheet
arranges them with grid and flexbox.

=item * Behavior is unobtrusive. Interactive elements carry C<data-ui-*>
attributes which ui-lib.js wires up with delegated event listeners, so no
inline event handlers are generated. A C<data-ui-confirm> attribute
passed in the tags of an existing button asks for confirmation, and
ui_search can filter table rows or list entries client-side.

=item * Theming is a contract, not a rewrite. Colors and spacing
come from C<--ui-*> CSS custom properties which a theme can redefine on
C<.ui_page>, and every element keeps a stable class for deeper styling. A built-in
dark palette is available by setting C<data-ui-scheme> to C<dark> (or
C<auto> to follow the browser) on any ancestor element, or via the
scheme option of ui_page_start. A theme can still replace any function
by defining C<theme_ui_*>, but should rarely need to.

Widget states used throughout are C<success>, C<warning>, C<danger>,
C<info> and C<neutral>. The aliases C<ok>, C<warn>, C<error>, C<err> and
C<off> are accepted.

=cut

# Per-request state, kept in main:: so it is shared no matter which
# package the library was loaded into
$main::ui_page_assets_done ||= 0;

# Valid widget states, and aliases accepted for convenience
my %ui_states = (
	'success' => 'success',	'ok' => 'success',
	'warning' => 'warning',	'warn' => 'warning',
	'danger' => 'danger',	'error' => 'danger',	'err' => 'danger',
	'info' => 'info',
	'neutral' => 'neutral',	'off' => 'neutral',
	);

# Built-in icon set, as 16x16 SVG path data drawn with the current color.
# Each icon is one or more path definitions joined with |
my %ui_svg_icons = (
	'check'          => 'M3.5 8.5l3 3 6-6.5',
	'check-circle'   => 'M8 14.25A6.25 6.25 0 1 0 8 1.75a6.25 6.25 0 0 0 0 12.5z|M5.4 8.3l1.8 1.9 3.4-4',
	'x'              => 'M4.5 4.5l7 7|M11.5 4.5l-7 7',
	'x-circle'       => 'M8 14.25A6.25 6.25 0 1 0 8 1.75a6.25 6.25 0 0 0 0 12.5z|M6 6l4 4|M10 6l-4 4',
	'info-circle'    => 'M8 14.25A6.25 6.25 0 1 0 8 1.75a6.25 6.25 0 0 0 0 12.5z|M8 7.4v3.4|M8 5.1h.01',
	'question-circle' => 'M8 14.25A6.25 6.25 0 1 0 8 1.75a6.25 6.25 0 0 0 0 12.5z|M6.2 6.2a1.8 1.8 0 1 1 2.6 1.8c-.55.28-.8.6-.8 1.15v.25|M8 11.3h.01',
	'warning'        => 'M8 2.6l6.4 10.4H1.6L8 2.6z|M8 6.8v2.7|M8 11.3h.01',
	'search'         => 'M7 11.25a4.25 4.25 0 1 0 0-8.5 4.25 4.25 0 0 0 0 8.5z|M10.2 10.2l3.3 3.3',
	'external'       => 'M6.5 4H4a1.5 1.5 0 0 0-1.5 1.5V12A1.5 1.5 0 0 0 4 13.5h6.5A1.5 1.5 0 0 0 12 12V9.5|M9.5 2.5h4v4|M13.3 2.7L7.8 8.2',
	'chevron-down'   => 'M4 6l4 4 4-4',
	'chevron-up'     => 'M4 10l4-4 4 4',
	'chevron-right'  => 'M6 4l4 4-4 4',
	'chevron-left'   => 'M10 4L6 8l4 4',
	'arrow-right'    => 'M2.8 8h10|M9 4.2L12.8 8 9 11.8',
	'plus'           => 'M8 3v10|M3 8h10',
	'minus'          => 'M3 8h10',
	'refresh'        => 'M13.2 6.2A5.5 5.5 0 0 0 3.4 4.6|M2.8 9.8a5.5 5.5 0 0 0 9.8 1.6|M13.5 2.5v3.7H9.8|M2.5 13.5V9.8h3.7',
	'play'           => 'M5.5 3.6v8.8L12.5 8z',
	'stop'           => 'M4.7 4.7h6.6v6.6H4.7z',
	'power'          => 'M8 2.2v5.6|M11.4 4.4a5.4 5.4 0 1 1-6.8 0',
	'clock'          => 'M8 14.25A6.25 6.25 0 1 0 8 1.75a6.25 6.25 0 0 0 0 12.5z|M8 4.8V8l2.2 1.4',
	'shield'         => 'M8 1.8l5.2 2v4c0 3.2-2.2 5.3-5.2 6.4C4.8 13.1 2.8 11 2.8 7.8v-4z',
	'server'         => 'M2 3.2h12v4.2H2z|M2 8.6h12v4.2H2z|M4.6 5.3h.01|M4.6 10.7h.01',
	'gear'           => 'M8 10.4a2.4 2.4 0 1 0 0-4.8 2.4 2.4 0 0 0 0 4.8z|M8 1.8v2|M8 12.2v2|M1.8 8h2|M12.2 8h2|M3.6 3.6L5 5|M11 11l1.4 1.4|M12.4 3.6L11 5|M5 11l-1.4 1.4',
	'user'           => 'M8 8a2.6 2.6 0 1 0 0-5.2A2.6 2.6 0 0 0 8 8z|M2.9 13.6a5.4 5.4 0 0 1 10.2 0',
	'trash'          => 'M2.8 4.2h10.4|M6.2 4V2.8h3.6V4|M4.2 4.4l.5 8a1.4 1.4 0 0 0 1.4 1.3h3.8a1.4 1.4 0 0 0 1.4-1.3l.5-8|M6.6 7v4|M9.4 7v4',
	'download'       => 'M8 2.5v7|M4.8 6.7L8 9.9l3.2-3.2|M3 12.5h10',
	'upload'         => 'M8 9.5v-7|M4.8 5.3L8 2.1l3.2 3.2|M3 12.5h10',
	'edit'           => 'M9.8 3.1l3.1 3.1L6 13.1l-3.6.5.5-3.6z|M8.6 4.3l3.1 3.1',
	'terminal'       => 'M1.8 3h12.4v10H1.8z|M4.5 6.3L7 8.4l-2.5 2.1|M8.5 10.7h3',
	'filter'         => 'M2.5 3.5h11L9.8 8.4v4.3l-3.6-1.6V8.4z',
	'book'           => 'M8 3.4C6.9 2.6 5.3 2.2 2.8 2.3v10.3c2.5-.1 4.1.3 5.2 1.1 1.1-.8 2.7-1.2 5.2-1.1V2.3c-2.5-.1-4.1.3-5.2 1.1z|M8 3.4v10.3',
	'globe'          => 'M8 14.25A6.25 6.25 0 1 0 8 1.75a6.25 6.25 0 0 0 0 12.5z|M2 8h12|M8 1.9c1.7 1.8 2.6 3.9 2.6 6.1S9.7 12.3 8 14.1C6.3 12.3 5.4 10.2 5.4 8S6.3 3.7 8 1.9z',
	'dot'            => 'M8 10.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
	);

# Icons drawn filled rather than stroked
my %ui_svg_icons_filled = ( 'play' => 1, 'stop' => 1, 'dot' => 1 );

# Default badge icons per state
my %ui_state_icons = (
	'success' => 'check-circle',
	'warning' => 'warning',
	'danger'  => 'x-circle',
	'info'    => 'info-circle',
	);

# _ui_state(state)
# Maps a caller-supplied state name or alias to a canonical state class
# suffix, defaulting to neutral
sub _ui_state
{
my ($state) = @_;
return $state && $ui_states{$state} ? $ui_states{$state} : 'neutral';
}

# _ui_text(&opts, key)
# Returns the escaped text option, preferring a raw key_html variant when
# the caller supplied pre-built HTML. Returns undef if both are absent or empty.
sub _ui_text
{
my ($opts, $key) = @_;
return $opts->{$key.'_html'} if (defined($opts->{$key.'_html'}) &&
				 $opts->{$key.'_html'} ne '');
return &html_escape($opts->{$key}) if (defined($opts->{$key}) &&
				       $opts->{$key} ne '');
return undef;
}

# _ui_attrs(&attrs)
# Returns a copy of the given attribute hash without the undefined or empty
# values, ready for ui_tag. Boolean attributes like checked are added by the
# callers afterwards with an undefined value, which ui_tag_start emits bare.
sub _ui_attrs
{
my ($attrs) = @_;
my %rv;
foreach my $key (keys %$attrs) {
	my $value = $attrs->{$key};
	next if (!defined($value) || $value eq '');
	$rv{$key} = $value;
	}
return \%rv;
}

# _ui_class(@classes)
# Joins the given class names, skipping empty ones
sub _ui_class
{
return join(" ", grep { defined($_) && $_ ne '' } @_);
}

# _ui_join(&items)
# Joins a list of HTML fragments, accepting either an array reference or a
# single pre-built string, and skipping empty entries
sub _ui_join
{
my ($items) = @_;
return "" if (!defined($items));
return $items if (!ref($items));
return join("\n", grep { defined($_) && $_ ne '' } @$items);
}

# _ui_block(tag, content, [&attrs])
# Returns a block element whose content starts and ends on its own line,
# so that nested widgets stay readable in the page source
sub _ui_block
{
my ($tag, $content, $attrs) = @_;
return &ui_tag($tag, "\n".$content."\n", $attrs);
}

=head2 ui_svg_icon(name, [&opts])

Returns inline SVG for a named icon from the built-in set, drawn with the
current text color. Unlike ui_icon, this does not depend on any theme
icon font. Options are :

=item size - Pixel size, defaulting to 16.

=item class - Additional CSS classes for the <svg> element.

=item title - Accessible label. Without it the icon is hidden from
screen readers.

=cut
sub ui_svg_icon
{
return &theme_ui_svg_icon(@_) if (defined(&theme_ui_svg_icon));
my ($name, $opts) = @_;
$opts ||= {};
my $paths = $ui_svg_icons{$name};
return "" if (!$paths);
my $size = int($opts->{'size'} || 16);
my %attrs = ( 'class' => &_ui_class('ui_svg_icon', $opts->{'class'}),
	      'width' => $size,
	      'height' => $size,
	      'viewBox' => '0 0 16 16',
	      'fill' => $ui_svg_icons_filled{$name} ? 'currentColor' : 'none',
	      'stroke' => 'currentColor',
	      'stroke-width' => '1.5',
	      'stroke-linecap' => 'round',
	      'stroke-linejoin' => 'round' );
if (defined($opts->{'title'}) && $opts->{'title'} ne '') {
	$attrs{'role'} = 'img';
	$attrs{'aria-label'} = $opts->{'title'};
	}
else {
	$attrs{'aria-hidden'} = 'true';
	}
my $rv = &ui_tag_start('svg', \%attrs);
foreach my $p (split(/\|/, $paths)) {
	$rv .= &ui_tag('path', undef, { 'd' => $p });
	}
$rv .= &ui_tag_end('svg');
return $rv;
}

=head2 ui_code(text)

Returns the given text styled as inline code.

=cut
sub ui_code
{
return &theme_ui_code(@_) if (defined(&theme_ui_code));
my ($str) = @_;
return &ui_tag('code', &html_escape($str), { 'class' => 'ui_code' });
}

=head2 ui_tip(content-html, tip)

Wraps arbitrary HTML content so the given plain-text tip is shown on
hover by the theme's tooltip, the same one ui_help uses. For a plain
question-mark help bubble, use ui_help instead.

=cut
sub ui_tip
{
return &theme_ui_tip(@_) if (defined(&theme_ui_tip));
my ($content, $tip) = @_;
return &ui_tag('span', $content,
	{ 'class' => 'ui_tip', 'aria-label' => &html_strip($tip),
	  'data-tooltip' => undef });
}

####################### page structure functions

=head2 ui_page_assets([&opts])

Returns the <link> and <script> tags that load the widget stylesheet and
behavior script, exactly once per page. This is normally called
automatically by ui_page_start, but can also be passed in the head-stuff
parameter of ui_print_header to load the assets from the <head> section.
Options are :

=item nojs - Set to 1 to skip the behavior script.

=cut
sub ui_page_assets
{
return &theme_ui_page_assets(@_) if (defined(&theme_ui_page_assets));
my ($opts) = @_;
$opts ||= {};
return "" if ($main::ui_page_assets_done++);
my $pfx = &get_webprefix();

# Each file is linked with its modification time as the cache key, so a
# browser picks up a changed file at once instead of keeping the copy it
# cached under the Webmin version, which stays the same between edits
my $ver = &get_webmin_version() || 0;
my $key = sub {
	my ($file) = @_;
	my @st = stat("$root_directory/unauthenticated/$file");
	return @st ? $st[9] : $ver;
	};
my $rv = &ui_tag('link', undef,
	{ 'rel' => 'stylesheet',
	  'href' => "$pfx/unauthenticated/css/ui-lib.css?".
		    $key->("css/ui-lib.css") })."\n";
$rv .= &ui_tag('script', undef,
	{ 'src' => "$pfx/unauthenticated/js/ui-lib.js?".
		   $key->("js/ui-lib.js"),
	  'defer' => undef }) if (!$opts->{'nojs'});
return $rv;
}

=head2 ui_page_start([&opts])

Returns HTML for the start of a widget page area, including the assets (if
not yet loaded) and an optional page header with a description and
actions. The page title itself is printed by ui_print_header as usual.
All other widgets, and any existing tabs, forms and tables that
should get the widget styling, should be placed between this and
ui_page_end. Options are :

=item title - Large page title text, for pages that do not already show
one in the theme header.

=item desc - Short description shown under the title.

=item help - URL of a help or documentation page, shown as a link with a
question-mark icon on the right.

=item help_title - Text for the help link, defaulting to "Help".

=item actions - HTML (or array ref of HTML fragments) for buttons or
links shown at the top right.

=item scheme - Color scheme for the page area. By default the light
palette is used; set to dark for the built-in dark palette, or to auto
to follow the browser's preferred color scheme. A theme can instead set
a data-ui-scheme attribute on the body or html element to control all
widget pages at once, or redefine the --ui-* CSS custom properties for
full control.

=item class - Additional CSS classes for the wrapper element.

=item id - HTML id for the wrapper element.

=cut
sub ui_page_start
{
return &theme_ui_page_start(@_) if (defined(&theme_ui_page_start));
my ($opts) = @_;
$opts ||= {};
my $rv = &ui_page_assets();
my $scheme = $opts->{'scheme'} && $opts->{'scheme'} =~ /^(dark|auto)$/ ?
		$opts->{'scheme'} : undef;
$rv .= &ui_tag_start('div', &_ui_attrs({
	'class' => &_ui_class('ui_page', $opts->{'class'}),
	'data-ui-scheme' => $scheme,
	'id' => $opts->{'id'} }))."\n";

# Optional header with title, description, help link and actions
my $title = &_ui_text($opts, 'title');
my $desc = &_ui_text($opts, 'desc');
my $actions = &_ui_join($opts->{'actions'});
my $help = "";
if ($opts->{'help'}) {
	my $htitle = defined($opts->{'help_title'}) ? $opts->{'help_title'} :
			$text{'ui_page_help'} || 'Help';
	$help = &ui_tag('a',
		&ui_svg_icon('question-circle', { 'size' => 15 }).
		&ui_tag('span', &html_escape($htitle)),
		{ 'class' => 'ui_page_help', 'href' => $opts->{'help'} });
	}
if (defined($title) || defined($desc) || $actions || $help) {
	my $titles = "";
	$titles .= &ui_tag('h1', $title, { 'class' => 'ui_page_title' })
		if (defined($title));
	$titles .= &ui_tag('p', $desc, { 'class' => 'ui_page_desc' })
		if (defined($desc));
	my $head = &_ui_block('div', $titles, { 'class' => 'ui_page_titles' });
	$head .= &ui_tag('div', $help.$actions, { 'class' => 'ui_page_actions' })
		if ($actions || $help);
	$rv .= &_ui_block('header', $head, { 'class' => 'ui_page_head' });
	}
return $rv;
}

=head2 ui_page_end

Returns HTML ending a page area started by ui_page_start.

=cut
sub ui_page_end
{
return &theme_ui_page_end(@_) if (defined(&theme_ui_page_end));
return &ui_tag_end('div');
}

####################### layout functions

=head2 ui_grid(&items, [&opts])

Returns HTML for a responsive grid of the given HTML fragments, typically
cards. By default columns are sized automatically to fit at least the
minimum width, wrapping on narrow screens. Options are :

=item cols - Fixed number of equal columns instead of automatic sizing.

=item min - Minimum column width for automatic mode, such as 320px.

=item template - Raw grid-template-columns value for unequal column
layouts, such as "minmax(280px,1fr) minmax(0,2fr)". Overrides cols. On
narrow screens the grid always collapses to one column.

=item gap - Gap between cells, as a CSS length.

=item class - Additional CSS classes.

=cut
sub ui_grid
{
return &theme_ui_grid(@_) if (defined(&theme_ui_grid));
my ($items, $opts) = @_;
$opts ||= {};
my @items = grep { defined($_) && $_ ne '' } @$items;
return "" if (!@items);
my $fixed = $opts->{'cols'} || $opts->{'template'};
my @style;
push(@style, "--ui-grid-cols:".int($opts->{'cols'}))
	if ($opts->{'cols'} && !$opts->{'template'});
push(@style, "--ui-grid-template:".$opts->{'template'})
	if ($opts->{'template'});
push(@style, "--ui-grid-min:".$opts->{'min'}) if ($opts->{'min'});
push(@style, "--ui-gap:".$opts->{'gap'}) if ($opts->{'gap'});
return &_ui_block('div', join("\n", @items), &_ui_attrs({
	'class' => &_ui_class('ui_grid', $fixed ? 'ui_grid_fixed' : undef,
			      $opts->{'class'}),
	'style' => @style ? join(";", @style) : undef }));
}

=head2 ui_stack(&items, [&opts])

Returns HTML stacking the given fragments vertically with consistent
spacing. Options are C<gap> and C<class>.

=cut
sub ui_stack
{
return &theme_ui_stack(@_) if (defined(&theme_ui_stack));
my ($items, $opts) = @_;
$opts ||= {};
my @items = grep { defined($_) && $_ ne '' } @$items;
return "" if (!@items);
return &_ui_block('div', join("\n", @items), &_ui_attrs({
	'class' => &_ui_class('ui_stack', $opts->{'class'}),
	'style' => $opts->{'gap'} ? "--ui-gap:".$opts->{'gap'} : undef }));
}

=head2 ui_cluster(&items, [&opts])

Returns HTML for a horizontal row of the given fragments — typically
buttons or badges — which wraps on narrow screens. Options are :

=item align - Horizontal alignment : start (default), center, end or
between.

=item gap - Gap between items, as a CSS length.

=item class - Additional CSS classes.

=cut
sub ui_cluster
{
return &theme_ui_cluster(@_) if (defined(&theme_ui_cluster));
my ($items, $opts) = @_;
$opts ||= {};
my @items = grep { defined($_) && $_ ne '' } @$items;
return "" if (!@items);
my $align = $opts->{'align'} || '';
return &_ui_block('div', join("\n", @items), &_ui_attrs({
	'class' => &_ui_class('ui_cluster',
			      $align =~ /^(center|end|between)$/ ?
				"ui_cluster_$align" : undef,
			      $opts->{'class'}),
	'style' => $opts->{'gap'} ? "--ui-gap:".$opts->{'gap'} : undef }));
}

####################### card functions

# _ui_card_head(&opts)
# Builds the optional header section of a card from title, desc and
# actions options
sub _ui_card_head
{
my ($opts) = @_;
my $title = &_ui_text($opts, 'title');
my $desc = &_ui_text($opts, 'desc');
my $actions = &_ui_join($opts->{'actions'});
return "" if (!defined($title) && !defined($desc) && !$actions);
my $titles = "";
$titles .= &ui_tag('h2', $title, { 'class' => 'ui_card_title' })
	if (defined($title));
$titles .= &ui_tag('p', $desc, { 'class' => 'ui_card_desc' })
	if (defined($desc));
my $head = &_ui_block('div', $titles, { 'class' => 'ui_card_titles' });
$head .= &ui_tag('div', $actions, { 'class' => 'ui_card_actions' })
	if ($actions);
return &_ui_block('header', $head, { 'class' => 'ui_card_head' });
}

=head2 ui_card(&opts)

Returns HTML for a card — the primary container widget, drawn as a
surface with a border. Options are :

=item title - Card heading text.

=item desc - Short description under the heading.

=item actions - HTML (or array ref of fragments) shown at the top right
of the card, such as buttons, links or a badge.

=item body - HTML for the card content, which may include forms and
tables built with the existing ui functions.

=item footer - HTML shown in a separated footer area.

=item flush - Set to 1 to remove horizontal body padding, for full-bleed content
such as lists. Tables keep their own border and look better with the
padding.

=item state - Optional state name, which adds a colored accent border.

=item class - Additional CSS classes.

=item id - HTML id for the card element.

=cut
sub ui_card
{
return &theme_ui_card(@_) if (defined(&theme_ui_card));
my ($opts) = @_;
$opts ||= {};
my $rv = &ui_card_start($opts);
$rv .= defined($opts->{'body'}) ? $opts->{'body'} : "";
$rv .= &ui_card_end($opts->{'footer'});
return $rv;
}

=head2 ui_card_start(&opts)

Returns HTML for the start of a card, for callers that print content
progressively. Takes the same options as ui_card except body and
footer, and must be followed by ui_card_end.

=cut
sub ui_card_start
{
return &theme_ui_card_start(@_) if (defined(&theme_ui_card_start));
my ($opts) = @_;
$opts ||= {};
my $rv = &ui_tag_start('section', &_ui_attrs({
	'class' => &_ui_class('ui_card',
			      $opts->{'state'} ?
				"ui_card_".&_ui_state($opts->{'state'}) : undef,
			      $opts->{'class'}),
	'id' => $opts->{'id'} }))."\n";
$rv .= &_ui_card_head($opts);
$rv .= &ui_tag_start('div', {
	'class' => &_ui_class('ui_card_body',
			      $opts->{'flush'} ? 'ui_card_flush' : undef) })."\n";
return $rv;
}

=head2 ui_card_end([footer])

Returns HTML for the end of a card started by ui_card_start, with an
optional HTML footer area.

=cut
sub ui_card_end
{
return &theme_ui_card_end(@_) if (defined(&theme_ui_card_end));
my ($footer) = @_;
my $rv = &ui_tag_end('div');
$rv .= &ui_tag('footer', $footer, { 'class' => 'ui_card_foot' })
	if (defined($footer) && $footer ne '');
$rv .= &ui_tag_end('section');
return $rv;
}

####################### data display functions

=head2 ui_stat(&opts)

Returns HTML for a single statistic tile with a large value and a label.
Options are :

=item value - The number or short value to display prominently.

=item label - Label text under the value.

=item desc - Smaller muted description under the label.

=item state - Optional state name to color the value.

=item href - Optional URL, making the whole tile a link.

=item icon - Optional icon name shown before the value.

=cut
sub ui_stat
{
return &theme_ui_stat(@_) if (defined(&theme_ui_stat));
my ($opts) = @_;
$opts ||= {};
my $value = &_ui_text($opts, 'value');
$value = "0" if (!defined($value));
my $body = &ui_tag('span',
	($opts->{'icon'} ?
		&ui_svg_icon($opts->{'icon'}, { 'size' => 20 })." " : "").$value,
	{ 'class' => &_ui_class('ui_stat_value',
				$opts->{'state'} ?
				  "ui_fg_".&_ui_state($opts->{'state'}) : undef) });
my $label = &_ui_text($opts, 'label');
$body .= &ui_tag('span', $label, { 'class' => 'ui_stat_label' })
	if (defined($label));
my $desc = &_ui_text($opts, 'desc');
$body .= &ui_tag('span', $desc, { 'class' => 'ui_stat_desc' })
	if (defined($desc));
return &_ui_block($opts->{'href'} ? 'a' : 'div', $body, &_ui_attrs({
	'class' => 'ui_stat',
	'href' => $opts->{'href'} }));
}

=head2 ui_stats(&stats, [&opts])

Returns HTML for a responsive row of statistic tiles. Each element of the
stats array is a hash reference in ui_stat format. Options are C<class>
and C<min> for the minimum tile width.

=cut
sub ui_stats
{
return &theme_ui_stats(@_) if (defined(&theme_ui_stats));
my ($stats, $opts) = @_;
$opts ||= {};
return "" if (!$stats || !@$stats);
return &_ui_block('div', join("", map { &ui_stat($_) } @$stats),
	&_ui_attrs({
		'class' => &_ui_class('ui_stats', $opts->{'class'}),
		'style' => $opts->{'min'} ?
			"--ui-grid-min:".$opts->{'min'} : undef }));
}

=head2 ui_dl(&rows, [&opts])

Returns HTML for a description list of label and value pairs, for
displaying (rather than editing) information. Each row is either a two
or three element array reference of C<[ label, value-html, help-text ]>,
or a hash reference with keys :

=item label - Plain label text.

=item value - Plain value text, which will be escaped.

=item value_html - Pre-built HTML for the value, used instead of value.

=item help - Plain help text shown as a question-mark tooltip after the
label.

Options are :

=item cols - Set to 2 to flow rows into two columns on wide screens.

=item wide - CSS width for the label column, such as 40%.

=item class - Additional CSS classes.

=cut
sub ui_dl
{
return &theme_ui_dl(@_) if (defined(&theme_ui_dl));
my ($rows, $opts) = @_;
$opts ||= {};
return "" if (!$rows || !@$rows);
my $body = "";
foreach my $row (@$rows) {
	next if (!defined($row));
	my ($label, $value, $help);
	if (ref($row) eq 'HASH') {
		$label = &html_escape($row->{'label'});
		$value = defined($row->{'value_html'}) ? $row->{'value_html'}
			   : &html_escape($row->{'value'});
		$help = $row->{'help'};
		}
	else {
		$label = &html_escape($row->[0]);
		$value = defined($row->[1]) ? $row->[1] : "";
		$help = $row->[2];
		}
	$body .= &ui_tag('div',
		&ui_tag('dt', $label.($help ? " ".&ui_help($help) : "")).
		&ui_tag('dd', $value),
		{ 'class' => 'ui_dl_row' });
	}
return &_ui_block('dl', $body, &_ui_attrs({
	'class' => &_ui_class('ui_dl',
			      $opts->{'cols'} && $opts->{'cols'} > 1 ?
				'ui_dl_cols' : undef,
			      $opts->{'class'}),
	'style' => $opts->{'wide'} ? "--ui-dl-label:".$opts->{'wide'} : undef }));
}

=head2 ui_badge(text, [state], [&opts])

Returns HTML for a status badge, such as "Running" in green. The state
is one of success, warning, danger, info or neutral. Options are :

=item icon - Icon name to show before the text, replacing the state's
default icon. Set to an empty string for no icon at all.

=item dot - Set to 1 to show a plain colored dot instead of an icon.

=item title - Tooltip text for the badge.

=cut
sub ui_badge
{
return &theme_ui_badge(@_) if (defined(&theme_ui_badge));
my ($label, $state, $opts) = @_;
$opts ||= {};
$state = &_ui_state($state);
my $icon = "";
if ($opts->{'dot'}) {
	$icon = &ui_svg_icon('dot', { 'size' => 10 });
	}
elsif (defined($opts->{'icon'})) {
	$icon = $opts->{'icon'} eq '' ? "" :
		&ui_svg_icon($opts->{'icon'}, { 'size' => 13 });
	}
elsif ($ui_state_icons{$state}) {
	$icon = &ui_svg_icon($ui_state_icons{$state}, { 'size' => 13 });
	}
return &ui_tag('span', $icon.&ui_tag('span', &html_escape($label)),
	&_ui_attrs({ 'class' => "ui_badge ui_badge_$state",
		     'title' => $opts->{'title'} }));
}

=head2 ui_chip(text, [&opts])

Returns HTML for a small muted chip, such as a category or source label
next to a list entry.

=cut
sub ui_chip
{
return &theme_ui_chip(@_) if (defined(&theme_ui_chip));
my ($label, $opts) = @_;
$opts ||= {};
return &ui_tag('span', &html_escape($label),
	{ 'class' => &_ui_class('ui_chip', $opts->{'class'}) });
}

=head2 ui_list(&items, [&opts])

Returns HTML for a stacked list of entries with titles, descriptions and
trailing details. Each item is a hash reference with keys :

=item title - Entry title text (or title_html for pre-built HTML).

=item desc - Secondary description line (or desc_html).

=item href - Optional URL, making the title a link.

=item badge - Optional array ref of [ text, state ] shown after the
title, or badge_html for arbitrary HTML.

=item tags - Optional array ref of plain strings shown as small chips
after the description.

=item meta - Muted text aligned to the right, such as a time or count.

=item actions - HTML for buttons or links aligned to the right.

=item icon - Optional icon name shown before the title.

=item state - Optional state name, which colors the icon.

Options are :

=item flush - Set to 1 when the list fills a flush card body, extending
row separators to the card edges.

=item class - Additional CSS classes.

=cut
sub ui_list
{
return &theme_ui_list(@_) if (defined(&theme_ui_list));
my ($items, $opts) = @_;
$opts ||= {};
return "" if (!$items || !@$items);
my $body = "";
foreach my $item (@$items) {
	next if (!defined($item));

	# Title line, with optional link and badge
	my $title = &_ui_text($item, 'title');
	$title = &ui_tag('a', $title,
			 { 'class' => 'ui_list_link', 'href' => $item->{'href'} })
		if (defined($title) && $item->{'href'});
	my $badge = defined($item->{'badge_html'}) ? $item->{'badge_html'} :
		    $item->{'badge'} ? &ui_badge(@{$item->{'badge'}}) : "";
	my $main = &ui_tag('div',
		(defined($title) ? $title : "").($badge ? " ".$badge : ""),
		{ 'class' => 'ui_list_title' });

	# Description line with chips
	my $desc = &_ui_text($item, 'desc');
	my $tags = $item->{'tags'} && @{$item->{'tags'}} ?
		join(" ", map { &ui_chip($_) } @{$item->{'tags'}}) : "";
	$main .= &ui_tag('div',
		(defined($desc) ? $desc : "").($tags ? " ".$tags : ""),
		{ 'class' => 'ui_list_desc' }) if (defined($desc) || $tags);

	# Leading icon, and trailing meta text and actions
	my $row = "";
	$row .= &ui_tag('span', &ui_svg_icon($item->{'icon'}),
		{ 'class' => &_ui_class('ui_list_icon',
					$item->{'state'} ?
					  "ui_fg_".&_ui_state($item->{'state'}) :
					  undef) }) if ($item->{'icon'});
	$row .= &_ui_block('div', $main, { 'class' => 'ui_list_main' });
	my $meta = &_ui_text($item, 'meta');
	my $actions = &_ui_join($item->{'actions'});
	$row .= &ui_tag('div',
		(defined($meta) ?
			&ui_tag('span', $meta, { 'class' => 'ui_list_meta' }) : "").
		$actions,
		{ 'class' => 'ui_list_side' }) if (defined($meta) || $actions);
	$body .= &_ui_block('div', $row, { 'class' => 'ui_list_item' });
	}
return &_ui_block('div', $body, {
	'class' => &_ui_class('ui_list', $opts->{'flush'} ? 'ui_list_flush' : undef,
			      $opts->{'class'}) });
}

=head2 ui_feed(&events, [&opts])

Returns HTML for a simple activity feed of timestamped events in the
supplied order. Pass the newest event first for a reverse-chronological
feed. Each event is a hash reference with keys :

=item when - Time label, such as "5 minutes ago".

=item text - Event text (or text_html for pre-built HTML).

=item state - Optional state name, coloring the event marker.

Options are C<flush> and C<class>, as for ui_list.

=cut
sub ui_feed
{
return &theme_ui_feed(@_) if (defined(&theme_ui_feed));
my ($events, $opts) = @_;
$opts ||= {};
return "" if (!$events || !@$events);
my $body = "";
foreach my $e (@$events) {
	next if (!defined($e));
	my $state = $e->{'state'} ? &_ui_state($e->{'state'}) : undef;
	my $when = &_ui_text($e, 'when');
	my $etext = &_ui_text($e, 'text');
	my $item = "";
	$item .= &ui_tag('div', $when, { 'class' => 'ui_feed_when' })
		if (defined($when));
	$item .= &ui_tag('div', $etext, { 'class' => 'ui_feed_text' })
		if (defined($etext));
	$body .= &_ui_block('div', $item, {
		'class' => &_ui_class('ui_feed_item',
				      $state ? "ui_feed_$state" : undef) });
	}
return &_ui_block('div', $body, {
	'class' => &_ui_class('ui_feed', $opts->{'flush'} ? 'ui_feed_flush' : undef,
			      $opts->{'class'}) });
}

=head2 ui_empty_state(&opts)

Returns HTML for an empty-state message, used when a table or list has
nothing to show. Options are :

=item title - Main message text.

=item desc - Secondary explanation text.

=item icon - Icon name shown above the message.

=item actions - HTML for buttons or links offering a next step.

=cut
sub ui_empty_state
{
return &theme_ui_empty_state(@_) if (defined(&theme_ui_empty_state));
my ($opts) = @_;
$opts ||= {};
my $title = &_ui_text($opts, 'title');
$title = &html_escape($text{'ui_empty_state'} || 'Nothing to display')
	if (!defined($title));
my $desc = &_ui_text($opts, 'desc');
my $actions = &_ui_join($opts->{'actions'});
my $body = "";
$body .= &ui_tag('span', &ui_svg_icon($opts->{'icon'}, { 'size' => 22 }),
		 { 'class' => 'ui_empty_icon' }) if ($opts->{'icon'});
$body .= &ui_tag('div', $title, { 'class' => 'ui_empty_title' });
$body .= &ui_tag('div', $desc, { 'class' => 'ui_empty_desc' })
	if (defined($desc));
$body .= &ui_tag('div', $actions, { 'class' => 'ui_empty_actions' })
	if ($actions);
return &_ui_block('div', $body, { 'class' => 'ui_empty' });
}

=head2 ui_progress(value, [&opts])

Returns HTML for a progress bar showing the given value as a percentage
of 100, or of the max option. The result is clamped to the range 0 to
100. Options are :

=item label - Text shown above the bar, or before it in the inline
layout, or under the ring.

=item state - State name coloring the bar, defaulting to info.

=item thresholds - Colors the bar by its value instead : success below
the first threshold, warning from there, danger from the second. Set to
1 for the defaults of 70 and 90, or to an array ref of two percentages.

=item max - The value that counts as 100%, defaulting to 100. Use it to
pass raw numbers such as bytes.

=item value - Text shown with the bar instead of the percentage, such as
"3.4 GB of 10 GB".

=item small - Set to 1 for a bare bar with no text at all.

=item inline - Set to 1 to show label, bar and value on one line, as in
a table cell or a list row.

=item inside - Set to 1 to show the value as a small marker riding on the
end of the bar, instead of at the right of the label row.

=item segments - Array ref of hash refs with pct (or value, against max),
state and label, drawn as consecutive segments of one bar, with a legend
under it when segments have labels. The main value is then their sum.

=item indeterminate - Set to 1 for a task of unknown progress, drawn as
a moving bar. The value is ignored.

=item ring - Set to 1 for a circular gauge with the value in its center,
sized by the size option in pixels, defaulting to 56.

=cut
sub ui_progress
{
return &theme_ui_progress(@_) if (defined(&theme_ui_progress));
my ($value, $opts) = @_;
$opts ||= {};
my $max = $opts->{'max'};
my $label = &_ui_text($opts, 'label');

# Segments each get a percentage, and together make up the total
my @segments;
if ($opts->{'segments'} && ref($opts->{'segments'}) eq 'ARRAY') {
	foreach my $s (@{$opts->{'segments'}}) {
		next if (ref($s) ne 'HASH');
		push(@segments, {
			'pct' => defined($s->{'pct'}) ?
				&_ui_progress_pct($s->{'pct'}) :
				&_ui_progress_pct($s->{'value'}, $max),
			'state' => &_ui_state($s->{'state'} || 'info'),
			'label' => &_ui_text($s, 'label') });
		}
	}
my $pct = 0;
if (@segments) {
	$pct += $_->{'pct'} foreach (@segments);
	$pct = 100 if ($pct > 100);
	}
else {
	$pct = &_ui_progress_pct($value, $max);
	}

# The color comes from the state, or from the thresholds the value crosses
my $state;
if ($opts->{'state'}) {
	$state = &_ui_state($opts->{'state'});
	}
elsif ($opts->{'thresholds'}) {
	my ($warn, $danger) = ref($opts->{'thresholds'}) eq 'ARRAY' ?
		@{$opts->{'thresholds'}} : (70, 90);
	$state = $pct >= $danger ? 'danger' :
		 $pct >= $warn ? 'warning' : 'success';
	}
else {
	$state = 'info';
	}
my $vtext = defined($opts->{'value'}) ? &html_escape($opts->{'value'})
				      : $pct."%";
my $indet = $opts->{'indeterminate'} ? 1 : 0;
my %aria = ( 'role' => 'progressbar',
	     'aria-valuemin' => 0,
	     'aria-valuemax' => 100 );
if ($indet) {
	$aria{'aria-busy'} = 'true';
	}
else {
	$aria{'aria-valuenow'} = $pct;
	}

# A ring is an SVG circle whose dash length is the percentage, drawn on a
# circle with a circumference of 100 units
if ($opts->{'ring'}) {
	my $size = int($opts->{'size'} || 56);
	# Invalid or subpixel sizes cannot be used to scale the stroke
	$size = 56 if ($size < 1);
	# The circle is 36 units across, so a stroke of 3 pixels is 3*36/size
	# units whatever the size
	my $stroke = sprintf("%.2f", 108 / $size);
	my $svg = &ui_tag_start('svg', {
			'class' => 'ui_progress_ring_svg',
			'width' => $size, 'height' => $size,
			'viewBox' => '0 0 36 36', 'aria-hidden' => 'true' }).
		  &ui_tag('circle', undef, {
			'class' => 'ui_progress_ring_track',
			'cx' => 18, 'cy' => 18, 'r' => 15.9155,
			'stroke-width' => $stroke }).
		  &ui_tag('circle', undef, {
			'class' => "ui_progress_ring_bar ui_fg_$state",
			'cx' => 18, 'cy' => 18, 'r' => 15.9155,
			'stroke-width' => $stroke,
			'stroke-dasharray' => ($indet ? 25 : $pct)." 100" }).
		  &ui_tag_end('svg');
	my $body = &ui_tag('span',
		$svg.&ui_tag('span', $indet ? "" : $vtext,
			     { 'class' => 'ui_progress_value' }),
		{ 'class' => 'ui_progress_ring_box' });
	$body .= &ui_tag('span', $label, { 'class' => 'ui_progress_label' })
		if (defined($label));
	return &_ui_block('div', $body, {
		'class' => &_ui_class('ui_progress', 'ui_progress_ring',
				      $indet ? 'ui_progress_indeterminate' :
					       undef),
		%aria });
	}

# The bar itself, or the bars of a segmented one
my $bars = "";
if ($indet) {
	$bars = &ui_tag('div', undef,
			{ 'class' => "ui_progress_bar ui_bg_$state" });
	}
elsif (@segments) {
	foreach my $s (@segments) {
		$bars .= &ui_tag('div', undef, {
			'class' => "ui_progress_bar ui_bg_$s->{'state'}",
			'style' => "width:$s->{'pct'}%" });
		}
	}
else {
	$bars = &ui_tag('div',
		$opts->{'inside'} ?
			&ui_tag('span', $vtext,
				{ 'class' => 'ui_progress_inside_value' }) : undef,
		{ 'class' => "ui_progress_bar ui_bg_$state",
		  'style' => "width:$pct%" });
	}
my $track = &ui_tag('div', $bars, { 'class' => 'ui_progress_track' });

# Legend for labelled segments
my $legend = "";
if (grep { defined($_->{'label'}) } @segments) {
	my $keys = "";
	foreach my $s (@segments) {
		$keys .= &ui_tag('span',
			&ui_tag('span', undef,
				{ 'class' => "ui_progress_dot ui_bg_$s->{'state'}" }).
			(defined($s->{'label'}) ? $s->{'label'} : "")." ".
			&ui_tag('span', $s->{'pct'}."%",
				{ 'class' => 'ui_progress_value' }),
			{ 'class' => 'ui_progress_key' });
		}
	$legend = &ui_tag('div', $keys, { 'class' => 'ui_progress_legend' });
	}

# Put the text around the track according to the layout
my $body;
if ($opts->{'small'}) {
	$body = $track;
	}
elsif ($opts->{'inline'}) {
	$body = (defined($label) ?
		 &ui_tag('span', $label, { 'class' => 'ui_progress_label' }) :
		 "").
		$track.
		($indet ? "" :
		 &ui_tag('span', $vtext, { 'class' => 'ui_progress_value' }));
	}
else {
	my $head = &ui_tag('span', defined($label) ? $label : "");
	$head .= &ui_tag('span', $vtext, { 'class' => 'ui_progress_value' })
		if (!$opts->{'inside'} && !$indet);
	$body = &ui_tag('div', $head, { 'class' => 'ui_progress_head' }).
		$track.$legend;
	}
return &_ui_block('div', $body, {
	'class' => &_ui_class('ui_progress',
		$opts->{'small'} ? 'ui_progress_sm' : undef,
		$opts->{'inline'} ? 'ui_progress_inline' : undef,
		$opts->{'inside'} ? 'ui_progress_inside' : undef,
		# Keep the marker within the track at either end
		$opts->{'inside'} && $pct < 8 ? 'ui_progress_inside_start' :
		$opts->{'inside'} && $pct > 92 ? 'ui_progress_inside_end' : undef,
		@segments ? 'ui_progress_segmented' : undef,
		$indet ? 'ui_progress_indeterminate' : undef),
	%aria });
}

# _ui_progress_pct(value, [max])
# Converts a value into a whole percentage of max (100 by default),
# clamped to 0..100, treating anything that is not a number as 0
sub _ui_progress_pct
{
my ($value, $max) = @_;
$value = 0 if (!defined($value) ||
	      $value !~ /\A-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)\z/);
$max = 100 if (!defined($max) ||
	       $max !~ /\A(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)\z/ || $max <= 0);
my $pct = $value * 100 / $max;
$pct = 0 if ($pct < 0);
$pct = 100 if ($pct > 100);
return int($pct + 0.5);
}

####################### new form controls

=head2 ui_toggle(&opts)

Returns HTML for an on/off switch, submitted like a checkbox. Options
are :

=item name - Name for this input.

=item value - Value submitted when on, defaulting to 1.

=item label - Text shown next to the switch.

=item checked - Set to 1 if on by default.

=item disabled - Set to 1 to disable the switch.

=item attrs - Hash reference of additional attributes for the input, such
as a data-ui-confirm message.

=item class, id, form - As for other widgets.

=cut
sub ui_toggle
{
return &theme_ui_toggle(@_) if (defined(&theme_ui_toggle));
my ($opts) = @_;
$opts ||= {};
my $value = defined($opts->{'value'}) ? $opts->{'value'} : 1;
my $attrs = &_ui_attrs({
	%{ $opts->{'attrs'} || {} },
	'type' => 'checkbox',
	'name' => $opts->{'name'},
	'value' => $value,
	'id' => defined($opts->{'id'}) ? $opts->{'id'} :
		defined($opts->{'name'}) ? $opts->{'name'}."_".$value : undef,
	'form' => $opts->{'form'} });
# An explicit empty value must be submitted as empty, not the browser's
# default checkbox value of "on"
$attrs->{'value'} = $value;
$attrs->{'checked'} = undef if ($opts->{'checked'});
$attrs->{'disabled'} = undef if ($opts->{'disabled'});
my $body = &ui_tag('input', undef, $attrs);
$body .= &ui_tag('span', &ui_tag('span', undef, { 'class' => 'ui_toggle_thumb' }),
		 { 'class' => 'ui_toggle_track', 'aria-hidden' => 'true' });
my $label = &_ui_text($opts, 'label');
$body .= &ui_tag('span', $label, { 'class' => 'ui_toggle_label' })
	if (defined($label));
return &ui_tag('label', $body,
	{ 'class' => &_ui_class('ui_toggle', $opts->{'class'}) });
}

=head2 ui_search(&opts)

Returns HTML for a search input with a magnifying-glass icon. Options
are :

=item name - Name for this input.

=item value - Initial contents.

=item placeholder - Hint text, defaulting to "Search".

=item filter - CSS selector of a container whose table rows or list
entries are filtered client-side as the user types, with no server
round-trip.

=item width - CSS width for the input.

=item size - Approximate width in characters, when width is not set.

=item attrs - Hash reference of additional attributes for the input.

=item disabled, class, id, form - As for other widgets.

=cut
sub ui_search
{
return &theme_ui_search(@_) if (defined(&theme_ui_search));
my ($opts) = @_;
$opts ||= {};
my $attrs = &_ui_attrs({
	%{ $opts->{'attrs'} || {} },
	'type' => 'search',
	'name' => $opts->{'name'},
	'id' => defined($opts->{'id'}) ? $opts->{'id'} : $opts->{'name'},
	'class' => &_ui_class('ui_input', 'ui_search_input', $opts->{'class'}),
	'value' => $opts->{'value'},
	'placeholder' => defined($opts->{'placeholder'}) ?
		$opts->{'placeholder'} : $text{'ui_search'} || 'Search',
	'size' => $opts->{'size'} ? int($opts->{'size'}) : undef,
	'form' => $opts->{'form'},
	'data-ui-filter' => $opts->{'filter'} });
$attrs->{'disabled'} = undef if ($opts->{'disabled'});
return &ui_tag('span',
	&ui_svg_icon('search', { 'size' => 14, 'class' => 'ui_search_icon' }).
	&ui_tag('input', undef, $attrs),
	&_ui_attrs({ 'class' => 'ui_search',
		     'style' => $opts->{'width'} ?
				"width:".$opts->{'width'} : undef }));
}

####################### choice lists

=head2 ui_choice(name, value, &options, [&opts])

Returns HTML for a boxed list of options with a radio button each, where
an option can carry its own inputs next to its label and further fields
under it. It replaces the hand-built tables of radios and inputs of pages
like the backup destination selector : every option is a row that wraps
on narrow screens instead of a nested table, and all inputs stay visible,
so nothing moves when the choice changes; focusing an input selects its
option (done by ui-lib.js). For a plain list of radios with at most one
input each, use ui_radio_list; when the options are many or their fields
long, ui_select_switch shows only the fields of the chosen option. Each
option is a hash reference with keys :

=item value - Value submitted when this option is selected.

=item label - Option text (or label_html for pre-built HTML).

=item desc - Optional muted explanation under the label.

=item content - HTML for inputs shown right after the label, such as the
textbox or select the option needs.

=item fields - Array ref of further inputs shown under the option, each
as C<[ label, html ]> or a hash with label (or label_html) and html, laid
out in as many columns as fit.

=item disabled - Set to 1 to disable this option.

Options are :

=item class - Additional CSS classes.

=item id - HTML id for the list element.

The buttons themselves come from ui_oneradio, so a theme styles them as
it styles every other radio button; for that reason a label is plain
text, and anything else goes in content. A ui_radio_table row
C<[ value, label, html ]> becomes
C<{ 'value' => value, 'label' => label, 'content' => html }>.

=cut
sub ui_choice
{
return &theme_ui_choice(@_) if (defined(&theme_ui_choice));
my ($name, $value, $options, $opts) = @_;
$opts ||= {};
return "" if (!$options || !@$options);
my $body = "";
foreach my $o (@$options) {
	next if (ref($o) ne 'HASH');
	my $oval = defined($o->{'value'}) ? $o->{'value'} : '';

	# The button with its label, then the inline inputs, on the first line
	my $label = &_ui_text($o, 'label');
	my $head = &ui_oneradio($name, $oval,
				defined($label) ? $label : &html_escape($oval),
				defined($value) && $value eq $oval ? 1 : 0,
				undef, $o->{'disabled'} ? 1 : 0);
	my $content = &_ui_join($o->{'content'});
	$head .= &ui_tag('span', $content, { 'class' => 'ui_choice_content' })
		if ($content);
	my $item = &ui_tag('div', $head, { 'class' => 'ui_choice_head' });

	# Description and further fields under it
	my $desc = &_ui_text($o, 'desc');
	$item .= &ui_tag('div', $desc, { 'class' => 'ui_choice_desc' })
		if (defined($desc));
	$item .= &_ui_fields($o->{'fields'}, 'ui_choice');
	$body .= &_ui_block('div', $item, {
		'class' => &_ui_class('ui_choice_item',
			$o->{'disabled'} ? 'ui_choice_disabled' : undef) });
	}
return &_ui_block('div', $body, &_ui_attrs({
	'class' => &_ui_class('ui_choice', $opts->{'class'}),
	'role' => 'radiogroup',
	'id' => $opts->{'id'} }));
}

# _ui_fields(&fields, class-prefix)
# Returns the grid of labelled inputs under an option of ui_choice or
# ui_select_switch, or an empty string when there are none. Each field is
# [ label, html ] or a hash with label (or label_html) and html.
sub _ui_fields
{
my ($fields, $prefix) = @_;
return "" if (ref($fields) ne 'ARRAY' || !@$fields);
my $rv = "";
foreach my $f (@$fields) {
	my ($flabel, $fhtml);
	if (ref($f) eq 'HASH') {
		$flabel = &_ui_text($f, 'label');
		$fhtml = $f->{'html'};
		}
	elsif (ref($f) eq 'ARRAY') {
		$flabel = defined($f->[0]) ? &html_escape($f->[0]) : undef;
		$fhtml = $f->[1];
		}
	else {
		next;
		}
	$rv .= &ui_tag('div',
		(defined($flabel) ?
		 &ui_tag('span', $flabel,
			 { 'class' => $prefix.'_field_label' }) : "").
		&ui_tag('span', defined($fhtml) ? $fhtml : "",
			{ 'class' => $prefix.'_field_input' }),
		{ 'class' => $prefix.'_field' });
	}
return &_ui_block('div', $rv, { 'class' => $prefix.'_fields' });
}

=head2 ui_radio_list(name, value, &options, [&opts])

Returns HTML for a compact boxed list of radio buttons, one per line, each
with an optional input right after its label : the direct replacement of
ui_radio_table. The buttons sit at the left edge of the box, close to one
another. For options that need several fields or an explanation, use
ui_choice. Each option is a hash reference with keys value, label (plain
text), content (HTML shown after the label) and disabled, as for
ui_choice; the buttons come from ui_oneradio so that the theme styles
them. Options are class and id.

=cut
sub ui_radio_list
{
return &theme_ui_radio_list(@_) if (defined(&theme_ui_radio_list));
my ($name, $value, $options, $opts) = @_;
$opts ||= {};
return "" if (!$options || !@$options);
my $body = "";
foreach my $o (@$options) {
	next if (ref($o) ne 'HASH');
	my $oval = defined($o->{'value'}) ? $o->{'value'} : '';
	my $label = &_ui_text($o, 'label');
	my $item = &ui_oneradio($name, $oval,
				defined($label) ? $label : &html_escape($oval),
				defined($value) && $value eq $oval ? 1 : 0,
				undef, $o->{'disabled'} ? 1 : 0);
	my $content = &_ui_join($o->{'content'});
	$item .= &ui_tag('span', $content, { 'class' => 'ui_radio_list_content' })
		if ($content);
	$body .= &ui_tag('div', $item, {
		'class' => &_ui_class('ui_radio_list_item',
			$o->{'disabled'} ? 'ui_radio_list_disabled' : undef) });
	}
return &_ui_block('div', $body, &_ui_attrs({
	'class' => &_ui_class('ui_radio_list', $opts->{'class'}),
	'role' => 'radiogroup',
	'id' => $opts->{'id'} }));
}

=head2 ui_select_switch(name, value, &options, [&opts])

Returns HTML for a select whose choice decides which block of inputs is
shown under it : the alternative to ui_choice when the options are many
or their fields long, since only the block of the current choice takes
any space. Each option is a hash reference with keys value, label (the
select entry), desc, content and fields as for ui_choice, the last three
making up the option's block. The blocks of the other options are hidden,
and ui-lib.js switches them when the select changes; the inputs of hidden
blocks are still submitted with the form. Options are class and id for
the wrapper.

=cut
sub ui_select_switch
{
return &theme_ui_select_switch(@_) if (defined(&theme_ui_select_switch));
my ($name, $value, $options, $opts) = @_;
$opts ||= {};
my @options = grep { ref($_) eq 'HASH' } @{$options || []};
return "" if (!@options);
# A select defaults to its first option when the saved value is absent.
# Use that same value for the panels so the visible fields always agree.
if (!defined($value) ||
    !(grep { (defined($_->{'value'}) ? $_->{'value'} : '') eq $value }
	   @options)) {
	$value = defined($options[0]->{'value'}) ? $options[0]->{'value'} : '';
	}
my @sel;
my $panels = "";
foreach my $o (@options) {
	my $oval = defined($o->{'value'}) ? $o->{'value'} : '';
	push(@sel, [ $oval,
		     defined($o->{'label_html'}) ? $o->{'label_html'} :
		     defined($o->{'label'}) ? &html_escape($o->{'label'}) :
		     &html_escape($oval) ]);

	# The block for this option, hidden unless it is the current one. Its
	# inline content is shown as a first field labelled with the option
	# name, since the button that would have named it is not there
	my $panel = "";
	my $desc = &_ui_text($o, 'desc');
	$panel .= &ui_tag('div', $desc, { 'class' => 'ui_select_switch_desc' })
		if (defined($desc));
	my $content = &_ui_join($o->{'content'});
	$panel .= &ui_tag('div',
		&ui_tag('span', $sel[-1]->[1],
			{ 'class' => 'ui_select_switch_field_label' }).
		&ui_tag('span', $content,
			{ 'class' => 'ui_select_switch_field_input' }),
		{ 'class' => 'ui_select_switch_field ui_select_switch_content' })
		if ($content);
	$panel .= &_ui_fields($o->{'fields'}, 'ui_select_switch');
	next if ($panel eq '');
	my $attrs = { 'class' => 'ui_select_switch_panel',
		      'data-ui-switch-value' => $oval };
	$attrs->{'hidden'} = undef if ($oval ne $value);
	$panels .= &_ui_block('div', $panel, $attrs);
	}
my $select = &ui_select($name, $value, \@sel, undef, undef, undef, 0,
			"data-ui-switch='1'");
return &_ui_block('div', $select.$panels, &_ui_attrs({
	'class' => &_ui_class('ui_select_switch', $opts->{'class'}),
	'id' => $opts->{'id'} }));
}

1;
