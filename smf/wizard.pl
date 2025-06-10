#!/usr/local/bin/perl
#
# Code for a generic cgi wizard. The wizard save
# for each stage in the process, provides validation of fields via 
# regular expressions, and manages button presses etc. It allows pages
# to be used to enter multiple sets of values, all of which are stored.
#
#	1) create a wizard array. Each array element specifies
# 	a page in the wizard. Each element should be a comma-separated
#	string, containing the following values:
#		- "page": the .cgi file for the page
#		- "min": the minimum valid number of datafiles
#		required for this page
#		- "max": the maximum valid number of datafiles
#		required for this page.
#	An example of a valid entry would be "page=mywizpage.cgi,min=1,max=1".
#
#	The wizard allows pages to be used to enter multiple sets of
#	properties. Each wizard page has an associated data file, and
#	where multiple datafiles are valid (i.e. max_datafiles>1),
#	they are numbered monotonically.
#	2) Create a .cgi file for each wizard page you specified in the
#	wizard array. Each wizard page will call wizard_header(),
#	wizard_[inputtype]() for each data field and wizard_footer().
#	3) Create a submit .cgi script that processes the set of datafiles
#	created.
#
# Appearance:
#
# Wizard consists of a main table holding 3 subtables
#       - the description/image table, taking up the LHS
#       - the data table, where fields appear, on the RHS
#       - the button table on the bottom
# The data table is opened, and rows are added by calls
# to wizard_input(). wizard_footer() adds the button table.



# This variable is set to 0 whenever an element in the form fails to
# validate against its regular expression. This prevents progress, and the
# highlighted elements are marked in red.
$validation_success = 1;

# Creates tables/subtables, show image etc.
#
# Parameters: ref_to_array_of_wizard_element_hashes, pagename, heading,
# description, imagename
#
sub wizard_header()
{
local ($wizinfo, %wizard, $wizref, $pagename, $heading, $description, $image);
($wizinfo, $pagename, $heading, $description, $image) = @_;
%wizard = &read_in_wizard("$wizinfo");
$wizref = \%wizard;
$pageinst = &wizard_get_pageinst();
$submit = &get_wizard_info_by_name($wizref, "submit");
print "<form method=\"POST\" action=\"$submit\">\n";
print "<table border cellpadding=0 cellspacing=0 width=100%>\n";
print "<tr $cb><td>\n";
print "<table noborder cellpadding=0 cellspacing=0 width=100% height=15%>\n";
print "<tr $tb><td>$heading</td></tr></table></td></tr>\n";
print "<tr $cb><td>\n";
print "<table border cellpadding=0 cellspacing=0 width=100% height=70%>\n";

# LHS consists description + optional image.
print "<tr $cb><td>\n";
print "<table noborder cellpadding=0 cellspacing=0>\n";
if ($image =~ /.+/) {
	print "<tr $cb><td><img src=$image alt=\"\"></td>\n";
	}
print "<td><p>$description</p></td></tr></table></td>\n";

# RHS contains information supplied by calls to wizard_input(), i.e.
# it`s where data is entered. We open this table and close it with
# wizard_footer() below...

print "<td><table noborder cellpadding=0 cellspacing=0>\n";
}

