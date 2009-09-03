use vars qw($theme_no_table $ui_radio_selector_donejs $module_name 
	    $ui_multi_select_donejs);

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
	$rv .= "<tr $tb class='ui_table_head'>";
	if (defined($heading)) {
		$rv .= "<td><b>$heading</b></td>"
		}
	if (defined($rightheading)) {
		$rv .= "<td align=right>$rightheading</td>";
		$colspan++;
		}
	$rv .= "</tr>\n";
	}
$rv .= "<tr $cb class='ui_table_body'> <td colspan=$colspan>".
       "<table width=100%>\n";
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

=head2 ui_table_row(label, value, [cols], [&td-tags])

Returns HTML for a row in a table started by ui_table_start, with a 1-column
label and 1+ column value. The parameters are :

=item label - Label for the input field. If this is undef, no label is displayed.

=item value - HTML for the input part of the row.

=item cols - Number of columns the value should take up, defaulting to 1.

=item td-tags - Array reference of HTML attributes for the <td> tags in this row.

=cut
sub ui_table_row
{
return &theme_ui_table_row(@_) if (defined(&theme_ui_table_row));
my ($label, $value, $cols, $tds) = @_;
$cols ||= 1;
$tds ||= $main::ui_table_default_tds;
my $rv;
if ($main::ui_table_pos+$cols+1 > $main::ui_table_cols &&
    $main::ui_table_pos != 0) {
	# If the requested number of cols won't fit in the number
	# remaining, start a new row
	$rv .= "</tr>\n";
	$main::ui_table_pos = 0;
	}
$rv .= "<tr class='ui_table_row'>\n"
	if ($main::ui_table_pos%$main::ui_table_cols == 0);
$rv .= "<td valign=top $tds->[0] class='ui_label'><b>$label</b></td>\n"
	if (defined($label));
$rv .= "<td valign=top colspan=$cols $tds->[1] class='ui_value'>$value</td>\n";
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
       "<td colspan=$main::ui_table_cols><hr></td> </tr>\n";
return $rv;
}

=head2 ui_table_span(text)

Outputs a table row that spans the whole table, and contains the given text.

=cut
sub ui_table_span
{
my ($text) = @_;
return &theme_ui_table_hr(@_) if (defined(&theme_ui_table_hr));
my $rv;
if ($ui_table_pos) {
	$rv .= "</tr>\n";
	$ui_table_pos = 0;
	}
$rv .= "<tr class='ui_table_span'> ".
       "<td colspan=$main::ui_table_cols>$text</td> </tr>\n";
return $rv;
}

=head2 ui_columns_start(&headings, [width-percent], [noborder], [&tdtags], [heading])

Returns HTML for the start of a multi-column table, with the given headings.
The parameters are :

=item headings - An array reference of headers for the table's columns.

=item width-percent - Desired width as a percentage, or undef to let the browser decide.

=item noborder - Set to 1 if the table should not have a border.

=item tdtags - An optional reference to an array of HTML attributes for the table's <td> tags.

=item heading - An optional heading to put above the table.

