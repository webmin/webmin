#!/usr/local/bin/perl
# index.cgi
# Display a list of services, built from svcs command

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'property_group_editor_title'}, "");

# get instance fmri
if (defined($in{'fmri'})) {
	$fmri = $in{'fmri'};
	# remove quotes...
	$fmri =~ /\'([^\']*)\'/;
	$fmri = $1;
	if ($fmri =~ /(svc:\/[^:]*):(.*)/) {
		$svc = $1;
		$inst = $2;
	} else {
		&error("Invalid fmri: instance must be specified!");
		}
} else {
	&error("No fmri supplied to property group editor!");
	}

# deal with add/deletion of property groups first. this way
# pgroup list will show changes...
if ((defined($in{'add'})) &&
    (defined($in{'addname'})) &&
    (defined($in{'addtype'})) &&
    (defined($in{'addsinst'}))) {
	$addname = "$in{'addname'}";
	$addtype = "$in{'addtype'}";
	$addsinst = "$in{'addsinst'}";
	if (($addname =~ /.+/) && ($addtype =~ /.+/) && ($addsinst =~ /.+/)) {
		&svc_addpg("$svc", "$addsinst", "$addname", "$addtype");
		}
	}
if (defined($in{'remove'})) {
	# get remove pg list
	@remove_pgs = split(/\0/, $in{'applyto'});
	foreach $rpg (@remove_pgs) { 
		# split into service or instance level/name
		if ($rpg =~ /([^\/]*)\/(.*)/) {
			$pgsinst = $1;
			$pgname = $2;
			&svc_delpg("$svc", "$pgsinst", "$pgname");
			}
		}
	}

@pgroup_listing_svc = &svc_listpg($svc, "service");
@pgroup_listing_inst = &svc_listpg($svc, $inst);
@pgroup_listing = (@pgroup_listing_svc, @pgroup_listing_inst);

print "<h2>";
&text_and_whats_this("property_group_editor_detail");
print " : $fmri </h2>\n";

print "<form method=\"POST\" action=\"property_group_editor.cgi?fmri='$fmri'\">\n";

# add pg table first...
print "<p><h3>$text{'property_group_editor_addpg'}</h3>\n";
print "<table><tr>";
print "<td><b>$text{'property_group_editor_addsinst'}</b></td>\n";
print "<td><b>$text{'property_group_editor_addname'}</b></td>\n";
print "<td><b>$text{'property_group_editor_addtype'}</b></td></tr>\n";
print "<tr><td>\n";
@sinstarray = ("service", "$inst");
&print_selection("addsinst", "service", \@sinstarray);
print "</td><td>\n";
print "<input size=30 name=\"addname\" value=\"\">\n";
print "</td><td>\n";
print "<input size=30 name=\"addtype\" value=\"\">\n";
print "</td></tr>\n";
print "<tr><td>&nbsp;</td><td>&nbsp;</td><td>";
print "<input type=submit name=\"add\" value=\"$text{'property_group_editor_add'}\">\n";
print "</td></tr></table></b>\n";

print "<table border width=100%>\n";
print "<tr><td><table width=100%>\n";
print "<tr $cb><td><b>$text{'property_group_editor_apply'}</b>:&nbsp;";
print "<input type=submit name=\"remove\" onClick=\"return (confirm(\'$text{'property_group_editor_deleteconfirm'}\'))\" value=\"$text{'property_group_editor_delete'}\">&nbsp;\n";
print "</td></tr></table></td></tr>\n";
print "<tr><td><table width=100%>\n";
print "<tr $cb>\n";
print "<td><b>$text{'property_group_editor_select'}</b></td>\n";
print "<td><b>$text{'property_group_editor_sinst'}</b></td>\n";
print "<td><b>$text{'property_group_editor_pgroup_name'}</b></td>\n";
print "<td><b>$text{'property_group_editor_pgroup_type'}</b></td></tr>\n";

foreach $pg (@pgroup_listing) {
	print "<tr $cb>";
	$sinst = $pg->{'sinst'};
	$name = $pg->{'pgroup_name'};
	$type = $pg->{'pgroup_type'};
	print "<td>\n";
	print "<input type=checkbox name=\"applyto\" value=\"$sinst/$name\">";
	print "</td><td>\n";
	print "$sinst</td><td>\n";
	# don't allow edit of nonpersistent items!
	if ($type =~ /NONPERSISTENT/) {
		print "$name";
	} else {
		$entity = ($sinst eq "service") ? "$svc" : "$fmri";
		print
	"<a href=\"property_editor.cgi?fmri='$fmri'&sinst=$sinst&pgroup=$name\">$name</a>";
		}
	print "</td><td>$type</td>\n";
	print "</tr>\n";
}
print "</table></td></tr></table></form>\n";

&print_cmds_run();

&ui_print_footer("instance_viewer.cgi?fmri='$fmri'",
	$text{'property_group_editor_back'});