sub wizard_footer()
{
local ($wizinfo, $pagename, %wizard, $wizref, $min_datafiles, $max_datafiles,
	$pageinst, $pagenum, $datafile, $back_disabled, $next_disable,
	$add_disabled, $remove_disabled, $finish_disabled, @wizard_pages,
	$page, @datafiles);
($wizinfo, $pagename) = @_;
%wizard = &read_in_wizard("$wizinfo");
$wizref = \%wizard;
$pageinst = &wizard_get_pageinst();

$min_datafiles = &get_wizard_info_by_name($wizref, "min_datafiles", $pagename);
$max_datafiles = &get_wizard_info_by_name($wizref, "max_datafiles", $pagename);
$pagenum = &get_wizard_info_by_name($wizref, "pagenum", $pagename);
$datafile = &wizard_datafile_name($pagename, $pageinst);

# which buttons do we show?

$back_disabled = "";
# first page, first instance, so no back button
if (($pagenum == 0) && ($pageinst == 0)) {
	$back_disabled="disabled=\"disabled\"";
	}

$next_disabled = "disabled=\"disabled\"";
# if we have met or exceeded minimum requirement of datafiles for
# this page, and are not on last page, or there are subsequent
# instances, enable next button
@datafiles = &list_wizard_datafiles($pagename);
@num_pages = &get_wizard_info_by_name($wizref, "pages");
@num_pageinsts = &list_wizard_datafiles($pagename);
if ((($pagenum < (@num_pages - 1)) && (@datafiles >= $min_datafiles)) ||
	(($pageinst < (@num_pageinsts - 1)))) {
	$next_disabled = "";
	}

$add_disabled = "";
$update_disabled = "disabled=\"disabled\"";
$new_disabled = "disabled=\"disabled\"";
$remove_disabled="disabled=\"disabled\"";
# if we have data already for page, don't disable remove/clear, disable add,
# enable update
@thispage_datafiles = &list_wizard_datafiles("$pagename.$pageinst");
if (@thispage_datafiles > 0) {
	$remove_disabled = "";
	$add_disabled = "disabled=\"disabled\"";
	$update_disabled = "";
	# enable new if we can have more instances....
	if ($pageinst < ($max_datafiles - 1)) {
		$new_disabled = "";
		}
	}

# can we show finish button? if each page has exceeded it`s minimum
# amount of datafiles, and each datafile has validation_success == 1, yes.
$finish_disabled = "";
@wizard_pages = &get_wizard_info_by_name($wizref, "pages");
foreach $page (@wizard_pages) {
	@datafiles = &list_wizard_datafiles("$page->{'pagename'}");
	foreach $datafile (@datafiles) {
		# get instance number...
		$datafile =~ /$page->{'pagename'}\.([0-9]*)/;
		$inst = $1;
		$validated = &wizard_get_data_value($page->{'pagename'},
			$inst, "validation_success");
		if ($validated != 1) {
			# instance not valid!
			$finish_disabled = "disabled=\"disabled\"";
			}
		}
	$page_min_datafiles = &get_wizard_info_by_name($wizref, "min_datafiles",
		"$page->{'pagename'}");
	if (@datafiles < $page_min_datafiles) {
		# haven't got minimum number of instances!
		$finish_disabled = "disabled=\"disabled\"";
		}
	}
# close data table
print "</table></td></tr></table></td></tr>\n";

# include hidden parameters here. These are:
# 	- pagename: current pagename
# 	- pageinst: current pageinst
print "<input type=\"hidden\" name=\"pagename\" value=\"$pagename\">";
print "<input type=\"hidden\" name=\"pageinst\" value=\"$pageinst\">";

# open button window
print "<tr $cb><td>\n";
print "<table noborder cellpadding=0 cellspacing=0 width=100% height=15%>";
print "<tr $cb><td>\n";
print
  "<input type=\"submit\" name=\"submit\" value=\"$text{'wizard_back'}\" $back_disabled>\n";
print "</td><td>\n";
print
  "<input type=\"submit\" name=\"submit\" value=\"$text{'wizard_new'}\" $new_disabled>\n";
print "</td><td>\n";
print
  "<input type=\"submit\" name=\"submit\" value=\"$text{'wizard_add'}\" $add_disabled>\n";
print "</td><td>\n";
print
  "<input type=\"submit\" name=\"submit\" value=\"$text{'wizard_update'}\" $update_disabled>\n";
print "</td><td>\n";
print
   "<input type=\"submit\" name=\"submit\" value=\"$text{'wizard_remove'}\" $remove_disabled>\n";
print "</td><td>\n";
print
  "<input type=\"submit\" name=\"submit\" value=\"$text{'wizard_next'}\" $next_disabled>\n";
print "</td><td>\n";
print
 "<input type=\"submit\" name=\"submit\" value=\"$text{'wizard_finish'}\" $finish_disabled>\n";
print "</td></tr></table></td></tr></table></form>\n";

# if we are validating page, ensure that we redirect!
if ($validation_success == 1) {
	# do redirect if next page/inst are defined
	&wizard_redirect_next($pagename, $pageinst);
	}
}