=cut
sub ui_columns_start
{
return &theme_ui_columns_start(@_) if (defined(&theme_ui_columns_start));
my ($heads, $width, $noborder, $tdtags, $title) = @_;
my $rv;
$rv .= "<table".($noborder ? "" : " border").
		(defined($width) ? " width=$width%" : "")." class='ui_columns'>\n";
if ($title) {
	$rv .= "<tr $tb class='ui_columns_heading'>".
	       "<td colspan=".scalar(@$heads)."><b>$title</b></td></tr>\n";
	}
$rv .= "<tr $tb class='ui_columns_heads'>\n";
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
$rv .= "<tr $cb class='ui_columns_row'>\n";
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
$rv .= "<tr $tb class='ui_columns_header'>\n";
my $i;
for($i=0; $i<@$cols; $i++) {
	$rv .= "<td ".$tdtags->[$i]."><b>".
	       ($cols->[$i] eq "" ? "<br>" : $cols->[$i])."</b></td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

=head2 ui_checked_columns_row(&columns, &tdtags, checkname, checkvalue, [checked?], [disabled])

Returns HTML for a row in a multi-column table, in which the first column 
contains a checkbox. The parameters are :

=item columns - Reference to an array containing the HTML to show in the columns for this row.

=item tdtags - An optional array reference containing HTML attributes for the row's <td> tags.

=item checkname - Name for the checkbox input. Should be the same for all rows.

=item checkvalue - Value for this checkbox input.

=item checked - Set to 1 if it should be checked by default.

=item disabled - Set to 1 if the checkbox should be disabled and thus un-clickable.

=cut
sub ui_checked_columns_row
{
return &theme_ui_checked_columns_row(@_) if (defined(&theme_ui_checked_columns_row));
my ($cols, $tdtags, $checkname, $checkvalue, $checked, $disabled) = @_;
my $rv;
$rv .= "<tr $cb class='ui_checked_columns'>\n";
$rv .= "<td class='ui_checked_checkbox' ".$tdtags->[0].">".
       &ui_checkbox($checkname, $checkvalue, undef, $checked, undef, $disabled).
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

=head2 ui_radio_columns_row(&columns, &tdtags, checkname, checkvalue, [checked], [disabled])

Returns HTML for a row in a multi-column table, in which the first
column is a radio button. The parameters are :

=item columns - Reference to an array containing the HTML to show in the columns for this row.

=item tdtags - An optional array reference containing HTML attributes for the row's <td> tags.

=item checkname - Name for the radio button input. Should be the same for all rows.

=item checkvalue - Value for this radio button option.

=item checked - Set to 1 if it should be checked by default.

=item disabled - Set to 1 if the radio button should be disabled and thus un-clickable.

=cut
sub ui_radio_columns_row
{
return &theme_ui_radio_columns_row(@_) if (defined(&theme_ui_radio_columns_row));
my ($cols, $tdtags, $checkname, $checkvalue, $checked, $dis) = @_;
my $rv;
$rv .= "<tr $cb class='ui_radio_columns'>\n";
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

=head2 ui_columns_table(&headings, width-percent, &data, &types, no-sort, title, empty-msg)

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

=cut
sub ui_columns_table
{
return &theme_ui_columns_table(@_) if (defined(&theme_ui_columns_table));
my ($heads, $width, $data, $types, $nosort, $title, $emptymsg) = @_;
my $rv;

# Just show empty message if no data
if ($emptymsg && !@$data) {
	$rv .= &ui_subheading($title) if ($title);
	$rv .= "<span class='ui_emptymsg'><b>$emptymsg</b></span><p>\n";
	return $rv;
	}

# Are there any checkboxes in each column? If so, make those columns narrow
my @tds = map { "valign=top" } @$heads;
my $maxwidth = 0;
foreach my $r (@$data) {
	my $cc = 0;
	foreach my $c (@$r) {
		if (ref($c) &&
		    ($c->{'type'} eq 'checkbox' || $c->{'type'} eq 'radio')) {
			$tds[$cc] .= " width=5" if ($tds[$cc] !~ /width=/);
			}
		$cc++;
		}
	$maxwidth = $cc if ($cc > $maxwidth);
	}
$rv .= &ui_columns_start($heads, $width, 0, \@tds, $title);

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
						 undef, $c->{'disabled'}));
			}
		elsif ($c->{'type'} eq 'radio') {
			# Radio button in non-first column
			push(@cols, &ui_oneradio($c->{'name'}, $c->{'value'},
					         $c->{'label'}, $c->{'checked'},
						 undef, $c->{'disabled'}));
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
					       $c0->{'disabled'});
		}
	elsif ($c0->{'type'} eq 'radio') {
		$rv .= &ui_radio_columns_row(\@cols, \@rtds, $c0->{'name'},
					     $c0->{'value'}, $c0->{'checked'},
					     $c0->{'disabled'});
		}
	}

$rv .= &ui_columns_end();
return $rv;
}

=head2 ui_form_columns_table(cgi, &buttons, select-all, &otherlinks, &hiddens, &headings, width-percent, &data, &types, no-sort, title, empty-msg)

Similar to ui_columns_table, but wrapped in a form. Parameters are :

=item cgi - URL to submit the form to.

=item buttons - An array ref of buttons at the end of the form, similar to that taken by ui_form_end.

=item select-all - If set to 1, include select all / invert links.

=item otherslinks - An array ref of other links to put at the top of the table, each of which is a 3-element hash ref of url, text and alignment (left or right).

=item hiddens - An array ref of hidden fields, each of which is a 2-element array ref containing the name and value.

All other parameters are the same as ui_columns_table.

=cut
sub ui_form_columns_table
{
return &theme_ui_form_columns_table(@_)
	if (defined(&theme_ui_form_columns_table));
my ($cgi, $buttons, $selectall, $others, $hiddens,
       $heads, $width, $data, $types, $nosort, $title, $emptymsg) = @_;
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
			unshift(@leftlinks, &select_all_link($cbname),
					    &select_invert_link($cbname));
			}
		}
	}

# Turn to HTML
if (@rightlinks) {
	$links = &ui_grid_table([ &ui_links_row(\@leftlinks),
				  &ui_links_row(\@rightlinks) ], 2, 100,
			        [ undef, "align=right" ]);
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
			 $emptymsg);

# Add form end
$rv .= $links;
if (@$data) {
	$rv .= &ui_form_end($buttons);
	}

return $rv;
}

####################### form generation functions

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
return &theme_ui_form_start(@_) if (defined(&theme_ui_form_start));
my ($script, $method, $target, $tags) = @_;
my $rv;
$rv .= "<form class='ui_form' action='".&html_escape($script)."' ".
	($method eq "post" ? "method=post" :
	 $method eq "form-data" ?
		"method=post enctype=multipart/form-data" :
		"method=get").
	($target ? " target=$target" : "").
        " ".$tags.
       ">\n";
