#!/usr/local/bin/perl
# search instance 
# Display a form for searching for a service using keywords/browse

require './smf-lib.pl';
&ReadParse();

$got_results = -1;
$original_searchstring = "";
$searchstring = "";
# get search term
if (defined($in{'searchstring'})) {
	$original_searchstring = $in{'searchstring'};
	$searchstring = $in{'searchstring'};
	if ($searchstring =~ /svc:\/.*/) {
		$searchstring = "$searchstring";
	} elsif ($searchstring =~ /.+/) {
		$searchstring = "\*$searchstring";
		}
	@svcs_info = &svcs_listing("$searchstring");
	if (@svcs_info > 0) {
		$got_results = 1;
	} else {
		$got_results = 0;
		}
		
}

&ui_print_header(undef, $text{'search_instance_title'}, "", undef);

print "<h2>";
&text_and_whats_this("search_instance_detail");
print "</h2>";

print "<form  method=\"POST\" action=\"search_instance.cgi\">\n";
print
    "<input size=60 name=\"searchstring\" value=\"$original_searchstring\">\n";
&print_svc_chooser("searchstring", 0, "$text{'search_instance_browse'}",
	"both", "0");
print "&nbsp;<input type=submit value=\"$text{'search_instance_go'}\">\n";
print "</form>\n";
if ($got_results == 1) {
	print &ui_hr();
	for $svc_info (@svcs_info) {
		$fmri = $svc_info->{'FMRI'};
		print "<p>\n";
		print "<a href=\"instance_viewer.cgi?fmri='$fmri'\">$fmri</a>";
		print "</p>\n";
		}
} elsif ($got_results == 0) {
	print &ui_hr();
	print "<p>$text{'search_instance_noresults'}</p>\n";
	}

&print_cmds_run();

&ui_print_footer("index.cgi", $text{'index'});