sub wizard_input()
{
local ($pagename, $description, $name, $size, $validation_regexp,
	$validation_err, $pageinst, $value);
($pagename, $description, $name, $size, $validation_regexp, $validation_err)
	= @_;
$value = &wizard_form_input_header($pagename, $description, $name,
	$validation_regexp, $validation_err);
print "<input size=$size name=\"$name\" value=\"$value\">\n";
&wizard_form_input_footer();
}

sub wizard_textarea()
{
local ($pagename, $description, $name, $rows, $cols, $validation_regexp,
	$validation_err, $pageinst, $value);
($pagename, $description, $name, $rows, $cols,  $validation_regexp,
	$validation_err) = @_;
$value = &wizard_form_input_header($pagename, $description, $name,
	$validation_regexp, $validation_err);
print "<textarea rows=$rows cols=$cols name=\"$name\" wrap=\"virtual\">\n";
print "$value";
print "</textarea>\n";
&wizard_form_input_footer();
}

sub wizard_select()
{
local ($pagename, $description, $name, $selection_arrayref, $validation_regexp,
	$validation_err, $pageinst, $value, @array, $elt, $select);
($pagename, $description, $name, $selection_arrayref, $validation_regexp,
	$validation_err) = @_;
$value = &wizard_form_input_header($pagename, $description, $name,
	$validation_regexp, $validation_err);
print "<select name=\"$name\" size=1>\n";
@array = @$selection_arrayref;
foreach $elt (@array) {
	$select = "";
	if ("$elt" eq "$value") {
		$select = "selected";
		}
	print "<option $select>$elt</option>\n";
	}
print "</select>\n";
&wizard_form_input_footer();
}

# subfns used for wizard form inputs...

sub wizard_form_input_header()
{
local ($pagename, $description, $name, $validation_regexp,
	$validation_err, $pageinst, $value);
($pagename, $description, $name, $validation_regexp, $validation_err) = @_;
$pageinst = &wizard_get_pageinst();
$value = &wizard_get_data_value($pagename, $pageinst, $name);
&wizard_validate_input($value, $validation_regexp, $validation_err);
print "<tr $cb><td><p>$description</p></td></tr><tr $cb><td>\n";
return $value;
}

sub wizard_form_input_footer()
{
print "</td></tr>\n";
}