return $rv;
}

=head2 ui_form_end([&buttons], [width])

Returns HTML for the end of a form, optionally with a row of submit buttons.
These are specified by the buttons parameter, which is an array reference
of array refs, with the following elements :

=item HTML value for the submit input for the button, or undef for none.

=item Text to appear on the button.

=item HTML or other inputs to appear after the button.

=item Set to 1 if the button should be disabled.

=item Additional HTML attributes to appear inside the button's input tag.

=cut
sub ui_form_end
{
return &theme_ui_form_end(@_) if (defined(&theme_ui_form_end));
my ($buttons, $width) = @_;
my $rv;
if ($buttons && @$buttons) {
	$rv .= "<table class='ui_form_end_buttons' ".($width ? " width=$width" : "")."><tr>\n";
	my $b;
	foreach $b (@$buttons) {
		if (ref($b)) {
			$rv .= "<td".(!$width ? "" :
				      $b eq $buttons->[0] ? " align=left" :
				      $b eq $buttons->[@$buttons-1] ?
					" align=right" : " align=center").">".
			       &ui_submit($b->[1], $b->[0], $b->[3], $b->[4]).
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
	}
$rv .= "</form>\n";
return $rv;
}

=head2 ui_textbox(name, value, size, [disabled?], [maxlength], [tags])

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
my ($name, $value, $size, $dis, $max, $tags) = @_;
$size = &ui_max_text_width($size);
return "<input class='ui_textbox' name=\"".&quote_escape($name)."\" ".
       "value=\"".&quote_escape($value)."\" ".
       "size=$size ".($dis ? "disabled=true" : "").
       ($max ? " maxlength=$max" : "").
       " ".$tags.
       ">";
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

=cut
sub ui_bytesbox
{
my ($name, $bytes, $size, $dis) = @_;
my $units = 1;
if ($bytes >= 10*1024*1024*1024*1024) {
	$units = 1024*1024*1024*1024;
	}
elsif ($bytes >= 10*1024*1024*1024) {
	$units = 1024*1024*1024;
	}
elsif ($bytes >= 10*1024*1024) {
	$units = 1024*1024;
	}
elsif ($bytes >= 10*1024) {
	$units = 1024;
	}
else {
	$units = 1;
	}
if ($bytes ne "") {
	$bytes = sprintf("%.2f", ($bytes*1.0)/$units);
	$bytes =~ s/\.00$//;
	}
$size = &ui_max_text_width($size || 8);
return &ui_textbox($name, $bytes, $size, $dis)." ".
       &ui_select($name."_units", $units,
		 [ [ 1, "bytes" ],
		   [ 1024, "kB" ],
		   [ 1024*1024, "MB" ],
		   [ 1024*1024*1024, "GB" ],
		   [ 1024*1024*1024*1024, "TB" ] ], undef, undef, undef, $dis);
}

=head2 ui_upload(name, size, [disabled?], [tags])

Returns HTML for a file upload input, for use in a form with the form-data
method. The parameters are :

=item name - Name for this input.

=item size - Desired width in characters.

=item disabled - Set to 1 if this text box should be disabled by default.

=item tags - Additional HTML attributes for the <input> tag.

=cut
sub ui_upload
{
return &theme_ui_upload(@_) if (defined(&theme_ui_upload));
my ($name, $size, $dis, $tags) = @_;
$size = &ui_max_text_width($size);
return "<input class='ui_upload' type=file name=\"".&quote_escape($name)."\" ".
       "size=$size ".
       ($dis ? "disabled=true" : "").
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
return "<input class='ui_password' ".
       "type=password name=\"".&quote_escape($name)."\" ".
       "value=\"".&quote_escape($value)."\" ".
       "size=$size ".($dis ? "disabled=true" : "").
       ($max ? " maxlength=$max" : "").
       " ".$tags.
       ">";
}

=head2 ui_hidden(name, value)

Returns HTML for a hidden field with the given name and value.

=cut
sub ui_hidden
{
return &theme_ui_hidden(@_) if (defined(&theme_ui_hidden));
my ($name, $value) = @_;
return "<input class='ui_hidden' type=hidden ".
       "name=\"".&quote_escape($name)."\" ".
       "value=\"".&quote_escape($value)."\">\n";
}

=head2 ui_select(name, value|&values, &options, [size], [multiple], [add-if-missing], [disabled?], [javascript])

Returns HTML for a drop-down menu or multiple selection list. The parameters
are :

=item name - Name for this input.

=item value - Either a single initial value, or an array reference of values if this is a multi-select list.

=item options - An array reference of possible options. Each element can either be a scalar, or a two-element array ref containing a submitted value and displayed text.

=item size - Desired vertical size in rows, which defaults to 1. For multi-select lists, this must be set to something larger.

=item multiple - Set to 1 for a multi-select list, 0 for single.

=item add-if-missing - If set to 1, any value that is not in the list of options will be automatically added (and selected).

=item disabled - Set to 1 to disable this input.

=item javascript - Additional HTML attributes for the <select> input.

=cut
sub ui_select
{
return &theme_ui_select(@_) if (defined(&theme_ui_select));
my ($name, $value, $opts, $size, $multiple, $missing, $dis, $js) = @_;
my $rv;
$rv .= "<select class='ui_select' name=\"".&quote_escape($name)."\"".
       ($size ? " size=$size" : "").
       ($multiple ? " multiple" : "").
       ($dis ? " disabled=true" : "")." ".$js.">\n";
my ($o, %opt, $s);
my %sel = ref($value) ? ( map { $_, 1 } @$value ) : ( $value, 1 );
foreach $o (@$opts) {
	$o = [ $o ] if (!ref($o));
	$rv .= "<option value=\"".&quote_escape($o->[0])."\"".
	       ($sel{$o->[0]} ? " selected" : "")." ".$o->[2].">".
	       ($o->[1] || $o->[0])."\n";
	$opt{$o->[0]}++;
	}
foreach $s (keys %sel) {
	if (!$opt{$s} && $missing) {
		$rv .= "<option value=\"".&quote_escape($s)."\"".
		       "selected>".($s eq "" ? "&nbsp;" : $s)."\n";
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
my $wstyle = $width ? "style='width:$width'" : "";

if (!$main::ui_multi_select_donejs++) {
	$rv .= &ui_multi_select_javascript();
	}
$rv .= "<table cellpadding=0 cellspacing=0 class='ui_multi_select'>";
if (defined($opts_title)) {
	$rv .= "<tr class='ui_multi_select_heads'> ".
	       "<td><b>$opts_title</b></td> ".
	       "<td></td> <td><b>$vals_title</b></td> </tr>";
	}
$rv .= "<tr class='ui_multi_select_row'>";
$rv .= "<td>".&ui_select($name."_opts", [ ], $leftover,
			 $size, 0, 0, $dis, $wstyle)."</td>\n";
$rv .= "<td>".&ui_button("->", undef, $dis,
		 "onClick='multi_select_move(\"$name\", form, 1)'")."<br>".
	      &ui_button("<-", undef, $dis,
		 "onClick='multi_select_move(\"$name\", form, 0)'")."</td>\n";
$rv .= "<td>".&ui_select($name."_vals", [ ], $values,
			 $size, 0, 0, $dis, $wstyle)."</td>\n";
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
<script>
// Move an element from the options list to the values list, or vice-versa
function multi_select_move(name, f, dir)
{
var opts = f.elements[name+"_opts"];
var vals = f.elements[name+"_vals"];
var opts_idx = opts.selectedIndex;
var vals_idx = vals.selectedIndex;
if (dir == 1 && opts_idx >= 0) {
	// Moving from options to selected list
	var o = opts.options[opts_idx];
	vals.options[vals.options.length] = new Option(o.text, o.value);
	opts.remove(opts_idx);
	}
else if (dir == 0 && vals_idx >= 0) {
	// Moving the other way
	var o = vals.options[vals_idx];
	opts.options[opts.options.length] = new Option(o.text, o.value);
	vals.remove(vals_idx);
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
	if ($label =~ /^(.*?)((<a\s+href|<input|<select|<textarea)[\000-\377]*)$/i) {
		$label = $1;
		$after = $2;
		}
	$rv .= "<input class='ui_radio' type=radio ".
	       "name=\"".&quote_escape($name)."\" ".
               "value=\"".&quote_escape($o->[0])."\"".
	       ($o->[0] eq $value ? " checked" : "").
	       ($dis ? " disabled=true" : "").
	       " id=\"$id\"".
	       " $o->[2]> <label for=\"$id\">".
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
$value = int($value);
return &ui_radio($name, $value, [ [ $yes, $text{'yes'} ],
				  [ $no, $text{'no'} ] ], $dis);
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
return "<input class='ui_checkbox' type=checkbox ".
       "name=\"".&quote_escape($name)."\" ".
       "value=\"".&quote_escape($value)."\" ".
       ($sel ? " checked" : "").($dis ? " disabled=true" : "").
       " id=\"".&quote_escape("${name}_${value}")."\"".
       " $tags> ".
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
return "<input class='ui_radio' type=radio name=\"".&quote_escape($name)."\" ".
       "value=\"".&quote_escape($value)."\" ".
       ($sel ? " checked" : "").($dis ? " disabled=true" : "").
       " id=\"$id\"".
       " $tags> <label for=\"$id\">$label</label>$after\n";
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
return "<textarea class='ui_textarea' name=\"".&quote_escape($name)."\" ".
       "rows=$rows cols=$cols".($wrap ? " wrap=$wrap" : "").
       ($dis ? " disabled=true" : "").
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
return &theme_ui_user_textbox(@_) if (defined(&theme_ui_user_textbox));
return &ui_textbox($_[0], $_[1], 13, $_[3], undef, $_[4])." ".
       &user_chooser_button($_[0], 0, $_[2]);
}

=head2 ui_group_textbox(name, value, [form], [disabled?], [tags])

Returns HTML for an input for selecting a Unix group. Parameters are the
same as ui_textbox.

=cut
sub ui_group_textbox
{
return &theme_ui_group_textbox(@_) if (defined(&theme_ui_group_textbox));
return &ui_textbox($_[0], $_[1], 13, $_[3], undef, $_[4])." ".
       &group_chooser_button($_[0], 0, $_[2]);
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

=cut
sub ui_opt_textbox
{
return &theme_ui_opt_textbox(@_) if (defined(&theme_ui_opt_textbox));
my ($name, $value, $size, $opt1, $opt2, $dis, $extra, $max, $tags) = @_;
my $dis1 = &js_disable_inputs([ $name, @$extra ], [ ]);
my $dis2 = &js_disable_inputs([ ], [ $name, @$extra ]);
my $rv;
$size = &ui_max_text_width($size);
$rv .= &ui_radio($name."_def", $value eq '' ? 1 : 0,
		 [ [ 1, $opt1, "onClick='$dis1'" ],
		   [ 0, $opt2 || " ", "onClick='$dis2'" ] ], $dis)."\n";
$rv .= "<input class='ui_opt_textbox' name=\"".&quote_escape($name)."\" ".
       "size=$size value=\"".&quote_escape($value)."\" ".
       ($value eq "" || $dis ? "disabled=true" : "").
       ($max ? " maxlength=$max" : "").
       " ".$tags.
       ">\n";
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
return "<input class='ui_submit' type=submit".
       ($name ne '' ? " name=\"".&quote_escape($name)."\"" : "").
       " value=\"".&quote_escape($label)."\"".
       ($dis ? " disabled=true" : "").
       ($tags ? " ".$tags : "").">\n";
			
}

=head2 ui_reset(label, [disabled?])

Returns HTML for a form reset button, which clears all fields when clicked.
Parameters are :

=item label - Text to appear on the button.

=item disabled - Set to 1 if this button should be disabled by default.

=cut
sub ui_reset
{
return &theme_ui_reset(@_) if (defined(&theme_ui_reset));
my ($label, $dis) = @_;
return "<input type=reset value=\"".&quote_escape($label)."\"".
       ($dis ? " disabled=true" : "").">\n";
			
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
return "<input type=button".
       ($name ne '' ? " name=\"".&quote_escape($name)."\"" : "").
       " value=\"".&quote_escape($label)."\"".
       ($dis ? " disabled=true" : "").
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

Returns HTML for the start of a block of action buttoms with descriptions, as
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
return "<table width=100% class='ui_buttons_table'>\n";
}

=head2 ui_buttons_end

Returns HTML for the end of a block started by ui_buttons_start.

=cut
sub ui_buttons_end
{
return &theme_ui_buttons_end(@_) if (defined(&theme_ui_buttons_end));
return "</table>\n";
}

=head2 ui_buttons_row(script, button-label, description, [hiddens], [after-submit], [before-submit]) 

Returns HTML for a button with a description next to it, and perhaps other
inputs. The parameters are :

=item script - CGI script that this button submits to, like start.cgi.

=item button-label - Text to appear on the button.

=item description - Text to appear next to the button, describing in more detail what it does.

=item hiddens - HTML for hidden fields to include in the form this function generates.

=item after-submit - HTML for text or inputs to appear after the submit button.

=item before-submit - HTML for text or inputs to appear before the submit button.

=cut
sub ui_buttons_row
{
return &theme_ui_buttons_row(@_) if (defined(&theme_ui_buttons_row));
my ($script, $label, $desc, $hiddens, $after, $before) = @_;
return "<form action=$script class='ui_buttons_form'>\n".
       $hiddens.
       "<tr class='ui_buttons_row'> ".
       "<td nowrap width=20% valign=top class=ui_buttons_label>".
       ($before ? $before." " : "").
       &ui_submit($label).($after ? " ".$after : "")."</td>\n".
       "<td valign=top width=80% valign=top class=ui_buttons_value>".
       $desc."</td> </tr>\n".
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
	return "<tr class='ui_buttons_hr'> <td colspan=2><table cellpadding=0 cellspacing=0 width=100%><tr> <td width=50%><hr></td> <td nowrap>$title</td> <td width=50%><hr></td> </tr></table></td> </tr>\n";
	}
else {
	return "<tr class='ui_buttons_hr'> <td colspan=2><hr></td> </tr>\n";
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
$rv .= "<center class='ui_post_header'><font size=+1>$text</font></center>\n" if (defined($text));
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

=head2 ui_print_header(subtext, args...)

Print HTML for a header with the post-header line. The args are the same
as those passed to header(), defined in web-lib-funcs.pl. The exception is
the additional subtext parameter, which is for optional HTML to display
just below the header.

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
&load_theme_library();
return &theme_ui_print_unbuffered_header(@_) if (defined(&theme_ui_print_unbuffered_header));
$| = 1;
$theme_no_table = 1;
&ui_print_header(@_);
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
my @subs = map { $_ || "../config.cgi?$module_name" }
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
my $imgdir = "$gconfig{'webprefix'}/images";
my ($jscb, $jstb) = ($cb, $tb);
$jscb =~ s/'/\\'/g;
$jstb =~ s/'/\\'/g;

return <<EOF;
<style>
.opener_shown {display:inline}
.opener_hidden {display:none}
</style>
<script>
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
    tabobj.innerHTML = '<table cellpadding=0 cellspacing=0><tr>'+
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
    tabobj.innerHTML = '<table cellpadding=0 cellspacing=0><tr>'+
		       '<td valign=top $jstb>'+
		       '<img src=$imgdir/lc1.gif alt=""></td>'+
		       '<td $jstb nowrap>'+
                       '&nbsp;<a href=\\'\\' onClick=\\'return select_tab("'+
		       name+'", "'+tabnames[i]+'")\\'>'+title+'</a>&nbsp;</td>'+
		       '<td valign=top $jstb>'+
    		       '<img src=$imgdir/rc1.gif alt=""></td>'+
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
$rv .= "<a href=\"javascript:hidden_opener('$divid', '$openerid')\" id='$openerid'><img border=0 src='$gconfig{'webprefix'}/images/$defimg' alt='*'></a>\n";
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
$rrv .= "<a href=\"javascript:hidden_opener('$divid', '$openerid')\" id='$openerid'><img border=0 src='$gconfig{'webprefix'}/images/$defimg'></a>\n";
$rrv .= "<a href=\"javascript:hidden_opener('$divid', '$openerid')\">$title</a><br>\n";
$rv .= &ui_table_row(undef, $rrv, $main::ui_table_cols);
$rv .= "</table>\n";
$rv .= "<div class='$defclass' id='$divid'>\n";
$rv .= "<table width=100%>\n";
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
return "</table></div><table width=100%>\n";
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
	$rv .= "<tr $tb> <td>";
	if (defined($heading)) {
		$rv .= "<a href=\"javascript:hidden_opener('$divid', '$openerid')\" id='$openerid'><img border=0 src='$gconfig{'webprefix'}/images/$defimg'></a> <a href=\"javascript:hidden_opener('$divid', '$openerid')\"><b><font color=#$text>$heading</font></b></a></td>";
		}
	if (defined($rightheading)) {
                $rv .= "<td align=right>$rightheading</td>";
                $colspan++;
                }
	$rv .= "</td> </tr>\n";
	}
$rv .= "<tr $cb> <td colspan=$colspan><div class='$defclass' id='$divid'><table width=100%>\n";
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
my $tabnames = "[".join(",", map { "\"".&html_escape($_->[0])."\"" } @$tabs)."]";
my $tabtitles = "[".join(",", map { "\"".&html_escape($_->[1])."\"" } @$tabs)."]";
$rv .= "<script>\n";
$rv .= "document.${name}_tabnames = $tabnames;\n";
$rv .= "document.${name}_tabtitles = $tabtitles;\n";
$rv .= "</script>\n";

# Output the tabs
my $imgdir = "$gconfig{'webprefix'}/images";
$rv .= &ui_hidden($name, $sel)."\n";
$rv .= "<table border=0 cellpadding=0 cellspacing=0 class='ui_tabs'>\n";
$rv .= "<tr><td bgcolor=#ffffff colspan=".(scalar(@$tabs)*2+1).">";
if ($ENV{'HTTP_USER_AGENT'} !~ /msie/i) {
	# For some reason, the 1-pixel space above the tabs appears huge on IE!
	$rv .= "<img src=$imgdir/1x1.gif>";
	}
$rv .= "</td></tr>\n";
$rv .= "<tr>\n";
$rv .= "<td bgcolor=#ffffff width=1><img src=$imgdir/1x1.gif></td>\n";
foreach my $t (@$tabs) {
	if ($t ne $tabs[0]) {
		# Spacer
		$rv .= "<td width=2 bgcolor=#ffffff class='ui_tab_spacer'>".
		       "<img src=$imgdir/1x1.gif></td>\n";
		}
	my $tabid = "tab_".$t->[0];
	$rv .= "<td id=${tabid} class='ui_tab'>";
	$rv .= "<table cellpadding=0 cellspacing=0 border=0><tr>";
	if ($t->[0] eq $sel) {
		# Selected tab
		$rv .= "<td valign=top $cb class='selectedTabLeft'>".
		       "<img src=$imgdir/lc2.gif alt=\"\"></td>";
		$rv .= "<td $cb nowrap class='selectedTabMiddle'>".
		       "&nbsp;<b>$t->[1]</b>&nbsp;</td>";
		$rv .= "<td valign=top $cb class='selectedTabRight'>".
		       "<img src=$imgdir/rc2.gif alt=\"\"></td>";
		}
	else {
		# Other tab (which has a link)
		$rv .= "<td valign=top $tb>".
		       "<img src=$imgdir/lc1.gif alt=\"\"></td>";
		$rv .= "<td $tb nowrap>".
		       "&nbsp;<a href='$t->[2]' ".
		       "onClick='return select_tab(\"$name\", \"$t->[0]\")'>".
		       "$t->[1]</a>&nbsp;</td>";
		$rv .= "<td valign=top $tb>".
		       "<img src=$imgdir/rc1.gif ".
		       "alt=\"\"></td>";
		$rv .= "</td>\n";
		}
	$rv .= "</tr></table>";
	$rv .= "</td>\n";
	}
$rv .= "<td bgcolor=#ffffff width=1><img src=$imgdir/1x1.gif></td>\n";
$rv .= "</table>\n";

if ($border) {
	# All tabs are within a grey box
	$rv .= "<table width=100% cellpadding=0 cellspacing=0 border=0 ".
	       "class='ui_tabs_box'>\n";
	$rv .= "<tr> <td bgcolor=#ffffff rowspan=3 width=1><img src=$imgdir/1x1.gif></td>\n";
	$rv .= "<td $cb colspan=3 height=2><img src=$imgdir/1x1.gif></td> </tr>\n";
	$rv .= "<tr> <td $cb width=2><img src=$imgdir/1x1.gif></td>\n";
	$rv .= "<td valign=top>";
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
my $imgdir = "$gconfig{'webprefix'}/images";
if ($border) {
	$rv .= "</td>\n";
	$rv .= "<td $cb width=2><img src=$imgdir/1x1.gif></td>\n";
	$rv .= "</tr>\n";
	$rv .= "<tr> <td $cb colspan=3 height=2><img src=$imgdir/1x1.gif></td> </tr>\n";
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
return "</table>\n".$div."<table width=100%>\n";
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
return "</table></div><table width=100%>\n";
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

=head2 ui_radio_selector(&opts, name, selected)

Returns HTML for a set of radio buttons, each of which shows a different
block of HTML when selected. The parameters are :

=item opts - An array ref to arrays containing [ value, label, html ]

=item name - HTML name for the radio buttons

=item selected - Value for the initially selected button.

=cut
sub ui_radio_selector
{
return &theme_ui_radio_selector(@_) if (defined(&theme_ui_radio_selector));
my ($opts, $name, $sel) = @_;
my $rv;
if (!$main::ui_radio_selector_donejs++) {
	$rv .= &ui_radio_selector_javascript();
	}
my $optnames =
	"[".join(",", map { "\"".&html_escape($_->[0])."\"" } @$opts)."]";
foreach my $o (@$opts) {
	$rv .= &ui_oneradio($name, $o->[0], $o->[1], $sel eq $o->[0],
	    "onClick='selector_show(\"$name\", \"$o->[0]\", $optnames)'");
	}
$rv .= "<br>\n";
foreach my $o (@$opts) {
	my $cls = $o->[0] eq $sel ? "selector_shown" : "selector_hidden";
	$rv .= "<div id=sel_${name}_$o->[0] class=$cls>".$o->[2]."</div>\n";
	}
return $rv;
}

sub ui_radio_selector_javascript
{
return <<EOF;
<style>
.selector_shown {display:inline}
.selector_hidden {display:none}
</style>
<script>
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
	    ($width ? " width=$width%" : "").
	    ($tabletags ? " ".$tabletags : "").
	    ">\n";
my $i;
for($i=0; $i<@$elements; $i++) {
	$rv .= "<tr class='ui_grid_row'>" if ($i%$cols == 0);
	$rv .= "<td ".$tds->[$i%$cols]." valign=top class='ui_grid_cell'>".
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
	$rv = "<table class=ui_table border ".
	      ($width ? " width=$width%" : "").">\n".
	      ($title ? "<tr $tb> <td><b>$title</b></td> </tr>\n" : "").
              "<tr $cb> <td>$rv</td> </tr>\n".
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
	$rv .= "<td valign=top".(defined($r->[2]) ? "" : " colspan=2").">".
	       ($nobold ? "" : "<b>").
	       &ui_oneradio($name, $r->[0], $r->[1], $r->[0] eq $sel).
	       ($nobold ? "" : "</b>").
	       "</td>\n";
	if (defined($r->[2])) {
		$rv .= "<td valign=top>".$r->[2]."</td>\n";
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

=cut
sub ui_up_down_arrows
{
return &theme_ui_up_down_arrows(@_) if (defined(&theme_ui_up_down_arrows));
my ($uplink, $downlink, $upshow, $downshow) = @_;
my $mover;
my $imgdir = "$gconfig{'webprefix'}/images";
if ($downshow) {
	$mover .= "<a href=\"$downlink\">".
		  "<img src=$imgdir/movedown.gif border=0></a>";
	}
else {
	$mover .= "<img src=$imgdir/movegap.gif>";
	}
if ($upshow) {
	$mover .= "<a href=\"$uplink\">".
		  "<img src=$imgdir/moveup.gif border=0></a>";
	}
else {
	$mover .= "<img src=$imgdir/movegap.gif>";
	}
return $mover;
}

=head2 ui_hr

Returns a horizontal row tag, typically just an <hr>

=cut
sub ui_hr
{
return &theme_ui_hr() if (defined(&theme_ui_hr));
return "<hr>\n";
}

=head2 ui_url($url, $absolute)

Returns a normalized URL.

If $absolute is true, include full protocol and hostname.

=cut
sub ui_url
{
return;
}

=head2 ui_link($text, $url, $cls, $absolute)

Returns the HTML for a link, with label $text and link of $url.

If defined, $cls is added to the "class=" field.

If $absolute is true, return the absolute URL (starting with https:) rather 
than relative; useful for links that must resolve from outside of the 
application, such as SSL login redirects.

=cut
sub ui_link
{
return;
}

=head2 ui_image($image, $alt, $cls, $absolute)

Returns the HTML for an image with the $alt text.  If $absolute is set, 
include protocol and hostname.  $cls is for optional CSS classes.

=cut
sub ui_image
{
return;
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
	return "<img alt=\"$alt\" align=\"middle\""
	     . "src=\"$gconfig{'webprefix'}/images/$direction-grey.gif\">\n";
	}
else {
	return "<a href=\"$url\"><img alt=\"$alt\" align=\"middle\""
	     . "src=\"$gconfig{'webprefix'}/images/$direction.gif\"></a>\n";
	}
}

=head2 ui_confirmation_form(cgi, message, &hiddens, [&buttons], [otherinputs], [extra-warning])

Returns HTML for a form asking for confirmation before performing some
action, such as deleting a user. The parameters are :

=item cgi - Script to which the confirmation form submits, like delete.cgi.

=item message - Warning message for the user to see.

=item hiddens - Array ref of two-element array refs, containing hidden form field names and values.

=item buttons - Array ref of two-element array refs, containing form button names and labels.

=item otherinputs - HTML for extra inputs to include in ther form.

=item extra-warning - An additional separate warning message to show.

=cut
sub ui_confirmation_form
{
my ($cgi, $message, $hiddens, $buttons, $others, $warning) = @_;
my $rv;
$rv .= "<center class=ui_confirmation>\n";
$rv .= &ui_form_start($cgi, "post");
foreach my $h (@$hiddens) {
	$rv .= &ui_hidden(@$h);
	}
$rv .= "<b>$message</b><p>\n";
if ($warning) {
	$rv .= "<b><font color=#ff0000>$warning</font></b><p>\n";
	}
if ($others) {
	$rv .= $others."<p>\n";
	}
$rv .= &ui_form_end($buttons);
$rv .= "</center>\n";
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
my $rv = "<center>";
$rv .= &ui_form_start($cgi) if ($cgi);

# Far left link, if needed
if (@_ > 5) {
	if ($farleft) {
		$rv .= "<a href='$farleft'><img src=/images/first.gif ".
		       "border=0 align=middle></a>\n";
		}
	else {
		$rv .= "<img src=/images/first-grey.gif ".
		       "border=0 align=middle></a>\n";
		}
	}

# Left link
if ($left) {
	$rv .= "<a href='$left'><img src=/images/left.gif ".
	       "border=0 align=middle></a>\n";
	}
else {
	$rv .= "<img src=/images/left-grey.gif ".
	       "border=0 align=middle></a>\n";
	}

# Message and inputs
$rv .= $msg;
$rv .= " ".$inputs if ($inputs);

# Right link
if ($right) {
	$rv .= "<a href='$right'><img src=/images/right.gif ".
	       "border=0 align=middle></a>\n";
	}
else {
	$rv .= "<img src=/images/right-grey.gif ".
	       "border=0 align=middle></a>\n";
	}

# Far right link, if needed
if (@_ > 5) {
	if ($farright) {
		$rv .= "<a href='$farright'><img src=/images/last.gif ".
		       "border=0 align=middle></a>\n";
		}
	else {
		$rv .= "<img src=/images/last-grey.gif ".
		       "border=0 align=middle></a>\n";
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

=head2 js_redirect(url, [window-object])

Returns HTML to trigger a redirect to some URL.

=cut
sub js_redirect
{
my ($url, $window) = @_;
if (defined(&theme_js_redirect)) {
	return &theme_js_redirect(@_);
	}
$window ||= "window";
return "<script>${window}.location = '".&quote_escape($url)."';</script>\n";
}

1;

