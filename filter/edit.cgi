#!/usr/local/bin/perl
# Show details of one filter

require './filter-lib.pl';
&foreign_require("mailbox", "mailbox-lib.pl");
&ReadParse();

# Show page header and get the filter
if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	$filter = { 'actiondefault' => 1,
		    'nobounce' => 1 };
	if ($in{'header'}) {
		# Initial filter is based on URL params
		$filter->{'condheader'} = $in{'header'};
		$filter->{'condvalue'} = $in{'value'};
		}
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "");
	@filters = &list_filters();
	($filter) = grep { $_->{'index'} == $in{'idx'} } @filters;
	}

@tds = ( "nowrap width=30%", "width=70%" );
print &ui_form_start("save.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});

# Start of condition section
$cmode = $filter->{'condspam'} ? 5 :
	 $filter->{'condlevel'} ? 6 :
         $filter->{'condheader'} ? 4 :
	 $filter->{'condtype'} eq '<' ? 3 :
	 $filter->{'condtype'} eq '>' ? 2 :
	 $filter->{'cond'} ? 1 : 0;
print &ui_table_start($text{'edit_header1'}, "width=100%", 2);

# Always do action
print &ui_table_row(
	&ui_oneradio("cmode", 0, $text{'edit_cmode0'}, $cmode == 0),
	"", undef, \@tds);

# Is spam
print &ui_table_row(
	&ui_oneradio("cmode", 5, $text{'edit_cmode5'}, $cmode == 5),
	"", undef, \@tds);

# Spam level is at or above
print &ui_table_row(
	&ui_oneradio("cmode", 6, $text{'edit_cmode6'}, $cmode == 6),
	&ui_textbox("condlevel", $filter->{'condlevel'}, 4, 0, undef,
		    "onFocus='form.cmode[2].checked = true'"), undef, \@tds);

# Check some header
@headers = ( "From", "To", "Subject", "Cc", "Reply-To", "List-Id" );
$common = &indexoflc($filter->{'condheader'}, @headers) >= 0;
if ($filter->{'condvalue'} =~ /^\.\*(.*)\$$/) {
	# Ends with
	$condvalue = $1;
	$condmode = 2;
	}
elsif ($filter->{'condvalue'} =~ /^\.\*(.*)\.\*$/ ||
       $filter->{'condvalue'} =~ /^\.\*(.*)$/) {
	# Contains
	$condvalue = $1;
	$condmode = 1;
	}
elsif ($filter->{'condvalue'} =~ /^(.*)\.\*$/ ||
       $filter->{'condvalue'} =~ /^(.*)$/) {
	# Starts with
	$condvalue = $1;
	$condmode = 0;
	}
if ($condvalue =~ /^[a-zA-Z0-9_ ]*$/) {
	# Contains no special chars, so not a regexp
	$regexp = 0;
	}
else {
	# Has special chars .. but if they are all escaped, then not a regexp
	$condre = $condvalue;
	$condre =~ s/\\./x/g;
	if ($condre =~ /^[a-zA-Z0-9_ ]*$/) {
		$condvalue =~ s/\\(.)/$1/g;
		$regexp = 0;
		}
	else {
		$regexp = 1;
		}
	}
print &ui_table_row(
	&ui_oneradio("cmode", 4, $text{'edit_cmode4'}, $cmode == 4),
	&text('edit_cheader2',
	      &ui_select("condmenu", $cmode != 4 ? "From" :
				     $common ? $filter->{'condheader'} : "",
			 [ (map { [ $_ ] } @headers),
			   [ "", $text{'edit_other'} ] ],
			 1, 0, 0, 0,
			 "onChange='form.condheader.disabled = (form.condmenu.value!=\"\")'"),
	      &ui_textbox("condheader",
			  $common ? "" : $filter->{'condheader'}, 20,
			  $cmode != 4 || $common),
	      &ui_select("condmode", $condmode,
			 [ [ 0, $text{'edit_modestart'} ],
			   [ 1, $text{'edit_modecont'} ],
			   [ 2, $text{'edit_modeend'} ] ]),
	      &ui_textbox("condvalue", $condvalue, 40, 0, undef,
			  "onFocus='form.cmode[3].checked = true'")."<br>\n".
	      &ui_checkbox("condregexp", 1, $text{'edit_regexp'}, $regexp)),
	undef, \@tds);

# Smaller
print &ui_table_row(
	&ui_oneradio("cmode", 3, $text{'edit_cmode3'}, $cmode == 3),
	&ui_bytesbox("condsmall", $cmode == 3 ? $filter->{'cond'} : "",
		     undef, 0, "onFocus='form.cmode[4].checked = true'"),
	undef, \@tds);

# Larger
print &ui_table_row(
	&ui_oneradio("cmode", 2, $text{'edit_cmode2'}, $cmode == 2),
	&ui_bytesbox("condlarge", $cmode == 2 ? $filter->{'cond'} : "",
		     undef, 0, "onFocus='form.cmode[5].checked = true'"),
	undef, \@tds);

# Matches regexp
print &ui_table_row(
	&ui_oneradio("cmode", 1, $text{'edit_cmode1'}, $cmode == 1),
	&ui_textbox("cond", $cmode == 1 ? $filter->{'cond'} : "", 70, 0, undef,
		    "onFocus='form.cmode[6].checked = true'")."<br>".
	&ui_checkbox("body", 1, $text{'edit_cbody'}, $filter->{'body'}),
	undef, \@tds);

print &ui_table_end();

# Start of action section
$amode = $filter->{'actionreply'} ? 6 :
	 $filter->{'actionspam'} ? 5 :
	 $filter->{'actionthrow'} ? 4 :
	 $filter->{'actiondefault'} ? 3 :
	 $filter->{'actionreply'} ? 2 :
	 $filter->{'actiontype'} eq '!' ? 1 : 0;
print &ui_table_start($text{'edit_header2'}, "width=100%", 2);

# Deliver normally
print &ui_table_row(
	&ui_oneradio("amode", 3, $text{'edit_amode3'}, $amode == 3),
	"", undef, \@tds);

if ($amode == 5 || &has_spamassassin()) {
	# Run spamassassin
	print &ui_table_row(
		&ui_oneradio("amode", 5, $text{'edit_amode5'}, $amode == 5),
		"", undef, \@tds);
	}

# Throw away
print &ui_table_row(
	&ui_oneradio("amode", 4, $text{'edit_amode4'}, $amode == 4),
	"", undef, \@tds);

# Forward to some addresses
print &ui_table_row(
	&ui_oneradio("amode", 1, $text{'edit_amode1'}, $amode == 1),
	&ui_textarea("forward", $amode == 1 ?
		join("\n", split(/,/, $filter->{'action'})) : "", 3, 70).
	"<br>\n".
	&ui_checkbox("nobounce", 1, $text{'edit_nobounce'},
		     $filter->{'nobounce'}),
	undef, \@tds);

# Save to a folder or file
@folders = grep { $_->{'file'} } &mailbox::list_folders_sorted();
if ($amode == 0) {
	$folder = &file_to_folder($filter->{'action'}, \@folders);
	}
else {
	$folder = $folders[0];
	}
print &ui_table_row(
	&ui_oneradio("amode", 0, $text{'edit_amode0'}, $amode == 0),
	&ui_select("folder", $folder ? &mailbox::folder_name($folder) : "",
		   [ (map { [ &mailbox::folder_name($_), $_->{'name'} ] }
			  @folders),
		     [ "", $text{'edit_file'} ] ],
		   1, 0, 0, 0,
                   "onChange='form.file.disabled = (form.folder.value!=\"\")'").
		   "\n".
	&ui_textbox("file", $folder ? "" : $filter->{'action'}, 50,
		    $folder ? 1 : 0),
	undef, \@tds);

# Save to a new folder
print &ui_table_row(
	&ui_oneradio("amode", 7, $text{'edit_amode7'}, 0),
	&ui_textbox("newfolder", undef, 20),
	undef, \@tds);

# Send autoreply
if ($amode == 6) {
	$r = $filter->{'reply'};
	$period = $in{'new'} ? 60 :
		  $r->{'replies'} && $r->{'period'} ? int($r->{'period'}/60) :
		  $r->{'replies'} ? 60 : undef;
	if ($r->{'autoreply_start'}) {
		@stm = localtime($r->{'autoreply_start'});
		$stm[4]++; $stm[5] += 1900;
		}
	if ($r->{'autoreply_end'}) {
		@etm = localtime($r->{'autoreply_end'});
		$etm[4]++; $etm[5] += 1900;
		}
	}
else {
	$period = 60;
	}
if ($config{'reply_force'}) {
	$replyblock = "";
	}
elsif ($config{'reply_min'}) {
	$replyblock = "<tr> <td><b>$text{'index_period'}</b></td> ".
		      "<td>".&ui_textbox("period", $period, 3)." ".
			     $text{'index_mins'}."</td> </tr>\n";
	}
else {
	$replyblock = "<tr> <td><b>$text{'index_period'}</b></td> ".
		      "<td>".&ui_opt_textbox("period", $period, 3,
			  $text{'index_noperiod'})." ".$text{'index_mins'}.
		      "</td> </tr>\n";
	}
$cs = !$in{'new'} ? $r->{'charset'} :
      &get_charset() eq $default_charset ? undef : &get_charset();
print &ui_table_row(
	&ui_oneradio("amode", 6, $text{'edit_amode6'}, $amode == 6,
		     "onClick='form.continue.checked = true'"),
	&ui_textarea("reply", $filter->{'reply'}->{'autotext'}, 5, 60)."<br>".
	"<table>\n".
	$replyblock.
	"<tr> <td><b>$text{'index_astart'}</b></td> ".
	"<td>".&ui_date_input($stm[3], $stm[4], $stm[5],
			       "dstart", "mstart", "ystart")." ".
            &date_chooser_button("dstart", "mstart", "ystart")."</td> </tr>\n".
	"<tr> <td><b>$text{'index_aend'}</b></td> ".
	"<td>".&ui_date_input($etm[3], $etm[4], $etm[5],
			       "dend", "mend", "yend")." ".
            &date_chooser_button("dend", "mend", "yend")."</td> </tr>\n".
	"<tr> <td><b>$text{'index_charset'}</b></td> ".
	"<td>".&ui_opt_textbox("charset", $cs, 20,
		       $text{'default'}." ($default_charset)")."</td> </tr>\n".
	"<tr> <td><b>$text{'index_subject'}</b></td> ".
	"<td>".&ui_opt_textbox("subject", $in{'new'} ? "" : $r->{'subject'}, 20,
		       $text{'default'}." (Autoreply to \$SUBJECT)")."</td> </tr>\n".
	"</table>",
	undef, \@tds);

# Continue checkbox
print &ui_table_row(
	undef, &ui_checkbox("continue", 1, $text{'edit_continue'},
			    $filter->{'continue'}), 2);

print &ui_table_end();

# End of the form, with buttons
if ($in{'new'}) {
	@buts = ( [ "create", $text{'create'} ] );
	}
else {
	@buts = ( [ "save", $text{'save'} ],
		  [ "delete", $text{'delete'} ] );
	($inbox) = grep { $_->{'inbox'} } @folders;
	if ($cmode == 4 || $cmode == 5 || $cmode == 6) {
		# Add button to show results of a search for the filter's
		# conditions
		push(@buts, undef,
			    [ "apply", $text{'edit_apply'},
			      &ui_select("applyfrom",
				 $inbox ? &mailbox::folder_name($inbox) : "",
				 [ map { [ &mailbox::folder_name($_),
					   $_->{'name'} ] } @folders ]) ]);
		}
	if (($cmode == 4 || $cmode == 5 || $cmode == 6) && $amode == 0) {
		# Add button to apply the action to matching emails
		push(@buts, undef,
			    [ "move", $text{'edit_move'},
			      &ui_select("movefrom",
				 $inbox ? &mailbox::folder_name($inbox) : "",
				 [ map { [ &mailbox::folder_name($_),
					   $_->{'name'} ] } @folders ]) ]);
		}
	}
print &ui_form_end(\@buts);

# Show page footer
&ui_print_footer("", $text{'index_return'});