# Deals with page submission
#
# Parameters: ref_to_array_of_wizard_element_hashes, pagename, heading,
# description, imagename
#
sub wizard_process_submit()
{
local ($wizinfo, %wizard, $wizref, $pagename, $heading, $description, $image);
($wizinfo, $pagename, $heading, $description, $image) = @_;
%wizard = &read_in_wizard("$wizinfo");
$wizref = \%wizard;
$pageinst = &wizard_get_pageinst();
if (defined($in{'submit'})) {
	$button_name = $in{'submit'};
} else {
	&error("No button name passed to wizard_process_submit!");
	}
if ($button_name eq "$text{'wizard_finish'}") {
	# finish is the submit scripts problem!
	return;
	}
if (defined($in{'pagename'})) {
	$pagename = $in{'pagename'};
} else {
	&error("No page name passed to wizard_process_submit!");
	}
if (defined($in{'pageinst'})) {
	$pageinst = $in{'pageinst'};
} else {
	&error("No page instance passed to wizard_process_submit!");
	}
if ($button_name eq "$text{'wizard_back'}") {
	# find previous page
	$previous_pagename = $pagename;
	$previous_pageinst = $pageinst;
	$pagenum = &get_wizard_info_by_name($wizref, "pagenum",
		$pagename);
	if (($pageinst == 0) && ($pagenum > 0)) {
		$previous_pagenum = $pagenum - 1;
		$previous_pagename = &get_wizard_info_by_page($wizref,
			"pagename", $previous_pagenum);
		@num_pageinsts = &list_wizard_datafiles($previous_pagename);
		if (@num_pageinsts > 0) {
			$previous_pageinst = @num_pageinsts - 1;
			}
	} elsif ($pageinst > 0) {
		$previous_pageinst = $pageinst - 1;
		}
	# validation needed? does data already exist for page?
	$validate_option = "";
	$previous_datafile = "$previous_pagename.$previous_pageinst";
	@datafiles =  &list_wizard_datafiles($previous_datafile);
	if (@datafiles > 0) {
		$validate_option = "&validate=1";
		}
	&redirect
	  ("$previous_pagename?pageinst=$previous_pageinst$validate_option");
	}
if ($button_name eq "$text{'wizard_next'}") {
	# find next page
	$next_pagename = $pagename;
	$next_pageinst = $pageinst;
	@num_pageinsts = &list_wizard_datafiles($pagename);
	$lastinst = 0;
	if (@num_pageinsts > 0) {
		$lastinst = @num_pageinsts - 1;
		}
	if ($pageinst >= $lastinst) {
		$pagenum = &get_wizard_info_by_name($wizref, "pagenum",
			$pagename);
		@num_pages = &get_wizard_info_by_name($wizref, "pages");
		if ($pagenum < (@num_pages - 1)) {
			$next_pagenum = $pagenum + 1;
			$next_pagename = &get_wizard_info_by_page($wizref,
				"pagename", $next_pagenum);
			$next_pageinst = 0;
			}
	} else {
		$next_pageinst = $pageinst + 1;
		}
	# validation needed? does data already exist for page?
	$next_datafile = "$next_pagename.$next_pageinst";
	@datafiles = &list_wizard_datafiles($next_datafile);
	$validate_option= "";
	if (@datafiles > 0) {
		$validate_option = "&validate=1";
		}
	&redirect("$next_pagename?pageinst=$next_pageinst$validate_option");
	}
if ($button_name eq "$text{'wizard_new'}") {
	# for new, if we have less than full complement of instances,
	# use the last unused instance, otherwise stay here
	$next_pagename = $pagename;
	$next_pageinst = $pageinst;
	@num_pageinsts = &list_wizard_datafiles($pagename);
	$max_inst = &get_wizard_info_by_name($wizref, "max_datafiles",
		$pagename);
	if (@num_pageinsts <= $max_inst) {
		$next_pageinst = @num_pageinsts;
		}
	&redirect("$next_pagename?pageinst=$next_pageinst");
	}
if ($button_name eq "$text{'wizard_remove'}") {
	&wizard_clear_data($pagename, $pageinst);
	&redirect("$pagename?pageinst=$pageinst");
	}
if (($button_name eq "$text{'wizard_add'}") ||
	($button_name eq "$text{'wizard_update'}")) { 
	# find next page
	$next_pagename = $pagename;
	$next_pageinst = $pageinst;
	$max_inst = &get_wizard_info_by_name($wizref, "max_datafiles",
		$pagename);
	if ($pageinst < ($max_inst - 1)) {
		# in this case, add can move to another instance
		$next_pageinst = $pageinst + 1;
	} else {
		# in this case, add moves to next page if possible
		$pagenum = &get_wizard_info_by_name($wizref, "pagenum",
			$pagename);
		@num_pages = &get_wizard_info_by_name($wizref, "pages");
		if ($pagenum < (@num_pages - 1)) {
			$next_pagenum = $pagenum + 1;
			$next_pagename = &get_wizard_info_by_page($wizref,
				"pagename", $next_pagenum);
			$next_pageinst = 0;
			}
		}
	# save data and reload validation stage (which includes automatic
	# redirect if no validation errors occur)
	&wizard_save_data($pagename, $pageinst);
	$validation_success = 1;
	&redirect("$pagename?pageinst=$pageinst&validate=1&next_pagename=$next_pagename&next_pageinst=$next_pageinst");
	}

# Shouldn't be here!
&error("Invalid button name $button_name!");
}

