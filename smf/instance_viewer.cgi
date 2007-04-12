#!/usr/local/bin/perl
# instance viewer
# Display a form for displaying SMF instance information

require './smf-lib.pl';
&ReadParse();

# get instance fmri
if (defined($in{'fmri'})) {
	$fmri = $in{'fmri'};
	# remove quotes...
	$fmri =~ /\'([^\']*)\'/;
	$fmri = $1;
} else {
	&error("No fmri supplied to instance viewer!");
	}

# Gather service description, and state info
$description = &run_smf_cmds("/usr/bin/svcs -H -oDESC $fmri", 0);
$sinfo = &run_smf_cmds("/usr/bin/svcs -x $fmri", 0);
@state_info = split(/\n/, $sinfo);

&ui_print_header(undef, $text{'instance_viewer_title'}, "", undef);

print "<h2>$description</h2>\n";
print "<h2>";
&text_and_whats_this("instance_viewer_detail");
print "</h2>";

foreach $line (@state_info) {
	$converted = &convert_links_in_text($line);
	print "<p>$converted</p>\n";
	}

print "<p>";
print "<a href=\"property_group_editor.cgi?fmri='$fmri'\">";
print "$text{'instance_viewer_goto_pgroup_editor'}</a>";
print "</p>\n";

print "<p>";
print "<a href=\"dep_viewer.cgi?fmri='$fmri'\">";
print "$text{'instance_viewer_goto_dep_viewer'}</a>";
print "</p>\n";

&print_cmds_run();

&ui_print_footer("index.cgi", $text{'index'});