# Return pageinst if defined, 0 otherwise.
#
# Parameters:
#
sub wizard_get_pageinst()
{
local ($pageinst);
if (defined($in{'pageinst'})) {
	$pageinst = $in{'pageinst'};
} else {
	$pageinst = 0;
	}
return $pageinst;
}

# Redirect to next target pagename/pageinst are defined...
#
# Parameters:
#
sub wizard_redirect_next()
{
local ($pagename, $pageinst);
($pagename, $pageinst) = @_;
if ((defined($in{'next_pagename'})) && (defined($in{'next_pageinst'}))) {
	# add validation success value to datafile
	# add validation result to datafile - used to assess if we can finish
	&wizard_save_validation_value($pagename, $pageinst);
	# if validation succeeded, move on...
	if ($validation_success == 1) {
		print <<EOF;
<script>
location.href = '$in{'next_pagename'}?pageinst=$in{'next_pageinst'}';
</script>
EOF
		}
	}
}

sub wizard_validate_input()
{
local ($value, $validation_regexp, $validation_err);
($value, $validation_regexp, $validation_err) = @_;
# do we do validation here?
if (defined($in{'validate'})) {
	if ($in{'validate'} == 1) {
		if ($value =~ /^$validation_regexp$/) {
			# ok, so we can redirect
		} else {
			print "<tr $cb><td>\n";
			print
			    "<i><font color=#FF0000>$validation_err</font></i>";
			print "</td></tr>\n";
			# flag global var to indicate validation failed - no
			# redirect will occur as a result...
			$validation_success = 0;
			}
		}
	}
}

# Give appropriate full path to datafile when given pagename/inst
#
# Parameters: pagename, pageinst
#
sub wizard_datafile_name()
{
local ($pagename, $pageinst);
($pagename, $pageinst) = @_;
return "$module_config_directory/${pagename}.${pageinst}.wizdata";
}

# Saves data to datafile for page/inst
#
# Parameters: pagename, pageinst
#
sub wizard_save_data()
{
local ($pagename, $pageinst, @inkeys, $datafile);
($pagename, $pageinst) = @_;
$datafile = &wizard_datafile_name($pagename, $pageinst);
# save webmin's "in" hash to file
@inkeys = keys(%in);
open(DATAFILE,">$datafile");
foreach $inkey (@inkeys) {
	print DATAFILE "$inkey=$in{$inkey}\n";
	}
close(DATAFILE);
}

sub wizard_save_validation_value()
{
local ($pagename, $pageinst, $datafile);
($pagename, $pageinst) = @_;
$datafile = &wizard_datafile_name($pagename, $pageinst);
open(DATAFILE,">>$datafile");
print DATAFILE "validation_success=$validation_success";
close(DATAFILE);
}

# Removes all datafiles for wizard
#
# Parameters: wizard_info
#
sub wizard_clear_all_data()
{
local ($wizinfo, %wizard, $wizref, @pages, $page, @allinsts, $inst);
$wizinfo = $_[0];
%wizard = &read_in_wizard("$wizinfo");
$wizref = \%wizard;
@pages = &get_wizard_info_by_name($wizref, "pages");
foreach $page (@pages) {
	@allinsts = &list_wizard_datafiles("$page->{'pagename'}");
	foreach $inst (@allinsts) {
		unlink($inst);
		}
	}
}

# Removes datafile, moves those above down one instance
#
# Parameters: pagename, pageinst
#
sub wizard_clear_data()
{
local ($pagename, $pageinst, $datafile, @num_inst, $instnum);
($pagename, $pageinst) = @_;
$datafile = &wizard_datafile_name($pagename, $pageinst);
@num_inst = &list_wizard_datafiles($pagename);
unlink($datafile);
# move all instances above deleted instance down one to fill gap....
for ($instnum = $pageinst + 1; $instnum < @num_inst; $instnum++) {
	$datafile_old = &wizard_datafile_name($pagename,
		$instnum);
	$datafile_new = &wizard_datafile_name($pagename,
		$instnum -1);
	rename($datafile_old, $datafile_new);
	}
}

# Reads wizard data file into key-value hash
#
# Parameters: pagename, pageinst
#
sub wizard_get_data()
{
local ($pagename, $pageinst, $datafile, @data, $line, $key, $value, %hash);
($pagename, $pageinst) = @_;
$datafile = &wizard_datafile_name($pagename, $pageinst);
open(DATAFILE, "<".$datafile);
@data = <DATAFILE>;
foreach $line (@data) {
	if ($line =~ /^\s*\#/) {
		next;
		}
	if ($line =~ /\s*([^=]+)=(.*)/) {
		$key = $1;
		$value = $2;
		$hash{"$key"} = "$value";
		}
        }
return %hash;
}

# Gets data value for particular page/inst
#
# Parameters: pagename, pageinst, datakey
#
sub wizard_get_data_value()
{
local ($pagename, $pageinst, $datakey, %hash);
($pagename, $pageinst, $datakey) = @_;
%hash = &wizard_get_data($pagename, $pageinst);
return ($hash{"$datakey"});
}

# Gets data values for all page insts associated with a pagename
#
# Parameters: pagename, datakey
#
sub wizard_get_data_values()
{
local ($pagename, $datakey, @allinsts, $instfile, $pageinst, $value);
($pagename, $datakey) = @_;
# get all matching instance files...
@allinsts = &list_wizard_datafiles($pagename);
@values = ();
foreach $instfile (@allinsts) {
	$instfile =~ /${pagename}\.([^\.]*)/;
	$pageinst = $1;
	$value = &wizard_get_data_value($pagename, $pageinst, $datakey);
	push (@values, $value);
	}
return @values;
}

# Read in wizard string, create internal representation (wizard hash).
#
# Parameters: wizard_string;
sub read_in_wizard()
{
local ($wizard_string, @wizard_array, $pagenum, %wizard, $wiz_elt);
$wizard_string = $_[0];
@wizard_array = split(/;/, $wizard_string);
$pagenum = 0;
foreach $wiz_elt (@wizard_array) {
	if ($wiz_elt =~ /\s*page\s*=\s*([^,\s]*)\s*,\s*min\s*=\s*([^,\s]*)\s*,\s*max\s*=\s*(.+)/) {
		# standard wizard element 
		$wizard{'pages'}->[$pagenum]->{'pagename'} = $1;
		$wizard{'pages'}->[$pagenum]->{'min_datafiles'} = $2;
		$wizard{'pages'}->[$pagenum]->{'max_datafiles'} = $3;
		$wizard{'pages'}->[$pagenum]->{'pagenum'} = $pagenum;
		$pagenum = $pagenum + 1;
	} elsif ($wiz_elt =~ /\s*submit\s*=\s*(\S+)/) {
		# submit cgi script name
		$wizard{'submit'} = $1;
	} else {
		&error("Syntax error in wizard specification: $wiz_elt");
		}
	}
return %wizard;
}

sub get_wizard_info_by_name()
{
local ($wizref, $pagename, @wizard_pages, $page);
($wizref, $data, $pagename) = @_;
@wizard_pages = @{$wizref->{'pages'}};
if ($data eq "pages") {
	return @wizard_pages;
} elsif ($data eq "submit") {
	return $wizref->{$data};
	}
foreach $page (@wizard_pages) {
	if ($pagename eq "$page->{'pagename'}") {
		return $page->{$data};
		}
	}
# not found
&error("Data $data not found for wizard. Pagename: $pagename");
}

sub get_wizard_info_by_page()
{
local ($wizref, $data, $pagenum);
($wizref, $data, $pagenum) = @_;
@wizard_pages = @{$wizref->{'pages'}};
return $wizard_pages[$pagenum]->{$data};
}

# list all files matching pattern and ending in .wizdata
#
# Parameters: filematch_pattern
#
sub list_wizard_datafiles()
{
local($filematch, $f,@filelist);
$filematch = $_[0];
opendir(DIR, $module_config_directory);
foreach $f (readdir(DIR)) {
	if ($f =~ /^$filematch.*\.wizdata/) {
		push(@filelist, "$module_config_directory/$f");
		}
	}
return @filelist;
}

